# Diagnostico de parsing da carga mobile - 03/11/2026

## Causa reproduzida

O backend atual determina o modo pelo aparelho autorizado, nao apenas pelo papel
da conta. Uma conta `FUNCIONARIO` com vinculo ativo pode receber `RELOGIO`.
O app tinha uma comparacao que exigia `PESSOAL` para todo `FUNCIONARIO`.

A reproducao usou a fixture de relogio, acrescida de `setores_disponiveis`,
transporte HTTP simulado e SQLite em memoria. Nao foi necessario consultar ou
alterar dados reais nem obter credenciais do usuario.

Antes da correcao, o diagnostico registrou esta excecao e stack trace:

```text
[bootstrap.parse][api] modo=RELOGIO papel=FUNCIONARIO
FormatException: Modo incompatível com a sessão.
#0      BootstrapRepository._parse (package:ponto_aqui_app/features/bootstrap/data/bootstrap_repository.dart:62:7)
#1      BootstrapRepository.refresh (package:ponto_aqui_app/features/bootstrap/data/bootstrap_repository.dart:107:13)
<asynchronous suspension>
#2      main.<anonymous closure> (file:///C:/Users/Matheus/Documents/GitHub/ponto_aqui_app/ponto-aqui-app/test/bootstrap_clock_test.dart:29:22)
<asynchronous suspension>
#3      Declarer.test.<anonymous closure>.<anonymous closure> (package:test_api/src/backend/declarer.dart:253:15)
<asynchronous suspension>
#4      Declarer.test.<anonymous closure> (package:test_api/src/backend/declarer.dart:250:11)
<asynchronous suspension>
#5      Invoker._waitForOutstandingCallbacks.<anonymous closure> (package:test_api/src/backend/invoker.dart:318:9)
<asynchronous suspension>
```

As linhas acima correspondem a versao anterior a correcao. O mesmo teste passou
depois da mudanca. Essa reproducao confirma a incompatibilidade do codigo;
nao representa captura de uma nova resposta autenticada do aparelho do usuario.

## Contratos por modo

- `PESSOAL` interpreta o funcionario, suas alocacoes, o resumo de escala e as
  marcacoes recentes. A identidade pessoal continua conferida contra a sessao.
- `RELOGIO` interpreta `setor`, `funcionarios`, `escalas` e o catalogo resumido
  `setores_disponiveis` (somente `id` e `nome`). Nao exige nem interpreta campos
  exclusivos de PESSOAL. As alocacoes de cada funcionario do relogio continuam
  obrigatorias, com referencias validas ao catalogo de escalas.
- O catalogo de setores e preservado no cache. Cargas antigas sem esse campo
  continuam legiveis. Quando fornecido, precisa ser uma lista de identificadores
  unicos; um catalogo nao vazio precisa conter o setor corrente.
- `FUNCIONARIO` pode receber os dois modos autorizados pela API. `USUARIO_SETOR`
  continua restrito ao relogio. Papeis administrativos e desconhecidos continuam
  rejeitados pelo repositorio. Nao se fabricam claims nem se relaxa o autorizador
  do servidor.

## Consultar os logs

Em desenvolvimento, procure `[bootstrap.parse]` no terminal do `flutter run` ou
no Debug Console. No DevTools, o logger se chama `ponto_aqui.bootstrap`.
O sufixo `[api]` identifica carga recebida e `[cache]` identifica carga local.
Os logs incluem modo, papel, tipo e mensagem completa da excecao e stack trace.
O texto pode ser dividido em varias linhas pelo console, mas nao e truncado pelo
relator. `FormatException.offset` e preservado quando disponivel.

O relator nao imprime sessao, cabecalhos ou corpo JSON. O campo
`FormatException.source` e omitido porque pode conter a resposta inteira.
O token da sessao e valores sensiveis encontrados no payload sao removidos da
mensagem e do stack trace; padroes Bearer/JWT e atribuicoes de credenciais tambem
sao ocultados. Somente strings sanitizadas chegam aos loggers. Nao ha arquivo
persistente automatico com resposta ou credenciais.

Uma falha de parsing preserva a carga anterior e retorna a mesma mensagem segura
na interface. Uma falha no proprio logger tambem nao altera o cache nem substitui
a excecao controlada. Falhas HTTP de autenticacao continuam no fluxo 401/403.

## Validacao

- Regressao antes da correcao: falhou com `Modo incompativel com a sessao`.
- Regressao apos a correcao e cenarios de parsing/privacidade: 23 testes passaram.
- Suite completa: 94 testes passaram.
- Analise estatica: nenhum problema encontrado.
- APK Android debug: compilado com sucesso.

Nenhum fonte, rota, migration, politica ou cadastro do backend foi alterado.
