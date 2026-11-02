import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:timezone/data/latest.dart' as tz;
import 'package:ponto_aqui_app/core/clock/clock_sample.dart';
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/core/device/evidence_sensors.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';
import 'package:ponto_aqui_app/features/bootstrap/domain/bootstrap_snapshot.dart';
import 'package:ponto_aqui_app/features/marcacoes/data/outbox_repository.dart';
import 'package:ponto_aqui_app/features/marcacoes/domain/capture_punch.dart';
import 'package:ponto_aqui_app/features/marcacoes/domain/punch_event.dart';

import 'support.dart';

class FakeSensors implements EvidenceSensors {
  bool? ignored;
  int photoCalls = 0;
  @override
  Future<PositionEvidence> location({required bool ignored}) async {
    this.ignored = ignored;
    return PositionEvidence(
      null,
      ignored ? 'dispensada_pela_politica' : 'permissao_negada',
    );
  }

  @override
  Future<Uint8List> selfie() async {
    photoCalls++;
    return prepareSelfie(
      Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8))),
    );
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
  late AppDatabase db;
  late OutboxRepository outbox;
  late Directory photos;
  late FakeSensors sensors;
  final now = DateTime.utc(2026, 10, 5, 15);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    photos = await Directory.systemTemp.createTemp('pontoaqui-test-capture-');
    sensors = FakeSensors();
  });
  tearDown(() async {
    await db.close();
    await photos.delete(recursive: true);
  });
  BootstrapSnapshot snapshot({bool ignored = false, bool selfie = false}) {
    final body = fixture();
    body['alocacoes'][0]['setor']['politicas']['ignorar_localizacao'] = ignored;
    body['alocacoes'][0]['setor']['politicas']['exige_selfie'] = selfie;
    return BootstrapSnapshot(
      MobileSyncDto.fromJson(body),
      ClockSample(
        offsetMs: -1599,
        receivedAt: now.subtract(const Duration(minutes: 1)),
        roundTripMs: 200,
      ),
    );
  }

  Future<String> capture(
    BootstrapSnapshot data, {
    bool Function()? authorized,
  }) => CapturePunch(outbox, sensors, photos, now: () => now)(
    session: session,
    snapshot: data,
    allocationId: data.data.alocacoes.single.id,
    type: PunchType.entrada,
    offlineSignal: true,
    authorized: authorized ?? () => true,
  );

  test('denied GPS persists null position and permission evidence without a fake location', () async {
    await capture(snapshot());
    final row = (await outbox.list(session.scope)).single;
    final payload = jsonDecode(row.payload) as Map;
    expect(payload['posicao'], isNull);
    expect(payload['registrado_offline'], isTrue);
    expect(payload['desvio_relogio_segundos'], -1);
    expect(payload['ocorrido_em'], now.toIso8601String());
    expect(jsonDecode(row.metadata)['localizacao_status'], 'permissao_negada');
    expect(sensors.photoCalls, 0);
  });
  test('ignored location policy bypasses GPS and selfie is persisted privately before event commit', () async {
    await capture(snapshot(ignored: true, selfie: true));
    final row = (await outbox.list(session.scope)).single;
    expect(sensors.ignored, isTrue);
    expect(sensors.photoCalls, 1);
    expect(row.photoTransport, 'na_fila');
    final file = File(row.photoPath!);
    expect(await file.exists(), isTrue);
    expect(sha256.convert(await file.readAsBytes()).toString(), row.photoSha);
    expect(row.transport, 'na_fila');
  });
  test(
    'session change and old sample prevent capture without generating evidence',
    () async {
      await expectLater(
        capture(snapshot(), authorized: () => false),
        throwsA(anything),
      );
      final stale = BootstrapSnapshot(
        snapshot().data,
        ClockSample(
          offsetMs: 0,
          receivedAt: now.subtract(const Duration(days: 2)),
          roundTripMs: 1,
        ),
      );
      await expectLater(capture(stale), throwsA(anything));
      expect(await outbox.list(session.scope), isEmpty);
    },
  );
}
