import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/app_runtime.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../bootstrap/data/mobile_sync_dto.dart';
import '../../bootstrap/domain/bootstrap_snapshot.dart';
import '../../bootstrap/presentation/work_view_model.dart';
import '../../escala/domain/schedule_projector.dart';
import '../domain/punch_event.dart';

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
const _paths = ['/inicio', '/historico', '/fila', '/escala'];

class WorkShell extends ConsumerStatefulWidget {
  const WorkShell({required this.path, required this.child, super.key});
  final String path;
  final Widget child;
  @override
  ConsumerState<WorkShell> createState() => _WorkShellState();
}

class _WorkShellState extends ConsumerState<WorkShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = ref.read(authProvider).asData?.value;
    if (session != null) {
      final vm = ref.read(workProvider(session.scope).notifier);
      vm.setForeground(state == AppLifecycleState.resumed);
      if (state == AppLifecycleState.resumed) unawaited(vm.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).asData?.value;
    if (session == null) return const SizedBox.shrink();
    final state = ref.watch(workProvider(session.scope));
    final rows = ref.watch(eventsProvider(session.scope)).asData?.value ?? [];
    final pending = rows
        .where(
          (r) =>
              r.transport != 'confirmada' ||
              [
                'na_fila',
                'enviando',
                'erro_requer_acao',
              ].contains(r.photoTransport),
        )
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/brand/symbol.png', width: 32, height: 32),
            const SizedBox(width: 10),
            const Text(
              'Ponto Aqui',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (state.busy)
            const Padding(
              padding: EdgeInsets.all(18),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Atualizar e sincronizar',
              onPressed: session.canSend
                  ? () => ref
                        .read(workProvider(session.scope).notifier)
                        .synchronize(manual: true)
                  : null,
              icon: const Icon(Icons.sync),
            ),
          PopupMenuButton<String>(
            tooltip: 'Conta',
            onSelected: (_) => ref.read(authProvider.notifier).logout(),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Text('Sair da conta'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!session.canSend)
              _Notice(
                session.blockedReason!,
                action: TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Entrar novamente'),
                ),
              ),
            if (ref.read(runtimeProvider).recoveredPhotos > 0)
              const _Notice(
                'Uma captura foi interrompida. A foto foi preservada em armazenamento privado; refaça a marcação.',
              ),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _paths.contains(widget.path)
            ? _paths.indexOf(widget.path)
            : 0,
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.cloud_upload_outlined),
            ),
            label: 'Fila',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Escala',
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4DF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(text), ?action],
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: children
            .expand((w) => [w, const SizedBox(height: 16)])
            .toList(),
      ),
    ),
  );
}

class HomeView extends ConsumerWidget {
  const HomeView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).asData?.value;
    if (session == null) return const SizedBox.shrink();
    final state = ref.watch(workProvider(session.scope));
    final snapshot = state.snapshot;
    final restriction = snapshot?.captureRestriction(DateTime.now().toUtc());
    return _Page(
      children: [
        Text(
          'Olá, ${session.name.split(' ').first}',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          snapshot?.data.funcionario == null
              ? session.email
              : '${snapshot!.data.funcionario!.nome} · Matrícula ${snapshot.data.funcionario!.matricula}',
          style: const TextStyle(color: Brand.muted),
        ),
        if (snapshot != null) _ClockCard(snapshot: snapshot),
        if (state.message != null) _Notice(state.message!),
        if (snapshot == null)
          const _Notice(
            'A primeira carga válida exige internet e aparelho autorizado. Toque em atualizar após o provisionamento.',
          ),
        if (restriction != null) _Notice(restriction),
        if (snapshot?.data.modoOperacao == ModoOperacao.relogio)
          _ClockMode(snapshot: snapshot!)
        else ...[
          if (snapshot != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seus vínculos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (snapshot.data.alocacoes.isEmpty)
                      Text(snapshot.data.mensagemStatus),
                    for (final allocation in snapshot.data.alocacoes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Brand.teal,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    allocation.setor.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    allocation.escala?.nome ??
                                        'Sem escala cadastrada',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          FilledButton.icon(
            onPressed:
                snapshot != null && restriction == null && session.canSend
                ? () => context.go('/registrar')
                : null,
            icon: const Icon(Icons.touch_app_outlined),
            label: const Text('Registrar ponto'),
          ),
          const Text(
            'Toda marcação é salva primeiro no aparelho. A situação será definida pelo servidor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.muted),
          ),
        ],
      ],
    );
  }
}

class _ClockCard extends StatefulWidget {
  const _ClockCard({required this.snapshot});
  final BootstrapSnapshot snapshot;
  @override
  State<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<_ClockCard> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final now = tz.TZDateTime.from(
      snapshot.clock.estimate(DateTime.now()),
      tz.getLocation(snapshot.data.fusoHorario),
    );
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Brand.navy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HORÁRIO ESTIMADO DA EMPRESA',
            style: TextStyle(
              color: Color(0xFFAFC9E1),
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _time(now),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 54,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_date(now)}/${now.year} · ${snapshot.data.fusoHorario}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Carga de ${snapshot.data.dataReferencia} · Amostra ${_time(snapshot.clock.receivedAt.toLocal())}',
            style: const TextStyle(color: Color(0xFFAFC9E1), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class CaptureView extends ConsumerStatefulWidget {
  const CaptureView({super.key});
  @override
  ConsumerState<CaptureView> createState() => _CaptureViewState();
}

class _CaptureViewState extends ConsumerState<CaptureView> {
  String? _allocation;
  PunchType _type = PunchType.entrada;
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).asData?.value;
    if (session == null) return const SizedBox.shrink();
    final state = ref.watch(workProvider(session.scope));
    final snapshot = state.snapshot;
    final allocations = snapshot?.data.alocacoes ?? <AlocacaoPessoalSyncDto>[];
    final selected =
        allocations.where((a) => a.id == _allocation).firstOrNull ??
        (allocations.length == 1 ? allocations.single : null);
    final restriction =
        snapshot?.captureRestriction(DateTime.now().toUtc()) ??
        (snapshot == null ? 'Atualize os dados antes de registrar.' : null);
    return _Page(
      children: [
        Text(
          'Registrar ponto',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (restriction != null) _Notice(restriction),
        if (state.message != null) _Notice(state.message!),
        DropdownButtonFormField<String>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Vínculo de trabalho'),
          items: allocations
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(a.setor.nome, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: state.capturing
              ? null
              : (id) => setState(() => _allocation = id),
        ),
        ...PunchType.values.map(
          (type) => Card(
            child: ListTile(
              enabled: !state.capturing,
              selected: type == _type,
              selectedTileColor: const Color(0xFFE7F5F3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              leading: Icon(switch (type) {
                PunchType.entrada => Icons.login,
                PunchType.saida => Icons.logout,
                PunchType.inicioIntervalo => Icons.coffee_outlined,
                PunchType.fimIntervalo => Icons.work_outline,
              }),
              title: Text(type.label),
              trailing: Icon(
                type == _type
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              onTap: () => setState(() => _type = type),
            ),
          ),
        ),
        if (selected != null)
          Text(
            selected.setor.politicas.exigeSelfie
                ? 'Esta marcação exige selfie pela câmera. A localização será solicitada conforme a política do setor.'
                : selected.setor.politicas.ignorarLocalizacao
                ? 'A localização é dispensada pela política do setor.'
                : 'A localização será capturada uma vez. A ausência ou baixa precisão será informada ao servidor.',
          ),
        FilledButton.icon(
          onPressed:
              state.capturing ||
                  selected == null ||
                  restriction != null ||
                  !session.canSend
              ? null
              : () async {
                  final ok = await ref
                      .read(workProvider(session.scope).notifier)
                      .capture(selected.id, _type);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Salvo no aparelho. A confirmação do servidor pode chegar depois.',
                        ),
                      ),
                    );
                    context.go('/fila');
                  }
                },
          icon: state.capturing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(
            state.capturing
                ? 'Capturando evidências…'
                : 'Confirmar ${_type.label.toLowerCase()}',
          ),
        ),
      ],
    );
  }
}

class QueueView extends ConsumerWidget {
  const QueueView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).asData?.value;
    if (session == null) return const SizedBox.shrink();
    final rows = ref.watch(eventsProvider(session.scope));
    final state = ref.watch(workProvider(session.scope));
    return _Page(
      children: [
        Text(
          'Fila de sincronização',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'Marcações e fotos têm confirmações separadas. Itens que exigem ação permanecem preservados para suporte.',
        ),
        OutlinedButton.icon(
          onPressed: state.busy || !session.canSend
              ? null
              : () => ref
                    .read(workProvider(session.scope).notifier)
                    .synchronize(manual: true),
          icon: const Icon(Icons.sync),
          label: const Text('Sincronizar agora'),
        ),
        if (state.message != null) _Notice(state.message!),
        ...rows.when(
          data: (items) => items.isEmpty
              ? [
                  const _Notice(
                    'Nenhuma marcação local neste aparelho para esta conta.',
                  ),
                ]
              : items.reversed.map((r) => _EventCard(row: r)).toList(),
          error: (_, _) => [
            const _Notice('Não foi possível ler a fila. Tente novamente.'),
          ],
          loading: () => [const Center(child: CircularProgressIndicator())],
        ),
      ],
    );
  }
}

class HistoryView extends ConsumerWidget {
  const HistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).asData?.value;
    if (session == null) return const SizedBox.shrink();
    final local = ref.watch(eventsProvider(session.scope));
    final snapshot = ref.watch(workProvider(session.scope)).snapshot;
    final ids = (local.asData?.value ?? []).map((r) => r.eventId).toSet();
    final remote =
        snapshot?.data.marcacoesRecentes
            .where((r) => !ids.contains(r.eventoClienteId))
            .toList() ??
        [];
    return _Page(
      children: [
        Text(
          'Suas marcações',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'Histórico local e registros recentes da última carga. Este resumo não é o espelho mensal.',
        ),
        ...local.when(
          data: (rows) => rows.map((r) => _EventCard(row: r)).toList(),
          loading: () => [const Center(child: CircularProgressIndicator())],
          error: (_, _) => [const _Notice('Histórico local indisponível.')],
        ),
        for (final event in remote)
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: Text(
                '${_label(event.tipo)} · ${_situation(event.situacao)}',
              ),
              subtitle: Text(
                '${_date(event.ocorridoEm.toLocal())} às ${_time(event.ocorridoEm.toLocal())}\n${event.motivos.join(', ')}',
              ),
            ),
          ),
        if ((local.asData?.value ?? []).isEmpty && remote.isEmpty)
          const _Notice('Ainda não há marcações para exibir.'),
      ],
    );
  }
}

String _label(String type) =>
    PunchType.values.where((t) => t.wire == type).firstOrNull?.label ?? type;
String _situation(String value) => switch (value) {
  'Aceita' => 'Aceita',
  'PendenteAnalise' => 'Pendente de análise',
  'Recusada' => 'Recusada',
  _ => value,
};

class _EventCard extends StatelessWidget {
  const _EventCard({required this.row});
  final OutboxEvent row;
  @override
  Widget build(BuildContext context) {
    final evidence = jsonDecode(row.payload) as Map<String, dynamic>;
    final receipt = row.receipt == null
        ? null
        : jsonDecode(row.receipt!) as Map<String, dynamic>;
    final metadata = jsonDecode(row.metadata) as Map<String, dynamic>;
    final time = DateTime.parse(evidence['ocorrido_em'] as String).toLocal();
    final confirmed = row.transport == 'confirmada';
    final title = switch (row.transport) {
      'confirmada' =>
        'Sincronizado · ${_situation(receipt?['situacao'] as String? ?? '')}',
      'enviando' => 'Enviando',
      'erro_requer_acao' => 'Requer ação',
      _ => 'Salvo no aparelho',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  confirmed ? Icons.cloud_done_outlined : Icons.phone_android,
                  color: Brand.teal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_label(evidence['tipo'] as String)} · ${_date(time)} ${_time(time)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title),
            if (receipt != null && (receipt['motivos'] as List).isNotEmpty)
              Text((receipt['motivos'] as List).join(', ')),
            if (row.photoTransport != 'sem_foto')
              Text(
                'Selfie: ${switch (row.photoTransport) {
                  'confirmada' => 'sincronizada',
                  'erro_requer_acao' => 'requer ação',
                  'enviando' => 'enviando',
                  _ => 'salva no aparelho, aguardando envio',
                }}',
              ),
            if (metadata['localizacao_status'] != null)
              Text(
                'Localização: ${(metadata['localizacao_status'] as String).replaceAll('_', ' ')}',
                style: const TextStyle(fontSize: 12, color: Brand.muted),
              ),
            if (row.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(row.lastError!),
              ),
            if (row.lastAttemptMs != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Última tentativa: ${_date(DateTime.fromMillisecondsSinceEpoch(row.lastAttemptMs!))} ${_time(DateTime.fromMillisecondsSinceEpoch(row.lastAttemptMs!))} · ${row.attempts} envio(s)',
                  style: const TextStyle(fontSize: 12, color: Brand.muted),
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Identificador para suporte',
                style: TextStyle(fontSize: 12),
              ),
              children: [SelectableText(row.eventId)],
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleView extends ConsumerWidget {
  const ScheduleView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).asData?.value;
    if (session == null) return const SizedBox.shrink();
    final snapshot = ref.watch(workProvider(session.scope)).snapshot;
    return _Page(
      children: [
        Text('Sua escala', style: Theme.of(context).textTheme.headlineMedium),
        const Text(
          'Projeção informativa a partir da última carga. Dias futuros podem mudar; feriados e afastamentos são apurados pelo servidor.',
        ),
        if (snapshot == null)
          const _Notice('Atualize seus dados para consultar a escala.'),
        if (snapshot != null) ...[
          Text(
            'Carga: ${snapshot.data.dataReferencia} · ${snapshot.data.fusoHorario}',
          ),
          for (final allocation in snapshot.data.alocacoes)
            _AllocationSchedule(allocation: allocation, snapshot: snapshot),
        ],
      ],
    );
  }
}

class _AllocationSchedule extends StatelessWidget {
  const _AllocationSchedule({required this.allocation, required this.snapshot});
  final AlocacaoPessoalSyncDto allocation;
  final BootstrapSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    try {
      final days = ScheduleProjector().project(
        allocation,
        snapshot.data.fusoHorario,
        snapshot.data.dataReferencia,
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                allocation.setor.nome,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(allocation.escala?.nome ?? 'Sem escala'),
              const SizedBox(height: 12),
              for (final day in days)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 65, child: Text(_date(day.date))),
                      Expanded(
                        child: Text(
                          day.windows.isEmpty
                              ? 'Folga prevista'
                              : day.windows
                                    .map(
                                      (w) =>
                                          '${_date(w.start)} ${_time(w.start)} → ${_date(w.end)} ${_time(w.end)}${w.breakMinutes > 0 ? ' · ${w.breakMinutes} min de intervalo' : ''}',
                                    )
                                    .join('\n'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (_) {
      return _Notice(
        '${allocation.setor.nome}: programação indisponível. ${allocation.escala?.modelo == 'Legado' ? 'A escala legada não permite inferir turnos.' : 'Solicite uma escala estruturada à empresa.'}',
      );
    }
  }
}

class _ClockMode extends StatelessWidget {
  const _ClockMode({required this.snapshot});
  final BootstrapSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.data.setor?.nome ?? 'Relógio de setor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'A carga do setor está disponível. Registrar pontos da equipe depende de autorização adicional no servidor.',
          ),
          for (final employee in snapshot.data.funcionarios)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(employee.funcionario.nome),
              subtitle: Text('Matrícula ${employee.funcionario.matricula}'),
            ),
        ],
      ),
    ),
  );
}
