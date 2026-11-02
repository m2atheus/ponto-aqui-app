import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../core/database/app_database.dart';
import '../core/device/evidence_sensors.dart';
import '../core/device/connection_monitor.dart';
import '../core/network/mobile_api.dart';
import '../core/storage/session_storage.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/bootstrap/data/bootstrap_repository.dart';
import '../features/marcacoes/data/outbox_repository.dart';
import '../features/marcacoes/domain/capture_punch.dart';
import '../features/sincronizacao/domain/sync_worker.dart';

final runtimeProvider = Provider<AppRuntime>(
  (ref) => throw StateError('Runtime não inicializado.'),
);

class AppRuntime {
  AppRuntime({
    required this.config,
    required this.db,
    required this.api,
    required this.storage,
    required this.photos,
    required this.installationUuid,
    this.recoveredPhotos = 0,
    ConnectionMonitor? connections,
    EvidenceSensors? sensors,
  }) : connections = connections ?? PlatformConnectionMonitor() {
    auth = AuthRepository(api, storage);
    bootstrap = BootstrapRepository(db, api);
    outbox = OutboxRepository(db);
    worker = SyncWorker(outbox, api);
    capture = CapturePunch(outbox, sensors ?? NativeEvidenceSensors(), photos);
  }
  final AppConfig config;
  final AppDatabase db;
  final MobileApi api;
  final SessionStorage storage;
  final Directory photos;
  final String installationUuid;
  final int recoveredPhotos;
  final ConnectionMonitor connections;
  late final AuthRepository auth;
  late final BootstrapRepository bootstrap;
  late final OutboxRepository outbox;
  late final SyncWorker worker;
  late final CapturePunch capture;

  static Future<AppRuntime> open() async {
    final config = AppConfig.environment();
    final storage = SessionStorage(const FlutterSecureStorage());
    final uuid = await storage.installationUuid();
    final support = await getApplicationSupportDirectory();
    final photos = Directory(p.join(support.path, 'evidencias'));
    await photos.create(recursive: true);
    var recovered = 0;
    final lost = await NativeEvidenceSensors().lostPhotos();
    if (lost.isNotEmpty) {
      final recovery = Directory(p.join(photos.path, 'capturas_interrompidas'));
      await recovery.create(recursive: true);
      for (var i = 0; i < lost.length; i++) {
        await File(lost[i].path).copy(
          p.join(
            recovery.path,
            '${DateTime.now().microsecondsSinceEpoch}_$i.jpg',
          ),
        );
        recovered++;
      }
    }
    return AppRuntime(
      config: config,
      db: AppDatabase.persistent(),
      api: MobileApi(config),
      storage: storage,
      photos: photos,
      installationUuid: uuid,
      recoveredPhotos: recovered,
    );
  }
}
