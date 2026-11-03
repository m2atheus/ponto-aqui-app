# Integracao compartilhada multissetor - 03/11/2026

## O que estava incompativel

- Login exigia o ID interno do aparelho em vez do UUID estavel da instalacao.
- O parsing de RELOGIO ja estava corrigido, mas Home, vinculos, captura e escala
  ainda dependiam dos campos de PESSOAL.
- Faltavam a escolha da propria alocacao no catalogo do relogio, a selecao
  persistida de setor e o isolamento do cache por contexto.
- Respostas atrasadas e workers de contas distintas precisavam de isolamento.

## Resultado

O app existente autentica com email, senha e device_uuid. Le os identificadores
emitidos no JWT e confere perfil e aparelho, validando /me antes de persistir a
sessao. Nao cria claims, nao provisiona aparelhos e nao exige setor no primeiro
acesso. O UUID permanece disponivel para copiar; erros de login sao genericos.

Em RELOGIO, employeeFor identifica a pessoa pelo usuario_id da sessao e
allocationsFor resolve somente suas alocacoes e referencias ao catalogo de
escalas. Nao se escolhe o primeiro funcionario. Pessoas sem conta ou alocacoes
de terceiros nao habilitam captura. data_fim nula e aceita. FUNCIONARIO continua
compativel com PESSOAL/RELOGIO; USUARIO_SETOR permanece restrito ao relogio e nao
envia pontos por terceiros. Perfis administrativos continuam rejeitados.

O seletor de setor usa GET /api/v1/mobile/sync?setor_id=... sem trocar o JWT.
A escolha persiste por identidade/aparelho. O cache do relogio acrescenta o setor
ao escopo de API/empresa/usuario/instalacao/aparelho. Um setor unico e adotado
automaticamente. Respostas de selecoes anteriores sao descartadas antes de alterar
estado ou cache. Sem cache de B, uma falha ao carregar B nao reaproveita A.
Cargas antigas sem setores_disponiveis continuam legiveis no contexto correto.

A migracao SQLite v1 para v2 apenas cria selected_contexts. Preserva caches,
marcacoes, fotos, referencias aos arquivos e o trigger de imutabilidade.

A outbox mantem o escopo da identidade e o alocacao_id original de cada evento.
Novas capturas tambem registram setor/nome em metadados locais imutaveis, sem
acrescentar campos ao payload HTTP. Trocar setor nunca reescreve uma batida.
Trocar conta nao envia a fila anterior. Uma requisicao ja enviada antes do logout
pode concluir para sua conta original; nenhuma nova foto dessa conta sai apos
a troca. Workers de identidades distintas nao compartilham filas ou JWT.

Selfies continuam vinculadas ao evento original, com fila independente apos a
confirmacao da batida e os mesmos bytes/hash nos retries. O setor atualmente
selecionado nao e anexado ao lote ou ao upload. persistida:true com Recusada em
HTTP 207 e confirmada no transporte, sem reenvio indefinido. Hora original,
desvio e flag offline permanecem congelados.

401/403 bloqueiam a sessao; DISPOSITIVO_MODO_ALTERADO orienta novo login.
Rede/503 e parsing preservam os dados pendentes. A classificacao definitiva
permanece no servidor. Diagnosticos sanitizados e suas regressoes foram mantidos.

## Arquivos ajustados

| Arquivo | Ajuste |
| --- | --- |
| lib/features/auth/data/auth_repository.dart | Login UUID, JWT e /me |
| lib/features/auth/domain/mobile_session.dart | Contexto inicial e setores do token |
| lib/features/auth/presentation/auth_view_model.dart | Login sem ID interno informado |
| lib/features/auth/presentation/login_view.dart | Remove campo ID e preserva copia do UUID |
| lib/core/network/mobile_api.dart | Parametros de query |
| lib/features/bootstrap/data/bootstrap_repository.dart | Cache/selecoes por setor e descarte de respostas obsoletas |
| lib/features/bootstrap/domain/bootstrap_snapshot.dart | Proprio funcionario e alocacoes em ambos os modos |
| lib/features/bootstrap/presentation/work_view_model.dart | Troca de contexto e recusas de acesso |
| lib/features/marcacoes/domain/capture_punch.dart | Captura propria e metadados originais |
| lib/features/marcacoes/presentation/work_views.dart | Home, setor, vinculos, escala e fila da propria conta |
| lib/features/sincronizacao/domain/sync_worker.dart | Workers por identidade |
| lib/core/database/app_database.dart | Migracao aditiva v2 |
| lib/core/database/app_database.g.dart | Codigo Drift regenerado |
| test/shared_device_test.dart | 21 cenarios novos de integracao |
| test/auth_bootstrap_test.dart | Contrato atualizado do login |
| test/login_widget_test.dart | Login e captura propria no relogio |
| test/support.dart | JWTs ficticios para HTTP simulado |
| test/theme_responsive_test.dart | Acoes proprias na Home do relogio |
| README.md e docs/contratos.md | Fluxos atualizados |

## Validacao concluida

- flutter analyze: nenhum problema.
- flutter test --reporter expanded: 116 testes aprovados.
- dart run build_runner build: codigo Drift atualizado.
- flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5000 --dart-define=ALLOW_DEV_HTTP=true: sucesso.
- APK: build/app/outputs/flutter-apk/app-debug.apk.

Testes cobrem login UUID, propria alocacao fora da primeira posicao, vigencia
indeterminada, dois setores/politicas, selecao persistida, resposta atrasada,
uso offline sem misturar contextos, migracao, revogacao/conversao, troca de conta
e retries imutaveis de batida/selfie.

Foram usados somente HTTP simulado, JWTs ficticios e SQLite de teste. Nenhuma
credencial real foi utilizada. Backend, rotas, migrations e dados remotos nao
foram alterados. Camera/GPS fisicos e chamadas autenticadas contra a API real
nao foram exercitados nesta validacao.
