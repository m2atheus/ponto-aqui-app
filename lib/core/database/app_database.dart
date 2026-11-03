import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class BootstrapCaches extends Table {
  TextColumn get scope => text()();
  TextColumn get payload => text()();
  IntColumn get receivedMs => integer()();
  IntColumn get offsetMs => integer()();
  IntColumn get roundTripMs => integer()();
  @override
  Set<Column> get primaryKey => {scope};
}

class SelectedContexts extends Table {
  TextColumn get scope => text()();
  TextColumn get sectorId => text()();
  @override
  Set<Column> get primaryKey => {scope};
}

class OutboxEvents extends Table {
  TextColumn get scope => text()();
  TextColumn get eventId => text()();
  // Evidence fields are inserted once; transport updates never rewrite them.
  TextColumn get payload => text()();
  TextColumn get metadata => text()();
  IntColumn get capturedMs => integer()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get photoSha => text().nullable()();
  TextColumn get transport => text().withDefault(const Constant('na_fila'))();
  TextColumn get photoTransport =>
      text().withDefault(const Constant('sem_foto'))();
  TextColumn get receipt => text().nullable()();
  TextColumn get photoReceipt => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get photoAttempts => integer().withDefault(const Constant(0))();
  IntColumn get lastAttemptMs => integer().nullable()();
  IntColumn get nextAttemptMs => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get leaseOwner => text().nullable()();
  IntColumn get leaseUntilMs => integer().nullable()();
  @override
  Set<Column> get primaryKey => {scope, eventId};
}

@DriftDatabase(tables: [BootstrapCaches, OutboxEvents, SelectedContexts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  factory AppDatabase.persistent() => AppDatabase(
    LazyDatabase(() async {
      final directory = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(directory.path, 'ponto_aqui.sqlite')),
      );
    }),
  );
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(selectedContexts);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Enforce immutable evidence even if a future DAO accidentally updates it.
      await customStatement(
        '''CREATE TRIGGER IF NOT EXISTS evidence_immutable
        BEFORE UPDATE OF scope, event_id, payload, metadata, captured_ms, photo_path, photo_sha
        ON outbox_events BEGIN SELECT RAISE(ABORT, 'Evidencia imutavel'); END''',
      );
    },
  );
}
