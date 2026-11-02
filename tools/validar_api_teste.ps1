param(
    [Parameter(Mandatory = $true)][string]$BackendRoot,
    [string]$ApiOrigin = 'http://127.0.0.1:5000',
    [Guid]$DeviceUuid = '46143ff9-1a4a-4061-9240-e95285a2c424'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$statePath = Join-Path $root '.local/validation-api-live.json'
$state = [ordered]@{estado='iniciando'; fase='preparacao'; redefinida=$false; checks=@()}
function Save-State([string]$Status, [string]$Phase) {
    $script:state['estado']=$Status
    $script:state['fase']=$Phase
    [IO.Directory]::CreateDirectory((Split-Path -Parent $statePath)) | Out-Null
    [IO.File]::WriteAllText($statePath, ($script:state | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
}
function Request-Api([string]$Method, [string]$Path, $Body=$null, [string]$Token='', [string]$Installation='', [int]$Expected=200) {
    $headers=@{Accept='application/json'}
    if($Token){$headers['Authorization']='Bearer '+$Token}
    if($Installation){$headers['X-Device-UUID']=$Installation}
    $parameters=@{Method=$Method; Uri=$script:ApiOrigin+$Path; Headers=$headers; TimeoutSec=45; MaximumRedirection=0; UseBasicParsing=$true}
    if($null -ne $Body){
        $parameters['Body']=[Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 12 -Compress))
        $parameters['ContentType']='application/json; charset=utf-8'
    }
    $httpCode=0
    $response=$null
    try {
        $response=Invoke-WebRequest @parameters
        $httpCode=[int]$response.StatusCode
    } catch {
        if($_.Exception.Response){$httpCode=[int]$_.Exception.Response.StatusCode}
    }
    if($httpCode -ne $Expected){throw ('HTTP inesperado em '+$Method+' '+$Path+': '+$httpCode+'; esperado '+$Expected)}
    if($Expected -eq 200){return ($response.Content | ConvertFrom-Json)}
}
$rhToken=$null; $mobileToken=$null; $testPassword=$null
try {
    Save-State 'iniciando' 'preparacao'
    $original=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root '.local/usuario-teste-status.json') | ConvertFrom-Json
    $uri=[Uri]$ApiOrigin
    if($uri.Scheme -ne 'http' -or $uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -ne 5000 -or $uri.AbsolutePath -ne '/' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment){throw 'Use somente a API local na porta 5000.'}
    $ApiOrigin=$uri.GetLeftPart([UriPartial]::Authority)
    if($original.estado -ne 'sucesso' -or $original.email_teste -notmatch '^mobile\.teste\..+@example\.invalid$'){throw 'Estado da conta de teste ausente ou incompatível.'}
    $BackendRoot=[IO.Path]::GetFullPath($BackendRoot)
    $python=Join-Path $BackendRoot '.venv/Scripts/python.exe'
    $helper=Join-Path $PSScriptRoot 'redefinir_senha_teste.py'
    if(-not(Test-Path -LiteralPath $python) -or -not(Test-Path -LiteralPath (Join-Path $BackendRoot 'app/__init__.py'))){throw 'Ambiente Python do backend nao encontrado.'}
    $null=Request-Api 'GET' '/'
    Save-State 'aguardando_rh' 'autenticacao_rh'
    Write-Host 'Validacao real do Ponto Aqui - conta de teste existente' -ForegroundColor Cyan
    Write-Host 'Informe a conta RH da mesma empresa no dialogo. A senha RH nao sera salva.'
    $credential=Get-Credential -Message 'Autorizar redefinicao SOMENTE da conta mobile de teste (RH da empresa)'
    if($null -eq $credential){throw 'Autenticacao cancelada.'}
    $plain=$credential.GetNetworkCredential().Password
    try {$login=Request-Api 'POST' '/api/web/auth/login' @{email=$credential.UserName;senha=$plain}}
    finally {$credential=$null; $plain=$null}
    $rhToken=$login.access_token; $login=$null
    $profile=(Request-Api 'GET' '/api/web/auth/me' $null $rhToken).usuario
    if($profile.papel -ne 'RH' -or $profile.empresa_id -ne $original.empresa_id){throw 'Use RH ativo da empresa da conta de teste.'}
    Save-State 'executando' 'redefinindo_senha_teste'
    $bytes=New-Object byte[] 24
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes); $rng.Dispose()
    $testPassword=[Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
    [Array]::Clear($bytes,0,$bytes.Length)
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$python
    $start.Arguments='-B "'+$helper+'" --backend-root "'+$BackendRoot+'"'
    $start.WorkingDirectory=$BackendRoot
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardInput=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $start.EnvironmentVariables['PYTHONUTF8']='1'
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE']='1'
    $process=New-Object Diagnostics.Process
    $process.StartInfo=$start
    $process.Start() | Out-Null
    $process.StandardInput.WriteLine((@{access_token=$rhToken;empresa_id=$original.empresa_id;usuario_id=$original.criados.usuario_id;email=$original.email_teste;nova_senha=$testPassword} | ConvertTo-Json -Compress))
    $process.StandardInput.Close()
    $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(60000)){$process.Kill();throw 'Redefinicao excedeu o tempo limite; confirme antes de repetir.'}
    $result=$stdoutTask.GetAwaiter().GetResult() | ConvertFrom-Json
    $null=$stderrTask.GetAwaiter().GetResult()
    if($process.ExitCode -ne 0 -or -not $result.ok -or $result.usuario_id -ne $original.criados.usuario_id){throw 'Redefinicao da conta de teste nao confirmada.'}
    $process.Dispose()
    $state['redefinida']=$true
    Save-State 'executando' 'validando_mobile'
    Write-Host ''
    Write-Host 'SENHA NOVA - guarde antes de fechar esta janela:' -ForegroundColor Yellow
    Write-Host ('Email: '+$original.email_teste)
    Write-Host ('Senha: '+$testPassword)
    Write-Host ('ID do aparelho: '+$original.dispositivo_id)
    $login=Request-Api 'POST' '/api/mobile/auth/login' @{email=$original.email_teste;senha=$testPassword;dispositivo_id=$original.dispositivo_id}
    $mobileToken=$login.access_token; $login=$null
    if(-not $mobileToken){throw 'Login sem token.'}
    $state['checks']+= 'login_mobile_200'
    $profile=(Request-Api 'GET' '/api/mobile/auth/me' $null $mobileToken).usuario
    if($profile.id -ne $original.criados.usuario_id -or $profile.empresa_id -ne $original.empresa_id -or $profile.papel -ne 'FUNCIONARIO'){throw 'Perfil inesperado.'}
    $state['checks']+= 'perfil_mobile_200'
    $snapshot=Request-Api 'GET' '/api/v1/mobile/sync' $null $mobileToken $DeviceUuid.ToString()
    if($snapshot.funcionario.id -ne $original.criados.funcionario_id -or $snapshot.modo_operacao -ne 'PESSOAL' -or @($snapshot.alocacoes | Where-Object {$_.id -eq $original.criados.alocacao_id}).Count -ne 1){throw 'Carga pessoal inesperada.'}
    [IO.File]::WriteAllText((Join-Path $root '.local/validation-bootstrap.json'), ($snapshot | ConvertTo-Json -Depth 40), (New-Object Text.UTF8Encoding($false)))
    $state['checks']+='bootstrap_pessoal_200'
    $null=Request-Api 'GET' '/api/v1/mobile/sync' $null $mobileToken ([Guid]::NewGuid().ToString()) 403
    $state['checks']+='uuid_incorreto_403'
    $null=Request-Api 'POST' '/api/mobile/marcacoes/lote' @{marcacoes=@()} $mobileToken $DeviceUuid.ToString() 400
    $state['checks']+='lote_vazio_400_sem_gravacao'
    $state['bootstrap_status']=[string]$snapshot.status
    $state['data_referencia']=[string]$snapshot.data_referencia
    Save-State 'sucesso' 'concluido'
    Write-Host 'Login, perfil, carga e autorizacao do aparelho validados. Nenhuma marcacao foi criada.' -ForegroundColor Green
} catch {
    $state['mensagem']=[string]$_.Exception.Message
    Save-State 'erro' $state['fase']
    Write-Host ('Falha: '+$_.Exception.Message) -ForegroundColor Red
} finally {
    $rhToken=$null; $mobileToken=$null; $testPassword=$null; $plain=$null; $credential=$null; $login=$null
}
