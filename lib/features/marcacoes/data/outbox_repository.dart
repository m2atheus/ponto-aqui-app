import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/punch_event.dart';

class OutboxRepository {
  OutboxRepository(this.db);
  final AppDatabase db;

  Future<void> save(String scope, PunchEvent event) => db.transaction(() async {
    await db
        .into(db.outboxEvents)
        .insert(
          OutboxEventsCompanion.insert(
            scope: scope,
            eventId: event.id,
            payload: event.payloadJson,
            metadata: event.metadataJson,
            capturedMs: event.capturedMs,
            photoPath: Value(event.photoPath),
            photoSha: Value(event.photoSha),
            photoTransport: Value(
              event.photoPath == null ? 'sem_foto' : 'na_fila',
            ),
          ),
        );
  });

  Stream<List<OutboxEvent>> watch(String scope) =>
      (db.select(db.outboxEvents)
            ..where((t) => t.scope.equals(scope))
            ..orderBy([(t) => OrderingTerm.desc(t.capturedMs)]))
          .watch();

  Future<List<OutboxEvent>> list(String scope) =>
      (db.select(db.outboxEvents)
            ..where((t) => t.scope.equals(scope))
            ..orderBy([(t) => OrderingTerm.asc(t.capturedMs)]))
          .get();

  Future<List<OutboxEvent>> claim(
    String scope,
    String owner,
    DateTime now, {
    int limit = 50,
    bool photos = false,
  }) => db.transaction(() async {
    final epoch = now.millisecondsSinceEpoch;
    // A killed worker loses its lease after two minutes. Other processes never
    // reset a live lease, even when the app resumes or a second worker starts.
    final expired =
        await (db.select(db.outboxEvents)..where(
              (t) =>
                  t.scope.equals(scope) &
                  t.leaseUntilMs.isSmallerOrEqualValue(epoch),
            ))
            .get();
    for (final row in expired) {
      await _row(scope, row.eventId).write(
        OutboxEventsCompanion(
          transport: Value(
            row.transport == 'enviando' ? 'na_fila' : row.transport,
          ),
          photoTransport: Value(
            row.photoTransport == 'enviando' ? 'na_fila' : row.photoTransport,
          ),
          leaseOwner: const Value(null),
          leaseUntilMs: const Value(null),
        ),
      );
    }
    final available =
        await (db.select(db.outboxEvents)
              ..where(
                (t) =>
                    t.scope.equals(scope) &
                    t.leaseOwner.isNull() &
                    t.nextAttemptMs.isSmallerOrEqualValue(epoch) &
                    (photos
                        ? t.transport.equals('confirmada') &
                              t.photoTransport.equals('na_fila')
                        : t.transport.equals('na_fila')),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.capturedMs)])
              ..limit(limit))
            .get();
    for (final row in available) {
      await _row(scope, row.eventId).write(
        OutboxEventsCompanion(
          transport: photos ? const Value.absent() : const Value('enviando'),
          photoTransport: photos
              ? const Value('enviando')
              : const Value.absent(),
          attempts: photos ? const Value.absent() : Value(row.attempts + 1),
          photoAttempts: photos
              ? Value(row.photoAttempts + 1)
              : const Value.absent(),
          lastAttemptMs: Value(epoch),
          leaseOwner: Value(owner),
          leaseUntilMs: Value(
            epoch + const Duration(minutes: 2).inMilliseconds,
          ),
        ),
      );
    }
    return available;
  });

  UpdateStatement<OutboxEvents, OutboxEvent> _row(String scope, String id) =>
      db.update(db.outboxEvents)
        ..where((t) => t.scope.equals(scope) & t.eventId.equals(id));

  Future<void> confirm(
    String scope,
    String owner,
    Map<String, Map<String, dynamic>> receipts, {
    bool photos = false,
  }) => db.transaction(() async {
    for (final entry in receipts.entries) {
      await (db.update(db.outboxEvents)..where(
            (t) =>
                t.scope.equals(scope) &
                t.eventId.equals(entry.key) &
                t.leaseOwner.equals(owner),
          ))
          .write(
            OutboxEventsCompanion(
              transport: photos
                  ? const Value.absent()
                  : const Value('confirmada'),
              photoTransport: photos
                  ? const Value('confirmada')
                  : const Value.absent(),
              receipt: photos
                  ? const Value.absent()
                  : Value(jsonEncode(entry.value)),
              photoReceipt: photos
                  ? Value(jsonEncode(entry.value))
                  : const Value.absent(),
              leaseOwner: const Value(null),
              leaseUntilMs: const Value(null),
              lastError: const Value(null),
              nextAttemptMs: const Value(0),
            ),
          );
    }
  });

  Future<void> fail(
    String scope,
    String owner,
    String id,
    String message, {
    required DateTime retryAt,
    bool permanent = false,
    bool photos = false,
  }) async {
    await (db.update(db.outboxEvents)..where(
          (t) =>
              t.scope.equals(scope) &
              t.eventId.equals(id) &
              t.leaseOwner.equals(owner),
        ))
        .write(
          OutboxEventsCompanion(
            transport: photos
                ? const Value.absent()
                : Value(permanent ? 'erro_requer_acao' : 'na_fila'),
            photoTransport: photos
                ? Value(permanent ? 'erro_requer_acao' : 'na_fila')
                : const Value.absent(),
            leaseOwner: const Value(null),
            leaseUntilMs: const Value(null),
            lastError: Value(message),
            nextAttemptMs: Value(retryAt.millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> manualRetry(String scope) async {
    // Permanent evidence conflicts require support; manual retry only removes
    // backoff for retryable rows and never replaces their UUID or payload.
    await (db.update(db.outboxEvents)
          ..where((t) => t.scope.equals(scope) & t.leaseOwner.isNull()))
        .write(const OutboxEventsCompanion(nextAttemptMs: Value(0)));
  }
}
