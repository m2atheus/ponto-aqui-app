# Ponto Aqui — aplicativo mobile

Flutter Android/iOS integrado exclusivamente à API Flask de `../Ponto-aqui`.
O fluxo pessoal usa aparelho previamente cadastrado, grava evidências primeiro
em SQLite e sincroniza marcações e selfies em filas independentes.

## Executar

Ambiente validado: Flutter 3.47.0, Dart 3.13.0. As versões resolvidas estão em
`pubspec.lock`; os pacotes foram conferidos na documentação dos mantenedores.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://SUA-API
```

Informe somente a origem Flask, sem `/api/web`, `/api/mobile` ou `/api/v1`.
Nenhuma senha, chave Supabase ou configuração de banco pertence ao aplicativo.
Sem configuração válida, a inicialização apresenta um estado de indisponibilidade.

Android emulador com Flask local:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000 --dart-define=ALLOW_DEV_HTTP=true
```

O Flask precisa estar acessível nessa porta. Em aparelho físico, use HTTPS ou
um endereço de desenvolvimento acessível na rede. Para HTTP em aparelho físico,
adicione **somente o host de desenvolvimento** ao XML em
`android/app/src/debug/res/xml/network_security_config.xml` e habilite a flag.
Produção rejeita HTTP mesmo com essa flag. O manifesto principal bloqueia tráfego
em texto claro; a exceção de rede existe exclusivamente no build debug.

No macOS, configure assinatura/equipe em `ios/Runner.xcworkspace` e execute:

```sh
flutter pub get
flutter run -d ID_DO_IPHONE --dart-define=API_BASE_URL=https://SUA-API
flutter build ios --no-codesign --dart-define=API_BASE_URL=https://SUA-API
```

A estrutura iOS foi gerada com Flutter. Câmera e localização em uso têm textos
de permissão em `Info.plist`. A compilação e os sensores iOS precisam ser
verificados em macOS/aparelho; não são executáveis no ambiente Windows atual.

## Aparência e tamanhos de tela

O aplicativo acompanha o tema do sistema por padrão. O botão **Configurações de
aparência**, disponível no login e na barra superior, permite forçar tema claro
ou escuro, ou voltar ao sistema. A preferência é mantida no aparelho, inclusive
após sair da conta. Falha ao salvar a preferência não impede a troca na sessão.

A Home usa uma coluna abaixo de 600 pixels lógicos e separa relógio e painel de
ações a partir de 600. Os botões pessoais ocupam a largura disponível no celular;
no tablet, podem formar duas colunas no painel lateral. Fonte ampliada reduz a
quantidade de colunas e a página continua rolável em telas baixas. A escolha de
Entrada, Saída ou Intervalo abre a confirmação do tipo correspondente. O modo
Relógio mostra os vínculos do funcionário autenticado no setor escolhido. Nenhum
funcionário registra ponto em nome de outra pessoa.

## Primeiro acesso real

1. O RH cria/vincula a conta de funcionário no Web Admin.
2. Abra o app e copie o UUID estável da instalação mostrado no login.
3. O RH autoriza esse aparelho para o funcionário e seus setores no Web Admin.
4. Entre no app com e-mail e senha. O app envia `device_uuid` automaticamente;
   não pede o ID interno do aparelho. O setor não é obrigatório no primeiro login.
5. A API emite o JWT; o app lê o `dispositivo_id` interno e confere os metadados
   contra a instalação/perfil, validando `/me` antes de persistir a sessão.
6. Com vários setores autorizados, escolha **Setor de trabalho**. A carga usa
   `sync?setor_id=...` sem trocar JWT. A escolha é persistida por conta/aparelho;
   o primeiro acesso ao setor exige rede, e os próximos podem usar seu cache válido.
7. No aparelho compartilhado, saia da conta antes do próximo funcionário entrar.
   A sessão, os vínculos e os envios são sempre da pessoa autenticada.

O modo é determinado pelo aparelho autorizado: `FUNCIONARIO` pode receber
PESSOAL ou RELOGIO; `USUARIO_SETOR` continua restrito ao relógio e não envia pontos
por terceiros. O app não cadastra, converte ou reativa aparelhos, não fabrica
claims e não implementa refresh fictício. Revogação/conversão recusada pela API
solicita novo login, preservando evidências pendentes.

## Operação e políticas explícitas

Para criar uma conta real de teste usando uma conta RH existente, há um
utilitário interativo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/criar_usuario_teste.ps1 -DeviceUuid UUID_COPIADO_DO_APP
```

O utilitário pede a senha RH em uma janela de credenciais, usa somente a API
local `http://127.0.0.1:5000` para criar funcionário/acesso/setor/escala/alocação,
e mostra as credenciais da **nova** conta no terminal. Não salva senha RH nem JWT.
O estado do processo, sem senhas/tokens, fica em `.local/usuario-teste-status.json`.

Esse utilitário legado de operação assistida fica fora do fluxo do aplicativo;
seu helper usa o backend local para vincular exclusivamente a conta de teste.
O fluxo normal usa a autorização manual do RH no Web Admin. Esses utilitários
não foram executados nos testes da integração compartilhada, que usam somente
HTTP simulado e SQLite de teste, sem credenciais ou banco remoto.

Os recursos de teste têm nomes próprios, alocação por 30 dias, `exige_selfie=false`
e localização ignorada pelo servidor somente no setor novo. A regra mobile de
selfie fora dos locais vinculados continua valendo nesse setor. Recursos anteriores
são preservados.
Uma falha pode deixar cadastros parciais; os IDs ficam no arquivo de estado,
sem exclusão automática nem redefinição de senhas existentes.

- Cada marcação recebe um UUID v4 e é confirmada localmente somente após commit.
- Hora original com offset, desvio, posição e flag offline não mudam no retry.
- `registrado_offline` congela o sinal de conectividade disponível na captura.
  Ele não afirma que a API estava acessível: Wi-Fi também pode estar sem internet.
- Offset = UTC do servidor menos UTC do aparelho no recebimento. Positivo
  significa aparelho atrasado. O W09 usa esse mesmo sinal e `offsetMs ~/ 1000`,
  truncando em direção a zero. A estimativa inclui latência e não altera o sistema.
- A captura exige carga com a data civil atual da empresa e amostra de relógio
  com idade entre zero e 24 horas. Sem amostra/carga, não há captura liberada.
- Uma sessão previamente validada pode operar offline dentro dessa política,
  inclusive sem renovar um JWT vencido. Uma resposta explícita 401/403 bloqueia
  novas capturas/envios até reautenticação. A aprovação futura não é garantida.
- Logout preserva a fila e os arquivos. Outra conta, empresa, API ou aparelho
  não consulta nem envia evidências do escopo anterior.
- A marcação pode ser `Aceita`, `PendenteAnalise` ou `Recusada` no servidor.
  Todas podem estar confirmadas no transporte. A classificação final é do servidor;
  o cálculo local de perímetro decide somente a necessidade da selfie.
- O app consulta o GPS para verificar presença em qualquer local das alocações
  vigentes do funcionário. Fora desses locais, a selfie é obrigatória. Se a
  localização não puder ser confirmada, também exige selfie. `exige_selfie=true`
  mantém a obrigatoriedade mesmo dentro do local.
- A foto só é dispensada se a posição e sua margem de precisão couberem em um
  dos raios cadastrados, com precisão de até 100 metros. A regra funciona com a
  carga offline válida e não consulta locais de outras empresas ou funcionários.
- Permissão negada, GPS desligado e timeout viram evidência local de ausência;
  nenhuma coordenada artificial é criada. `ignorar_localizacao` continua sendo
  uma política de classificação do servidor; não dispensa a consulta do GPS
  necessária para decidir a selfie no app.
- Um aviso explica a exigência antes de abrir a câmera frontal. Cancelar o aviso,
  negar a câmera ou cancelar a foto impede salvar a marcação. Fotos exigidas são
  capturadas pela câmera, orientadas/redimensionadas e
  preparadas em JPEG uma vez, com SHA-256. Reenvios usam os mesmos bytes privados.
- A foto só é enviada após confirmação da marcação. Upload recusado não recria
  nem apaga a marcação. Fotos recuperadas de uma câmera interrompida são guardadas
  separadamente e nunca vinculadas a uma marcação inventada.
- Não há exclusão automática de evidências, incluindo fotos confirmadas, nesta
  versão. A retenção local é contínua; política de expurgo deve ser acordada com a
  empresa antes de adicionar limpeza. Evidências pendentes nunca expiram no app.
- JWT e contexto de sessão ficam em armazenamento seguro do sistema. Banco e
  fotos ficam no diretório privado persistente do app; SQLite não usa SQLCipher.
  Android desabilita backup automático. Não há logs de senha/JWT.
- Sincronização ocorre na abertura, retorno ao foreground, reconexão, captura e
  comando manual. Em foreground, um timer verifica retries vencidos a cada 15s.
  Não há garantia de execução com o app encerrado.

## Transporte

Lotes de até 50 eventos; até três lotes por execução. A fila usa lease de dois
minutos por lote e recupera leases vencidos após interrupção. Selfies são
reivindicadas uma a uma, até três por execução. Todos os retries preservam bytes
e UUIDs. Há backoff exponencial de até 15 minutos com jitter; a ação manual
antecipa somente tentativas recuperáveis.

Uma resposta parcial confirma somente os itens coerentes com UUID, índice,
status, conteúdo original e `persistida:true`. 404/409/422 por item requerem ação
e não entram em loop. 401/403 suspendem a sessão. Timeout, 503 e respostas
inconsistentes conservam a evidência na fila.

## Arquitetura e banco

`lib/app` compõe dependências, tema e rotas protegidas. `core` contém configuração,
HTTP, armazenamento seguro, SQLite, relógio e sensores. `features` separa
autenticação, bootstrap, marcações, sincronização e escala. Views não executam
Dio/SQL; ViewModels expõem estados e ações. Captura e sincronização coordenam
repositórios e serviços testáveis.

O Drift contém snapshots por conta/aparelho/setor e a outbox por identidade.
Cada evento da outbox conserva sua alocação original; os novos também guardam
setor e nome em metadados locais imutáveis. Selecionar outro setor nunca reescreve
um evento nem reassocia sua selfie. O schema v2 acrescenta somente a seleção de
contexto: a migração preserva caches, eventos e referências aos arquivos de foto.
 A evidência é separada dos campos
de transporte, com trigger SQLite impedindo alterações de payload/metadados/
arquivo após inserção. Confirmações de cada resposta são aplicadas em transação.

O arquivo gerado está incluído no projeto. Após alterar o schema:

```powershell
dart run build_runner build
```

Ao mudar schema de uma versão distribuída, acrescente migração e testes antes de
incrementar `schemaVersion`. Não apague o banco para resolver incompatibilidades.

## Limites da API

- O modo relógio permite ao funcionário registrar somente suas próprias alocações
  no setor autorizado. Não oferece marcação coletiva nem funções administrativas.
- O login usa UUID e recebe os identificadores/contextos do JWT emitido pela API;
  autorização e revogação continuam sendo responsabilidade do backend.
- Uma alocação encerrada no dia anterior pode não estar na carga atual mesmo
  havendo madrugada de turno. O app não inventa um vínculo para contornar isso.
- O histórico é local mais os últimos 20 registros/7 dias da carga; não é um
  espelho completo. A escala é previsão da carga disponível, sem apuração local
  de feriados, afastamentos ou conflitos definitivos.
- A exigência de selfie por política do setor ou presença fora dos locais é
  aplicada na captura mobile. A API W09 não garante completude de selfie ao
  classificar uma marcação. Uma selfie não altera a política do setor: a API
  ainda pode recusar a batida fora do perímetro quando configurada para bloquear.
- Não há refresh fictício, acesso Supabase direto, edição/exclusão de pontos,
  substituição de selfies ou alteração de contratos públicos.

Consulte [contratos e decisões](docs/contratos.md).

## Verificar e compilar

```powershell
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --dart-define=API_BASE_URL=https://SUA-API
```

Os testes usam os dois exemplos W08 do backend, HTTP falso e SQLite real,
incluindo reabertura de arquivo, rollback, concorrência, isolamento, 207,
respostas incompletas, timeout depois do commit, duplicatas, permissões e selfie.
Eles não precisam de Flask, `.env`, Supabase ou credenciais reais.

A assinatura release continua sendo responsabilidade da distribuição. Não
publique uma compilação com a chave debug gerada pelo template Flutter.

Para gerar um APK de validação sem backend, use a origem reservada
`https://api.example.invalid`. Para uso com a empresa, compile com a URL real.
O fluxo completo foi testado com HTTP falso; câmera/GPS e
integração com uma API implantada ainda exigem validação em aparelho real.

Referências: [Flutter/MVVM](https://docs.flutter.dev/app-architecture/guide),
[offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first),
[Drift](https://drift.simonbinder.eu/dart_api/transactions/),
[Riverpod](https://riverpod.dev/docs/introduction/getting_started),
[pacotes e versões resolvidas](pubspec.lock).
