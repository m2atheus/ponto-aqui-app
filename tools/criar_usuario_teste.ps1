param(
    [Parameter(Mandatory = $true)][Guid]$DeviceUuid,
    [string]$ApiOrigin = 'http://127.0.0.1:5000',
    [string]$StatusFile
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $PSScriptRoot
$backend = [System.IO.Path]::GetFullPath((Join-Path $root '../Ponto-aqui'))
$python = Join-Path $backend '.venv/Scripts/python.exe'
$helper = Join-Path $PSScriptRoot 'vincular_aparelho_teste.py'
if (-not $StatusFile) { $StatusFile = Join-Path $root '.local/usuario-teste-status.json' }
$statusDirectory = Split-Path -Parent $StatusFile
[System.IO.Directory]::CreateDirectory($statusDirectory) | Out-Null
$state = [ordered]@{ estado = 'aguardando_rh'; fase = 'autenticacao'; criados = @{} }

function Write-State([string]$Status, [string]$Phase, [string]$Message = '') {
    $script:state['estado'] = $Status
    $script:state['fase'] = $Phase
    $script:state['mensagem'] = $Message
    # Somente estado/IDs: senhas e JWTs nunca sao escritos neste arquivo.
    $json = $script:state | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($StatusFile, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-Api([string]$Method, [string]$Path, $Body = $null, [string]$Token = '', [string]$Installation = '') {
    $headers = @{ Accept = 'application/json' }
    if ($Token) { $headers['Authorization'] = 'Bearer ' + $Token }
    if ($Installation) { $headers['X-Device-UUID'] = $Installation }
    $parameters = @{
        Method = $Method; Uri = $script:ApiOrigin + $Path; Headers = $headers
        TimeoutSec = 45; MaximumRedirection = 0; UseBasicParsing = $true
    }
    if ($null -ne $Body) {
        $parameters['Body'] = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10 -Compress))
        $parameters['ContentType'] = 'application/json; charset=utf-8'
    }
    try { return Invoke-RestMethod @parameters }
    catch {
        $message = 'Nao foi possivel acessar a API local.'
        if ($_.Exception.Response) {
            $response = $_.Exception.Response
            try {
                $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                $detail = ($reader.ReadToEnd() | ConvertFrom-Json).erro
                if ($detail.mensagem) { $message = [string]$detail.mensagem }
                $reader.Dispose()
            } catch { $message = 'A API recusou a operacao.' }
            $message = 'HTTP ' + [int]$response.StatusCode + ': ' + $message
        }
        # Nao serializar Request, Body, Headers ou a excecao HTTP completa.
        throw $message
    }
}

$rhToken = $null
$testToken = $null
$testPassword = $null
try {
    $uri = [Uri]$ApiOrigin
    if ($uri.Scheme -ne 'http' -or $uri.Host -notin @('127.0.0.1', 'localhost') -or $uri.Port -ne 5000 -or $uri.AbsolutePath -ne '/') {
        throw 'Este utilitario aceita somente a API local na porta 5000.'
    }
    $ApiOrigin = $uri.GetLeftPart([UriPartial]::Authority)
    if (-not (Test-Path -LiteralPath $python) -or -not (Test-Path -LiteralPath $helper)) {
        throw 'Ambiente Python do backend ou helper nao encontrado.'
    }
    Write-State 'aguardando_rh' 'autenticacao'
    Write-Host 'Cadastro real de usuario de teste no Ponto Aqui' -ForegroundColor Cyan
    Write-Host 'Informe a conta RH da empresa. A senha RH nao sera salva nem exibida.'
    Write-Host ('Instalacao: ' + $DeviceUuid.ToString())
    $credential = Get-Credential -Message 'Conta RH existente da empresa (API local Ponto Aqui)'
    if ($null -eq $credential) { throw 'Autenticacao cancelada.' }
    $plain = $credential.GetNetworkCredential().Password
    try {
        $login = Invoke-Api 'POST' '/api/web/auth/login' @{email = $credential.UserName; senha = $plain}
    } finally { $plain = $null; $credential = $null }
    $rhToken = $login.access_token
    $login = $null
    $profile = (Invoke-Api 'GET' '/api/web/auth/me' $null $rhToken).usuario
    if ($profile.papel -ne 'RH' -or -not $profile.empresa_id) {
        throw 'Use uma conta RH ativa da empresa. Nenhum cadastro foi criado.'
    }
    $companyId = [string]$profile.empresa_id
    $profile = $null
    $state['empresa_id'] = $companyId
    Write-State 'executando' 'cadastros'

    $zone = [System.TimeZoneInfo]::FindSystemTimeZoneById('E. South America Standard Time')
    $today = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $zone).Date
    $suffix = $today.ToString('yyyyMMdd') + '-' + ([Guid]::NewGuid().ToString('N').Substring(0, 6))
    $testEmail = 'mobile.teste.' + $suffix + '@example.invalid'
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $testPassword = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    [Array]::Clear($bytes, 0, $bytes.Length)

    $employee = (Invoke-Api 'POST' '/api/web/funcionarios' @{
        nome = 'Teste Mobile ' + $suffix; matricula = 'MOB-' + $suffix; cargo = 'Teste do aplicativo'; ativo = $true
    } $rhToken).funcionario
    $state['criados']['funcionario_id'] = [string]$employee.id
    Write-State 'executando' 'vinculando_acesso'
    $access = Invoke-Api 'POST' ('/api/v1/funcionarios/' + $employee.id + '/vincular-acesso') @{
        email = $testEmail; senha = $testPassword
    } $rhToken
    $userId = [string]$access.usuario.id
    $state['criados']['usuario_id'] = $userId
    $state['email_teste'] = $testEmail
    Write-Host ''
    Write-Host 'Credenciais NOVAS da conta de teste (guarde nesta janela):' -ForegroundColor Yellow
    Write-Host ('E-mail: ' + $testEmail)
    Write-Host ('Senha:  ' + $testPassword)
    Write-State 'executando' 'criando_vinculos'

    # Recursos exclusivos do teste: nenhum setor/escala/funcionario anterior e alterado.
    $sector = (Invoke-Api 'POST' '/api/web/setores' @{
        nome = 'Teste aplicativo ' + $suffix; endereco = 'Ambiente de teste mobile'
        latitude = -8.0; longitude = -35.0; raio_metros = 100
        exige_selfie = $false; ignorar_localizacao = $true
        acao_fora_perimetro = 'PENDENTE'; limite_desvio_relogio_segundos = 120; ativo = $true
    } $rhToken).setor
    $state['criados']['setor_id'] = [string]$sector.id
    $schedule = (Invoke-Api 'POST' '/api/web/escalas' @{
        nome = 'Teste 5x2 ' + $suffix; modelo = '5x2'; ativo = $true
        turnos = @(@{ hora_inicio = '08:00'; hora_fim = '17:00'; tempo_intervalo = 60
            fim_dia_seguinte = $false; dias_semana = @(1, 2, 3, 4, 5) })
    } $rhToken).escala
    $state['criados']['escala_id'] = [string]$schedule.id
    $allocation = (Invoke-Api 'POST' '/api/web/alocacoes' @{
        funcionario_id = [string]$employee.id; setor_id = [string]$sector.id; escala_id = [string]$schedule.id
        data_inicio = $today.AddDays(-1).ToString('yyyy-MM-dd'); data_fim = $today.AddDays(30).ToString('yyyy-MM-dd')
    } $rhToken).alocacao
    $state['criados']['alocacao_id'] = [string]$allocation.id
    Write-State 'executando' 'provisionando_aparelho'

    # Login de verdade pela API; o helper recebe o JWT por stdin, nunca por argv/arquivo.
    $personal = Invoke-Api 'POST' '/api/mobile/auth/login' @{email = $testEmail; senha = $testPassword}
    $testToken = $personal.access_token
    $personal = $null
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $python
    $start.Arguments = '-B "' + $helper + '" --backend-root "' + $backend + '"'
    $start.WorkingDirectory = $backend
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $start.EnvironmentVariables['PYTHONUTF8'] = '1'
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    $process.Start() | Out-Null
    $process.StandardInput.WriteLine((@{access_token = $testToken; usuario_id = $userId
        empresa_id = $companyId; device_uuid = $DeviceUuid.ToString()} | ConvertTo-Json -Compress))
    $process.StandardInput.Close()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) { $process.Kill(); throw 'O provisionamento excedeu o tempo limite. Os cadastros anteriores foram preservados.' }
    $output = $stdoutTask.GetAwaiter().GetResult()
    $null = $stderrTask.GetAwaiter().GetResult()
    $provision = $output | ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or -not $provision.ok) { throw ([string]$provision.erro) }
    $process.Dispose()
    $deviceId = [string]$provision.dispositivo_id
    $state['dispositivo_id'] = $deviceId
    Write-Host ('ID cadastrado do aparelho: ' + $deviceId) -ForegroundColor Yellow
    Write-State 'executando' 'validando_api_mobile'

    $personal = Invoke-Api 'POST' '/api/mobile/auth/login' @{
        email = $testEmail; senha = $testPassword; dispositivo_id = $deviceId
    }
    $testToken = $personal.access_token
    $personal = $null
    $snapshot = Invoke-Api 'GET' '/api/v1/mobile/sync' $null $testToken $DeviceUuid.ToString()
    if ($snapshot.funcionario.id -ne $employee.id -or $snapshot.modo_operacao -ne 'PESSOAL' -or
        @($snapshot.alocacoes | Where-Object { $_.id -eq $allocation.id }).Count -ne 1) {
        throw 'O cadastro foi gravado, mas o bootstrap retornou um contexto inesperado.'
    }
    $state['bootstrap_status'] = [string]$snapshot.status
    Write-State 'sucesso' 'concluido' 'Login mobile e carga inicial validados pela API.'
    Write-Host ''
    Write-Host 'Cadastro concluido e validado na API. Use as credenciais e o ID acima no app.' -ForegroundColor Green
    Write-Host 'Setor exclusivo do teste: sem selfie obrigatoria e com localizacao dispensada.'
    Write-Host ('Alocacao valida ate ' + $today.AddDays(30).ToString('dd/MM/yyyy') + '.')
} catch {
    Write-State 'erro' $state['fase'] ([string]$_.Exception.Message)
    Write-Host ('Falha: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Os IDs dos cadastros ja criados foram preservados no arquivo de estado. Nao houve exclusao automatica.'
} finally {
    $rhToken = $null; $testToken = $null; $testPassword = $null
    $plain = $null; $credential = $null; $personal = $null; $login = $null
}
