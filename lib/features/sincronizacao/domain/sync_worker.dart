import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/mobile_api.dart';
import '../../auth/domain/mobile_session.dart';
import '../../marcacoes/data/outbox_repository.dart';
import 'receipt_validator.dart';

class SyncWorker {
  SyncWorker(this.outbox, this.api, {DateTime Function()? now, Random? random})
    : now = now ?? DateTime.now,
      random = random ?? Random();
  final OutboxRepository outbox;
  final MobileApi api;
  final DateTime Function() now;
  final Random random;
  Future<void>? _running;
  final String _owner = const Uuid().v4();

  Future<void> run(
    MobileSession session, {
    required bool Function() authorized,
    required Future<void> Function(AppFailure) onDenied,
    bool manual = false,
  }) {
    if (_running != null) return _running!;
    final future = _run(session, authorized, onDenied, manual);
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  DateTime _retry(int attempts) {
    final seconds = min(900, 5 * pow(2, min(attempts, 8)).toInt());
    return now().toUtc().add(
      Duration(milliseconds: seconds * 1000 + random.nextInt(3000)),
    );
  }

  Future<void> _run(
    MobileSession session,
    bool Function() authorized,
    Future<void> Function(AppFailure) onDenied,
    bool manual,
  ) async {
    if (!session.canSend || !authorized()) return;
    if (manual) await outbox.manualRetry(session.scope);
    for (
      var cycle = 0;
      cycle < AppConfig.cyclesPerRun && authorized();
      cycle++
    ) {
      final rows = await outbox.claim(
        session.scope,
        _owner,
        now().toUtc(),
        limit: AppConfig.batchSize,
      );
      if (rows.isEmpty) break;
      if (!authorized()) {
        await _release(session, rows, 'Sessão alterada antes do envio.');
        return;
      }
      try {
        final response = await api.request(
          'POST',
          '/api/mobile/marcacoes/lote',
          session: session,
          data: {'marcacoes': rows.map((r) => jsonDecode(r.payload)).toList()},
        );
        final results = response['resultados'];
        final confirmed = <String, Map<String, dynamic>>{};
        final failures = <String, Map<String, dynamic>>{};
        if (results is List) {
          for (var index = 0; index < rows.length; index++) {
            final row = rows[index];
            final matches = results
                .whereType<Map<String, dynamic>>()
                .where(
                  (r) =>
                      r['evento_cliente_id'] == row.eventId ||
                      r['indice'] == index,
                )
                .toList();
            if (matches.length != 1) continue;
            final result = matches.single;
            if (coherentReceipt(
              result,
              jsonDecode(row.payload) as Map<String, dynamic>,
              index,
            )) {
              confirmed[row.eventId] = result;
            } else if (result['indice'] == index &&
                result['evento_cliente_id'] == row.eventId &&
                result['persistida'] == false &&
                [404, 409, 422].contains(result['http_status'])) {
              failures[row.eventId] = result;
            }
          }
        }
        // Every coherent acknowledgement is committed together. Absent or
        // contradictory items are released for retry with unchanged evidence.
        await outbox.db.transaction(() async {
          await outbox.confirm(session.scope, _owner, confirmed);
          for (final row in rows.where(
            (r) => !confirmed.containsKey(r.eventId),
          )) {
            final error = failures[row.eventId]?['erro'];
            final message = error is Map && error['mensagem'] is String
                ? error['mensagem'] as String
                : 'Resposta incompleta ou inconsistente; confirmação pendente.';
            await outbox.fail(
              session.scope,
              _owner,
              row.eventId,
              message,
              retryAt: _retry(row.attempts + 1),
              permanent: failures.containsKey(row.eventId),
            );
          }
        });
      } on AppFailure catch (error) {
        await _release(
          session,
          rows,
          error.message,
          permanent: !error.retryable && !error.authorizationDenied,
        );
        if (error.authorizationDenied) await onDenied(error);
        // One network failure ends this cycle. A timer/lifecycle/manual signal
        // may retry later; never spin on an unreachable API.
        return;
      } catch (_) {
        await _release(
          session,
          rows,
          'Não foi possível concluir a tentativa. A evidência foi preservada.',
        );
        rethrow;
      }
    }
    if (!authorized()) return;
    for (var index = 0; index < AppConfig.cyclesPerRun; index++) {
      if (!authorized()) return;
      final photos = await outbox.claim(
        session.scope,
        _owner,
        now().toUtc(),
        photos: true,
        limit: 1,
      );
      if (photos.isEmpty) return;
      final row = photos.single;
      if (!authorized()) {
        await _release(session, photos, 'Sessão alterada.', photos: true);
        return;
      }
      try {
        final file = File(row.photoPath!);
        if (!await file.exists() ||
            sha256.convert(await file.readAsBytes()).toString() !=
                row.photoSha) {
          await outbox.fail(
            session.scope,
            _owner,
            row.eventId,
            'A selfie local está ausente ou foi alterada. Contate o suporte.',
            retryAt: now(),
            permanent: true,
            photos: true,
          );
          continue;
        }
        final result = await api.upload(session, row.eventId, file);
        if (result['evento_cliente_id'] != row.eventId ||
            result['sha256'] != row.photoSha ||
            result['selfie_id'] is! String ||
            result['duplicada'] is! bool ||
            result['content_type'] != 'image/jpeg') {
          throw const AppFailure('Confirmação da selfie inconsistente.');
        }
        await outbox.confirm(session.scope, _owner, {
          row.eventId: result,
        }, photos: true);
      } on AppFailure catch (error) {
        await outbox.fail(
          session.scope,
          _owner,
          row.eventId,
          error.message,
          retryAt: _retry(row.photoAttempts + 1),
          permanent: !error.retryable && !error.authorizationDenied,
          photos: true,
        );
        if (error.authorizationDenied) {
          await onDenied(error);
          return;
        }
        if (error.retryable) return;
      } catch (_) {
        await _release(
          session,
          photos,
          'Falha ao acessar a selfie privada.',
          photos: true,
        );
        return;
      }
    }
  }

  Future<void> _release(
    MobileSession session,
    List<OutboxEvent> rows,
    String message, {
    bool permanent = false,
    bool photos = false,
  }) async {
    for (final row in rows) {
      await outbox.fail(
        session.scope,
        _owner,
        row.eventId,
        message,
        retryAt: _retry((photos ? row.photoAttempts : row.attempts) + 1),
        permanent: permanent,
        photos: photos,
      );
    }
  }
}
