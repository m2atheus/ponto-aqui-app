# Validacao do Ponto Aqui em 02/11/2026

Projeto validado: `C:/Users/Matheus/Documents/GitHub/ponto_aqui_app/ponto-aqui-app`.
Backend local: `C:/Users/Matheus/Documents/GitHub/caminhos_de_maria_bonita/Ponto-aqui`.
Ambiente de compilacao: Flutter 3.47.8 / Dart 3.13.7, Windows.

| Verificacao executada | Resultado |
| --- | --- |
| `flutter analyze` | Sem problemas |
| `flutter test --reporter expanded` | 45 testes aprovados |
| APK debug, API `http://10.0.2.2:5000`, `ALLOW_DEV_HTTP=true` | Compilado |
| API local `GET /` | HTTP 200, aplicacao inicializada |
| Perfil, carga e lote sem token | HTTP 401 |
| Login de usuario inexistente | HTTP 401 |
| Login da conta de teste com aparelho cadastrado | HTTP 200 |
| Perfil mobile da conta de teste | HTTP 200, empresa e funcionario esperados |
| Carga pessoal com UUID cadastrado | HTTP 200, status `OK` |
| Carga com UUID incorreto | HTTP 403 |
| Lote autenticado sem marcacoes | HTTP 400 |
| Parser real do app sobre a carga recebida | Aprovado |
| Projecao da escala recebida para sete dias | Aprovada, uma alocacao estruturada |

A carga retornou a data civil `2026-11-02` no fuso `America/Sao_Paulo`, coerente
com o horario do servidor. Os testes automatizados cobrem autenticacao,
restauracao offline, isolamento, captura, persistencia SQLite, retries,
respostas parciais, escalas e widgets; usam transporte simulado.

A senha da conta de teste existente foi redefinida depois da autenticacao HTTP
de um RH ativo da mesma empresa. A senha nova foi exibida somente na janela
interativa. Nenhuma senha ou JWT foi gravado nos arquivos de estado.
A operacao preservou os vinculos da conta e nao criou marcacoes de ponto.
Nao houve alteracao em fontes, rotas, migrations ou schema do backend.

O APK esta em `build/app/outputs/flutter-apk/app-debug.apk`. Sua configuracao
aponta para a API local vista pelo emulador Android; para outro servidor,
compile novamente com a origem correspondente.

## Pendencias de execucao no Android

Nenhum dispositivo Android estava conectado. O comando `emulator -accel-check`
retornou codigo 6 e informou que o driver do hypervisor nao esta instalado.
O usuario preferiu configurar o emulador depois. Portanto, abertura do APK,
login pela interface e uso real de camera, GPS e sincronizacao offline no
Android nao foram validados nesta retomada. iOS tambem nao foi executado.

## Repetir a validacao autenticada

Execute na raiz do aplicativo, com a API local aberta:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/validar_api_teste.ps1 -BackendRoot "C:/Users/Matheus/Documents/GitHub/caminhos_de_maria_bonita/Ponto-aqui"
```

Esse comando pede a conta RH e redefine novamente SOMENTE a senha da conta de
teste identificada em `.local/usuario-teste-status.json`. Nao o execute apenas
para consultar o resultado anterior. O UUID padrao corresponde a instalacao do
emulador usada no cadastro anterior; o utilitario nao cadastra outro aparelho.

O resultado sem segredos fica em `.local/validation-api-live.json`. A carga
pessoal fica em `.local/validation-bootstrap.json`, ignorada pelo Git. Para
validar novamente essa carga usando o codigo do aplicativo:

```powershell
dart run tools/validar_carga.dart .local/validation-bootstrap.json
```

Uma carga salva valida o formato e a escala daquele momento; nao substitui
uma nova consulta ao servidor nem demonstra o funcionamento da interface.
