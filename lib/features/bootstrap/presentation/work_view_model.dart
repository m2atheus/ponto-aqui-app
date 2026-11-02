import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_runtime.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/domain/mobile_session.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../marcacoes/domain/punch_event.dart';
import '../domain/bootstrap_snapshot.dart';

class WorkState {
  const WorkState({
    this.snapshot,
    this.busy = false,
    this.capturing = false,
    this.message,
    this.offline = true,
  });
  final BootstrapSnapshot? snapshot;
  final bool busy, capturing, offline;
  final String? message;
  WorkState copy({
    BootstrapSnapshot? snapshot,
    bool? busy,
    bool? capturing,
    String? message,
    bool? offline,
  }) => WorkState(
    snapshot: snapshot ?? this.snapshot,
    busy: busy ?? this.busy,
    capturing: capturing ?? this.capturing,
    message: message,
    offline: offline ?? this.offline,
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
  bool _disposed = false;
  Future<void>? _operation;
  bool _foreground = true;

  @override
  WorkState build() {
    _disposed = false;
    final connectivity = ref.read(runtimeProvider).connections;
    final subscription = connectivity.changes.listen((offline) {
      if (_disposed) return;
      state = state.copy(offline: offline);
      if (!state.offline) unawaited(refresh());
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
      try {
        final session = _session;
        if (session == null) return;
        final cached = await ref
            .read(runtimeProvider)
            .bootstrap
            .cached(session);
        if (_disposed) return;
        state = state.copy(snapshot: cached);
        final offline = await connectivity.isOffline();
        if (_disposed) return;
        state = state.copy(offline: offline);
        await refresh();
      } catch (error) {
        if (!_disposed) state = state.copy(message: _message(error));
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
    if (_operation != null) return _operation!;
    final future = _run(refreshBootstrap: refreshBootstrap, manual: manual);
    _operation = future;
    return future.whenComplete(() => _operation = null);
  }

  Future<void> _run({
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
          final snapshot = await runtime.bootstrap.refresh(session);
          if (!_authorized(session)) return;
          state = state.copy(snapshot: snapshot, busy: true);
        } on AppFailure catch (error) {
          if (error.authorizationDenied) {
            await auth.block(
              session,
              error.status == 401
                  ? 'Entre novamente para sincronizar.'
                  : 'Acesso ao aparelho negado. Contate o administrador.',
            );
            return;
          }
          if (!_disposed) {
            state = state.copy(message: error.message, busy: true);
          }
          // Bootstrap network failure does not discard an existing outbox.
          // Its independent idempotent transport may still be attempted.
        }
      }
      await runtime.worker.run(
        session,
        authorized: () => _foreground && _authorized(session),
        onDenied: (error) => auth.block(
          session,
          error.status == 401
              ? 'Sessão expirada. Entre novamente; sua fila foi preservada.'
              : 'Acesso negado. Sua fila foi preservada; contate o administrador.',
        ),
        manual: manual,
      );
    } catch (error) {
      if (!_disposed) state = state.copy(message: _message(error));
    } finally {
      if (!_disposed) state = state.copy(busy: false, message: state.message);
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
    final capture = ref.read(runtimeProvider).capture;
    state = state.copy(capturing: true);
    try {
      final location = await capture(
        session: session,
        snapshot: snapshot,
        allocationId: allocationId,
        type: type,
        offlineSignal: state.offline,
        authorized: () => _authorized(session),
        confirmSelfie: confirmSelfie,
      );
      if (!_disposed) {
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
