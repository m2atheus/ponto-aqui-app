# Contratos verificados e decisões

Fonte de verdade: código local de `../Ponto-aqui/app`, rotas, Services e testes.
Não houve alteração de backend, execução de migration ou contato com banco online.

| Operação | Caminho | Body | Sucesso |
| --- | --- | --- | --- |
| Login | POST `/api/mobile/auth/login` | email, senha, dispositivo_id | 200: access_token, token_type, usuario |
| Perfil | GET `/api/mobile/auth/me` | nenhum | 200: usuario |
| Carga | GET `/api/v1/mobile/sync` | nenhum | 200: DTO pessoal/relógio |
| Lote | POST `/api/mobile/marcacoes/lote` | marcacoes: array W09 | 200/207: resultados |
| Selfie | POST `/api/mobile/marcacoes/{evento_cliente_id}/selfie` | multipart selfie | 201 nova, 200 duplicata |

Todas as operações protegidas usam Bearer JWT. O cliente envia X-Device-UUID
nessas operações, mas somente W08 exige esse header no middleware atual.
Não há prefixo `/api/v1` global. O cliente não segue redirects e rejeita requests
a outra origem antes de enviar o token.

O login aceita `dispositivo_id` previamente registrado, não `device_uuid` ou nome
do aparelho. `sub` é `Usuarios.id`; `Funcionarios.id` tem identidade distinta.
O UUID da instalação também difere da PK de `Dispositivos`.

O DTO W08 é baseado no Dart portátil existente no painel, acrescido de validação
de listas obrigatórias, status, duração de turnos e referências de ciclos. O
repositório confere IANA, identidade e modo antes de substituir o cache inteiro
em transação. Erro de rede/parsing preserva a última carga válida. Uma resposta
401/403 bloqueia a sessão, preservando cache e outbox separadamente.

Itens W09 contêm somente evento_cliente_id, dispositivo_id, alocacao_id, tipo,
ocorrido_em, desvio_relogio_segundos, registrado_offline e posicao opcional/nula.
Metadados locais jamais entram no body. As situações de negócio não se confundem
com na_fila, enviando, confirmada e erro_requer_acao.

As respostas 200/201 por item exigem persistida:true, UUID/índice correspondentes,
registro_id UUID, duplicada coerente, situação/motivos válidos e os valores
originais de hora, offset, desvio e offline. Ausentes/ambíguos não são confirmados.

Diferenças documentais encontradas:

- W09 descreve `sub` como UUID de funcionário; Services usam UUID da conta.
- W01/W04 contêm descrições anteriores aos CRUDs administrativos atuais.
- Já existe vinculação de acesso pelo RH em
  `/api/v1/funcionarios/{id}/vincular-acesso`; não é provisionamento do aparelho.
- Já existem ajustes RH em `/api/v1/admin/ponto-manual` e `/ponto-correcao`,
  separados dos registros imutáveis; não são solicitação mobile do funcionário.
- Bootstrap filtra vigência civil atual. Sua presença não garante que o vínculo
  tenha `usuario_id` compatível com o autorizador W09; o erro remoto é preservado.

Para automatizar provisionamento, será necessário apresentar e aprovar uma
extensão mobile que valide senha, registre/revogue aparelho com o Service W07 e
retorne a identidade do dispositivo antes de emitir JWT. A decisão precisa
contemplar filas antigas e selfies de aparelhos revogados. Nada disso é simulado
no cliente atual.


## Selfie por presença no local vinculado

A captura mobile exige selfie quando a posição estiver fora de todos os locais
vinculados ao funcionário com alocação vigente na data civil da carga. A API W08
não expõe um catálogo de todos os locais da empresa; somente as alocações do
funcionário são consideradas. A escolha da alocação enviada no evento permanece
explícita: estar dentro de outro local vinculado não muda a alocação da batida.

A presença é confirmada apenas com posição válida, precisão até 100 metros e
círculo de precisão inteiro dentro do raio de pelo menos um local. Ausência de
posição, GPS indisponível, permissão negada, baixa precisão ou margem cruzando
um limite exigem selfie. O cálculo Haversine usa raio terrestre de 6371008.8 m,
igual ao Service do servidor, sem definir Aceita/PendenteAnalise/Recusada.
`exige_selfie=true` mantém a foto obrigatória também dentro do local. A consulta
de GPS ocorre mesmo com `ignorar_localizacao=true`, que permanece uma política
de classificação do backend.

O aviso de selfie permite cancelar antes de abrir a câmera. Sem captura bem
sucedida não se salva evento na outbox. Foto e hash são preparados antes do
commit local e seguem a fila independente já existente, após confirmação do
ponto. Os metadados locais registram presença e motivo da exigência sem acrescentar
campos ao payload HTTP nem alterar evidências antigas.

A exigência condicional é do cliente. O backend atual recebe marcação e foto em
requisições separadas e não aplica essa exigência na classificação. Em particular,
selfie não converte ponto recusado por política de bloqueio em ponto aceito.
Não houve alteração de rotas, migrations, cadastros ou políticas do banco nesta
implementação. Uma regra obrigatória também para outros clientes precisará ser
implementada no servidor.
