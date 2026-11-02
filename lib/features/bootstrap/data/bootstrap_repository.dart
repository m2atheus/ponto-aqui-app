import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

import '../../../core/clock/clock_sample.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/mobile_api.dart';
import '../../auth/domain/mobile_session.dart';
import '../domain/bootstrap_snapshot.dart';
import 'mobile_sync_dto.dart';

class BootstrapRepository {
  BootstrapRepository(this.db, this.api, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final AppDatabase db;
  final MobileApi api;
  final DateTime Function() now;

  MobileSyncDto _parse(Object? raw, MobileSession session) {
    final dto = MobileSyncDto.fromJson(raw);
    tz.getLocation(dto.fusoHorario);
    if (dto.modoOperacao == ModoOperacao.pessoal &&
        dto.funcionario != null &&
        dto.funcionario!.usuarioId != session.userId) {
      throw const FormatException(
        'Funcionário incompatível com a conta autenticada.',
      );
    }
    if ((session.role == 'FUNCIONARIO') !=
        (dto.modoOperacao == ModoOperacao.pessoal)) {
      throw const FormatException('Modo incompatível com a sessão.');
    }
    return dto;
  }

  Future<BootstrapSnapshot?> cached(MobileSession session) async {
    final row = await (db.select(
      db.bootstrapCaches,
    )..where((t) => t.scope.equals(session.scope))).getSingleOrNull();
    if (row == null) return null;
    try {
      return BootstrapSnapshot(
        _parse(jsonDecode(row.payload), session),
        ClockSample(
          offsetMs: row.offsetMs,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            row.receivedMs,
            isUtc: true,
          ),
          roundTripMs: row.roundTripMs,
        ),
      );
    } catch (_) {
      throw const AppFailure(
        'A carga local está inválida. Atualize os dados para registrar ponto.',
      );
    }
  }

  Future<BootstrapSnapshot> refresh(MobileSession session) async {
    if (!session.canSend) {
      throw const AppFailure('Entre novamente para atualizar os dados.');
    }
    final started = now().toUtc();
    final watch = Stopwatch()..start();
    final body = await api.request(
      'GET',
      '/api/v1/mobile/sync',
      session: session,
    );
    final received = now().toUtc();
    watch.stop();
    late final MobileSyncDto dto;
    try {
      dto = _parse(body, session);
    } catch (_) {
      throw const AppFailure(
        'Carga inválida recebida da API. A última carga válida foi preservada.',
      );
    }
    if ((received.difference(started).inMilliseconds -
                watch.elapsedMilliseconds)
            .abs() >
        2000) {
      throw const AppFailure(
        'O relógio mudou durante a atualização. Tente novamente.',
      );
    }
    final sample = ClockSample(
      offsetMs: dto.serverTimestamp.difference(received).inMilliseconds,
      receivedAt: received,
      roundTripMs: watch.elapsedMilliseconds,
    );
    await db.transaction(
      () => db
          .into(db.bootstrapCaches)
          .insertOnConflictUpdate(
            BootstrapCachesCompanion.insert(
              scope: session.scope,
              payload: jsonEncode(dto.toJson()),
              receivedMs: received.millisecondsSinceEpoch,
              offsetMs: sample.offsetMs,
              roundTripMs: sample.roundTripMs,
            ),
          ),
    );
    return BootstrapSnapshot(dto, sample);
  }
}
