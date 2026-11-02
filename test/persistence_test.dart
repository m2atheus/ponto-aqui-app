import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/features/marcacoes/data/outbox_repository.dart';

import 'support.dart';

void main() {
  test(
    'outbox survives database close/reopen and isolates account scopes',
    () async {
      final temp = await Directory.systemTemp.createTemp('pontoaqui-test-');
      final file = File('${temp.path}/queue.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      final payload = evidence();
      await OutboxRepository(db).save(session.scope, event(payload));
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      final rows = await OutboxRepository(db).list(session.scope);
      expect(rows.single.eventId, payload['evento_cliente_id']);
      expect(
        await OutboxRepository(db).list('different-company-user-device'),
        isEmpty,
      );
      await db.close();
      await temp.delete(recursive: true);
    },
  );
  test(
    'transaction rollback and uniqueness never acknowledge a lost insert',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = OutboxRepository(db);
      final payload = evidence();
      await expectLater(
        db.transaction(() async {
          await repo.save(session.scope, event(payload));
          throw StateError('simulate crash before commit');
        }),
        throwsStateError,
      );
      expect(await repo.list(session.scope), isEmpty);
      await repo.save(session.scope, event(payload));
      await expectLater(
        repo.save(session.scope, event(payload)),
        throwsA(anything),
      );
      expect(await repo.list(session.scope), hasLength(1));
    },
  );
  test(
    'database rejects evidence mutation but permits transport updates',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = OutboxRepository(db);
      await repo.save(session.scope, event(evidence()));
      await expectLater(
        db
            .update(db.outboxEvents)
            .write(const OutboxEventsCompanion(payload: Value('{}'))),
        throwsA(anything),
      );
      await db
          .update(db.outboxEvents)
          .write(
            const OutboxEventsCompanion(
              lastError: Value('network unavailable'),
            ),
          );
      expect(
        (await repo.list(session.scope)).single.lastError,
        'network unavailable',
      );
    },
  );
  test(
    'concurrent workers cannot lease same event and expired leases recover',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = OutboxRepository(db);
      await repo.save(session.scope, event(evidence()));
      final now = DateTime.utc(2026, 10, 5);
      final leases = await Future.wait([
        repo.claim(session.scope, 'one', now),
        repo.claim(session.scope, 'two', now),
      ]);
      expect(leases.expand((r) => r), hasLength(1));
      expect(
        await repo.claim(
          session.scope,
          'restart',
          now.add(const Duration(minutes: 1)),
        ),
        isEmpty,
      );
      expect(
        await repo.claim(
          session.scope,
          'restart',
          now.add(const Duration(minutes: 3)),
        ),
        hasLength(1),
      );
    },
  );
}
