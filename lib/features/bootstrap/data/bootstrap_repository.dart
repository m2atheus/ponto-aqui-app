import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

import '../../../core/clock/clock_sample.dart';
import '../../../core/database/app_database.dart';
import '../../../core/diagnostics/parsing_diagnostic.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/mobile_api.dart';
import '../../auth/domain/mobile_session.dart';
import '../domain/bootstrap_snapshot.dart';
import 'mobile_sync_dto.dart';

class BootstrapRepository {
  BootstrapRepository(
    this.db,
    this.api, {
    DateTime Function()? now,
    void Function(ParsingDiagnostic)? reportParsingFailure,
  }) : now = now ?? DateTime.now,
       reportParsingFailure = reportParsingFailure ?? ParsingDiagnostic.log;
  final AppDatabase db;
  final MobileApi api;
  final DateTime Function() now;
  final void Function(ParsingDiagnostic) reportParsingFailure;

  void _report(
    String source,
    Object error,
    StackTrace stack,
    Object? payload,
    MobileSession session,
  ) {
    try {
      reportParsingFailure(
        ParsingDiagnostic.capture(
          source: source,
          error: error,
          stackTrace: stack,
          payload: payload,
          token: session.token,
          role: session.role,
        ),
      );
    } catch (_) {
      // Diagnostico indisponivel nao pode substituir o erro nem alterar o cache.
    }
  }

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
    // O modo vem do aparelho autorizado pela API, nao apenas do papel.
    // FUNCIONARIO tambem pode usar um RELOGIO compartilhado com vinculo ativo.
    final compatible = switch (session.role) {
      'FUNCIONARIO' => true,
      'USUARIO_SETOR' => dto.modoOperacao == ModoOperacao.relogio,
      _ => false,
    };
    if (!compatible) {
      throw const FormatException('Modo incompatível com a sessão.');
    }
    return dto;
  }

  String _cacheScope(MobileSession session, String? sectorId) =>
      sectorId == null
      ? session.scope
      : jsonEncode([session.scope, 'RELOGIO', sectorId]);

  void _current(bool Function()? isCurrent) {
    if (isCurrent != null && !isCurrent()) {
      throw const AppFailure(
        'A seleção de contexto mudou.',
        code: 'CONTEXTO_SUPERADO',
      );
    }
  }

  Future<String?> selectedSector(MobileSession session) async {
    final row = await (db.select(
      db.selectedContexts,
    )..where((t) => t.scope.equals(session.scope))).getSingleOrNull();
    final stored = row?.sectorId;
    // Um novo login pode trazer autorizacoes diferentes, sem reaproveitar um
    // contexto que nao consta mais no JWT emitido e verificado pela API.
    if (session.authorizedSectorIds.isNotEmpty &&
        stored != null &&
        !session.authorizedSectorIds.contains(stored)) {
      return session.initialSectorId;
    }
    return stored ?? session.initialSectorId;
  }

  Future<void> selectSector(
    MobileSession session,
    String sectorId, {
    bool Function()? isCurrent,
  }) => db.transaction(() async {
    _current(isCurrent);
    await db
        .into(db.selectedContexts)
        .insertOnConflictUpdate(
          SelectedContextsCompanion.insert(
            scope: session.scope,
            sectorId: sectorId,
          ),
        );
    _current(isCurrent);
  });

  Future<BootstrapSnapshot?> cached(
    MobileSession session, {
    String? sectorId,
  }) async {
    sectorId ??= await selectedSector(session);
    final scope = _cacheScope(session, sectorId);
    var row = await (db.select(
      db.bootstrapCaches,
    )..where((t) => t.scope.equals(scope))).getSingleOrNull();
    // Compatibilidade com cargas v1. Nunca reaproveitar outro setor por engano.
    row ??= sectorId == null
        ? null
        : await (db.select(
            db.bootstrapCaches,
          )..where((t) => t.scope.equals(session.scope))).getSingleOrNull();
    if (row == null) return null;
    Object? body;
    try {
      body = jsonDecode(row.payload);
      final dto = _parse(body, session);
      if (sectorId != null &&
          (dto.modoOperacao != ModoOperacao.relogio ||
              dto.setor?.id != sectorId)) {
        return null;
      }
      return BootstrapSnapshot(
        dto,
        ClockSample(
          offsetMs: row.offsetMs,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            row.receivedMs,
            isUtc: true,
          ),
          roundTripMs: row.roundTripMs,
        ),
      );
    } catch (error, stack) {
      _report('cache', error, stack, body, session);
      throw const AppFailure(
        'A carga local está inválida. Atualize os dados para registrar ponto.',
      );
    }
  }

  Future<BootstrapSnapshot> refresh(
    MobileSession session, {
    String? sectorId,
    bool Function()? isCurrent,
  }) async {
    if (!session.canSend) {
      throw const AppFailure('Entre novamente para atualizar os dados.');
    }
    _current(isCurrent);
    sectorId ??= await selectedSector(session);
    _current(isCurrent);
    final started = now().toUtc();
    final watch = Stopwatch()..start();
    final body = await api.request(
      'GET',
      '/api/v1/mobile/sync',
      session: session,
      queryParameters: sectorId == null ? null : {'setor_id': sectorId},
    );
    final received = now().toUtc();
    watch.stop();
    _current(isCurrent);
    late final MobileSyncDto dto;
    try {
      dto = _parse(body, session);
      if (sectorId != null &&
          (dto.modoOperacao != ModoOperacao.relogio ||
              dto.setor?.id != sectorId)) {
        throw const FormatException(
          'O setor recebido não corresponde ao contexto solicitado.',
        );
      }
    } catch (error, stack) {
      _report('api', error, stack, body, session);
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
    final context = dto.modoOperacao == ModoOperacao.relogio
        ? dto.setor!.id
        : null;
    await db.transaction(() async {
      _current(isCurrent);
      await db
          .into(db.bootstrapCaches)
          .insertOnConflictUpdate(
            BootstrapCachesCompanion.insert(
              scope: _cacheScope(session, context),
              payload: jsonEncode(dto.toJson()),
              receivedMs: received.millisecondsSinceEpoch,
              offsetMs: sample.offsetMs,
              roundTripMs: sample.roundTripMs,
            ),
          );
      if (context != null) {
        await db
            .into(db.selectedContexts)
            .insertOnConflictUpdate(
              SelectedContextsCompanion.insert(
                scope: session.scope,
                sectorId: context,
              ),
            );
      }
      _current(isCurrent);
    });
    return BootstrapSnapshot(dto, sample);
  }
}
