import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_runtime.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/domain/mobile_session.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../marcacoes/domain/punch_event.dart';
import '../data/mobile_sync_dto.dart';
import '../domain/bootstrap_snapshot.dart';

class WorkState {
  const WorkState({
    this.snapshot,
    this.busy = false,
    this.capturing = false,
    this.message,
    this.offline = true,
    this.selectedSectorId,
    this.sectors = const [],
  });
  final BootstrapSnapshot? snapshot;
  final bool busy, capturing, offline;
  final String? message, selectedSectorId;
  final List<SetorDisponivelSyncDto> sectors;
  WorkState copy({
    BootstrapSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? busy,
    bool? capturing,
    String? message,
    bool? offline,
    String? selectedSectorId,
    bool clearSector = false,
    List<SetorDisponivelSyncDto>? sectors,
  }) => WorkState(
    snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
    busy: busy ?? this.busy,
    capturing: capturing ?? this.capturing,
    message: message,
    offline: offline ?? this.offline,
    selectedSectorId: clearSector
        ? null
        : selectedSectorId ?? this.selectedSectorId,
    sectors: sectors ?? this.sectors,
  );
}

final workProvider = NotifierProvider.autoDispose
    .family<WorkViewModel, WorkState, String>(WorkViewModel.new);
final eventsProvider = StreamProvider.autoDispose
    .family<List<OutboxEvent>, String>(
      (ref, scope) => ref.watch(runtimeProvider).outbox.watch(scope),
    );

class WorkViewModel extends Notifier<WorkState> {
  WorkViewModel(this.scope);
  final String scope;
  bool _disposed = false, _foreground = true;
  int _revision = 0, _operationRevision = -1;
  bool _ready = false;
  Future<void>? _operation;

  @override
  WorkState build() {
    _disposed = false;
    final connectivity = ref.read(runtimeProvider).connections;
    final subscription = connectivity.changes.listen((offline) {
      if (_disposed) return;
      state = state.copy(offline: offline);
      if (!offline) unawaited(refresh());
    });
    final timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(synchronize()),
    );
    ref.onDispose(() {
      _disposed = true;
      subscription.cancel();
      timer.cancel();
    });
    Future.microtask(() async {
      final session = _session;
      final revision = _revision;
      if (session == null) return;
      try {
        final repository = ref.read(runtimeProvider).bootstrap;
        final selected = await repository.selectedSector(session);
        if (!_current(session, revision)) return;
        state = state.copy(selectedSectorId: selected);
        try {
          final cached = await repository.cached(session, sectorId: selected);
          if (!_current(session, revision)) return;
          if (cached != null) _adopt(cached);
        } catch (error) {
          if (_current(session, revision)) {
            state = state.copy(message: _message(error));
          }
        }
        final offline = await connectivity.isOffline();
        if (!_current(session, revision)) return;
        state = state.copy(offline: offline, message: state.message);
        _ready = true;
        await refresh();
      } catch (error) {
        if (_current(session, revision)) {
          state = state.copy(message: _message(error));
        }
      }
    });
    return const WorkState();
  }

  MobileSession? get _session {
    if (_disposed) return null;
    final session = ref.read(authProvider).asData?.value;
    return session?.scope == scope ? session : null;
  }

  bool _authorized(MobileSession session) =>
      !_disposed &&
      _session?.token == session.token &&
      _session?.canSend == true;
  bool _current(MobileSession session, int revision) =>
      _revision == revision && _authorized(session);

  void _adopt(BootstrapSnapshot snapshot) {
    final clock = snapshot.data.modoOperacao == ModoOperacao.relogio;
    final sector = snapshot.data.setor;
    state = state.copy(
      snapshot: snapshot,
      selectedSectorId: clock ? sector?.id : null,
      clearSector: !clock,
      sectors: clock
          ? (snapshot.data.setoresDisponiveis.isNotEmpty
                ? snapshot.data.setoresDisponiveis
                : [
                    if (sector != null)
                      SetorDisponivelSyncDto(id: sector.id, nome: sector.nome),
                  ])
          : const [],
      busy: state.busy,
    );
  }

  Future<void> selectSector(String sectorId) async {
    final session = _session;
    if (session == null ||
        !session.canSend ||
        state.capturing ||
        state.selectedSectorId == sectorId ||
        !state.sectors.any((s) => s.id == sectorId)) {
      return;
    }
    final revision = ++_revision;
    state = state.copy(
      selectedSectorId: sectorId,
      clearSnapshot: true,
      busy: true,
    );
    try {
      final repo = ref.read(runtimeProvider).bootstrap;
      await repo.selectSector(
        session,
        sectorId,
        isCurrent: () => _current(session, revision),
      );
      try {
        final cached = await repo.cached(session, sectorId: sectorId);
        if (!_current(session, revision)) return;
        if (cached != null) _adopt(cached);
      } catch (error) {
        if (!_current(session, revision)) return;
        state = state.copy(message: _message(error));
      }
      await refresh();
    } catch (error) {
      if (_current(session, revision)) {
        state = state.copy(busy: false, message: _message(error));
      }
    }
  }

  Future<void> refresh() => _perform(refreshBootstrap: true, manual: false);
  Future<void> synchronize({bool manual = false}) =>
      _perform(refreshBootstrap: manual, manual: manual);
  void setForeground(bool value) {
    _foreground = value;
  }

  Future<void> _perform({
    required bool refreshBootstrap,
    required bool manual,
  }) {
    if (!_ready) return Future.value();
    final revision = _revision;
    if (_operation != null && _operationRevision == revision) {
      return _operation!;
    }
    final future = _run(
      revision,
      refreshBootstrap: refreshBootstrap,
      manual: manual,
    );
    _operation = future;
    _operationRevision = revision;
    return future.whenComplete(() {
      if (identical(_operation, future)) _operation = null;
    });
  }

  String _denial(AppFailure error) => error.status == 401
      ? 'Sessão expirada. Entre novamente; sua fila foi preservada.'
      : error.code == 'DISPOSITIVO_MODO_ALTERADO'
      ? 'O aparelho foi convertido para compartilhado. Entre novamente; sua fila foi preservada.'
      : 'Autorização do aparelho ou setor recusada. Entre novamente ou contate o RH. Sua fila foi preservada.';

  Future<void> _run(
    int revision, {
    required bool refreshBootstrap,
    required bool manual,
  }) async {
    final session = _session;
    if (session == null || !session.canSend || !_foreground) return;
    final runtime = ref.read(runtimeProvider);
    final auth = ref.read(authProvider.notifier);
    state = state.copy(busy: true);
    try {
      if (refreshBootstrap) {
        try {
          final snapshot = await runtime.bootstrap.refresh(
            session,
            sectorId: state.selectedSectorId,
            isCurrent: () => _current(session, revision),
          );
          if (!_current(session, revision)) return;
          _adopt(snapshot);
        } on AppFailure catch (error) {
          if (!_current(session, revision)) return;
          if (error.authorizationDenied) {
            await auth.block(session, _denial(error));
            return;
          }
          state = state.copy(message: error.message, busy: true);
        }
      }
      if (!_current(session, revision)) return;
      await runtime.worker.run(
        session,
        authorized: () => _foreground && _authorized(session),
        onDenied: (error) => auth.block(session, _denial(error)),
        manual: manual,
      );
    } catch (error) {
      if (_current(session, revision)) {
        state = state.copy(message: _message(error));
      }
    } finally {
      if (!_disposed && _revision == revision) {
        state = state.copy(busy: false, message: state.message);
      }
    }
  }

  Future<bool> capture(
    String allocationId,
    PunchType type, {
    Future<bool> Function(String message)? confirmSelfie,
  }) async {
    if (state.capturing) return false;
    final session = _session;
    final snapshot = state.snapshot;
    if (session == null || snapshot == null) return false;
    final revision = _revision;
    final capture = ref.read(runtimeProvider).capture;
    state = state.copy(capturing: true);
    try {
      final location = await capture(
        session: session,
        snapshot: snapshot,
        allocationId: allocationId,
        type: type,
        offlineSignal: state.offline,
        authorized: () => _current(session, revision),
        confirmSelfie: confirmSelfie,
      );
      if (_current(session, revision)) {
        state = state.copy(
          capturing: false,
          message:
              'Salvo no aparelho. ${location == 'capturada' || location == 'dispensada_pela_politica' ? 'Aguardando confirmação do servidor.' : 'Localização: ${location.replaceAll('_', ' ')}. O servidor avaliará a evidência.'}',
        );
        unawaited(synchronize());
      }
      return true;
    } catch (error) {
      if (!_disposed) {
        state = state.copy(capturing: false, message: _message(error));
      }
      return false;
    }
  }

  String _message(Object error) => error is AppFailure
      ? error.message
      : 'Não foi possível concluir a operação. Suas evidências foram preservadas.';
}
