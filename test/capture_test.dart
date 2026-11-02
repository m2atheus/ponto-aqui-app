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
import 'package:ponto_aqui_app/core/errors/app_failure.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';
import 'package:ponto_aqui_app/features/bootstrap/domain/bootstrap_snapshot.dart';
import 'package:ponto_aqui_app/features/marcacoes/data/outbox_repository.dart';
import 'package:ponto_aqui_app/features/marcacoes/domain/capture_punch.dart';
import 'package:ponto_aqui_app/features/marcacoes/domain/punch_event.dart';

import 'support.dart';

class FakeSensors implements EvidenceSensors {
  bool? ignored;
  int photoCalls = 0;
  bool cancelPhoto = false;
  bool emptyPhoto = false;
  void Function()? afterPhoto;
  PositionEvidence evidence = const PositionEvidence(null, 'permissao_negada');
  @override
  Future<PositionEvidence> location({required bool ignored}) async {
    this.ignored = ignored;
    return evidence;
  }

  @override
  Future<Uint8List> selfie() async {
    photoCalls++;
    if (cancelPhoto) throw const AppFailure('Captura cancelada.');
    afterPhoto?.call();
    if (emptyPhoto) return Uint8List(0);
    return prepareSelfie(
      Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8))),
    );
  }
}

PositionEvidence position({double latitude = -8, double accuracy = 5}) =>
    PositionEvidence({
      'latitude': latitude,
      'longitude': -35.0,
      'precisao_metros': accuracy,
    }, accuracy > 100 ? 'baixa_precisao' : 'capturada');

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
  BootstrapSnapshot snapshot({
    bool ignored = false,
    bool selfie = false,
    void Function(Map<String, dynamic>)? configure,
  }) {
    final body = fixture();
    for (final sector in [body['setor'], body['alocacoes'][0]['setor']]) {
      sector['politicas']['ignorar_localizacao'] = ignored;
      sector['politicas']['exige_selfie'] = selfie;
    }
    configure?.call(body);
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
    Future<bool> Function(String)? confirmSelfie,
  }) => CapturePunch(outbox, sensors, photos, now: () => now)(
    session: session,
    snapshot: data,
    allocationId: data.data.alocacoes.first.id,
    type: PunchType.entrada,
    offlineSignal: true,
    authorized: authorized ?? () => true,
    confirmSelfie: confirmSelfie,
  );

  test(
    'denied GPS requires selfie and preserves absence without fake coordinates',
    () async {
      await capture(snapshot());
      final row = (await outbox.list(session.scope)).single;
      final payload = jsonDecode(row.payload) as Map;
      expect(payload['posicao'], isNull);
      expect(payload['registrado_offline'], isTrue);
      expect(payload['desvio_relogio_segundos'], -1);
      expect(payload['ocorrido_em'], now.toIso8601String());
      final metadata = jsonDecode(row.metadata);
      expect(metadata['localizacao_status'], 'permissao_negada');
      expect(metadata['selfie_motivo'], 'localizacao_nao_confirmada');
      expect(sensors.photoCalls, 1);
      expect(row.photoTransport, 'na_fila');
    },
  );
  test('outside workplace requires a private photo before saving the offline event', () async {
    sensors.evidence = position(latitude: -8.01);
    String? explanation;
    await capture(
      snapshot(),
      confirmSelfie: (message) async {
        explanation = message;
        expect(await outbox.list(session.scope), isEmpty);
        return true;
      },
    );
    final row = (await outbox.list(session.scope)).single;
    expect(explanation, contains('fora dos locais vinculados'));
    expect(jsonDecode(row.payload)['posicao'], sensors.evidence.position);
    expect(jsonDecode(row.metadata)['selfie_motivo'], 'fora_dos_locais');
    expect(sensors.photoCalls, 1);
    expect(row.photoTransport, 'na_fila');
    final file = File(row.photoPath!);
    expect(await file.exists(), isTrue);
    expect(sha256.convert(await file.readAsBytes()).toString(), row.photoSha);
    expect(row.transport, 'na_fila');
  });
  test('inside a linked workplace does not request a photo', () async {
    sensors.evidence = position();
    await capture(
      snapshot(),
      confirmSelfie: (_) => throw StateError('No dialog inside'),
    );
    final row = (await outbox.list(session.scope)).single;
    expect(sensors.photoCalls, 0);
    expect(row.photoPath, isNull);
    expect(row.photoTransport, 'sem_foto');
    expect(jsonDecode(row.metadata)['presenca_local_vinculado'], 'dentro');
  });
  test(
    'always-required sector still requests selfie inside its perimeter',
    () async {
      sensors.evidence = position();
      await capture(snapshot(selfie: true));
      final row = (await outbox.list(session.scope)).single;
      expect(sensors.photoCalls, 1);
      expect(jsonDecode(row.metadata)['selfie_motivo'], 'politica_do_setor');
    },
  );
  test(
    'ignored server location policy cannot bypass the conditional selfie',
    () async {
      sensors.evidence = position(latitude: -8.01);
      await capture(snapshot(ignored: true));
      expect(sensors.ignored, isFalse);
      expect(sensors.photoCalls, 1);
      expect((await outbox.list(session.scope)).single.photoPath, isNotNull);
    },
  );
  for (final status in [
    'servico_desligado',
    'tempo_esgotado',
    'indisponivel',
  ]) {
    test(
      '$status requires selfie while retaining the original location status',
      () async {
        sensors.evidence = PositionEvidence(null, status);
        await capture(snapshot());
        final row = (await outbox.list(session.scope)).single;
        expect(sensors.photoCalls, 1);
        expect(jsonDecode(row.metadata)['localizacao_status'], status);
        expect(jsonDecode(row.payload)['posicao'], isNull);
      },
    );
  }
  test('low accuracy inside a workplace still requires a photo', () async {
    sensors.evidence = position(accuracy: 150);
    await capture(snapshot());
    expect(sensors.photoCalls, 1);
    final row = (await outbox.list(session.scope)).single;
    expect(
      jsonDecode(row.metadata)['presenca_local_vinculado'],
      'nao_confirmada',
    );
  });
  test('uncertainty crossing the perimeter requires a photo', () async {
    sensors.evidence = position(latitude: -8.0008, accuracy: 20);
    await capture(snapshot());
    expect(sensors.photoCalls, 1);
    expect(
      jsonDecode(
        (await outbox.list(session.scope)).single.metadata,
      )['presenca_local_vinculado'],
      'nao_confirmada',
    );
  });
  for (final expired in [false, true]) {
    test(
      'another ${expired ? 'expired' : 'active'} linked workplace ${expired ? 'cannot' : 'can'} dispense selfie',
      () async {
        sensors.evidence = position();
        final data = snapshot(
          configure: (body) {
            final first = body['alocacoes'][0];
            final other = jsonDecode(jsonEncode(first));
            other['id'] = '77777777-7777-4777-8777-777777777777';
            other['setor']['id'] = '88888888-8888-4888-8888-888888888888';
            if (expired) {
              other['data_inicio'] = '2026-10-01';
              other['data_fim'] = '2026-10-04';
            }
            first['setor']['latitude'] = -7.0;
            body['alocacoes'].add(other);
            body['status'] = 'MULTIPLAS_ALOCACOES';
            body['setor'] = null;
            body['escala'] = null;
          },
        );
        await capture(data);
        expect(sensors.photoCalls, expired ? 1 : 0);
      },
    );
  }
  test(
    'declining required selfie does not save a point or open camera',
    () async {
      await expectLater(
        capture(snapshot(), confirmSelfie: (_) async => false),
        throwsA(isA<AppFailure>()),
      );
      expect(await outbox.list(session.scope), isEmpty);
      expect(sensors.photoCalls, 0);
      expect(await photos.list(recursive: true).toList(), isEmpty);
    },
  );
  for (final empty in [false, true]) {
    test(
      '${empty ? 'empty' : 'cancelled'} camera result cannot save a point',
      () async {
        sensors.cancelPhoto = !empty;
        sensors.emptyPhoto = empty;
        await expectLater(capture(snapshot()), throwsA(isA<AppFailure>()));
        expect(await outbox.list(session.scope), isEmpty);
        expect(await photos.list(recursive: true).toList(), isEmpty);
      },
    );
  }
  test('session change while dialog is open prevents camera capture', () async {
    var authorized = true;
    await expectLater(
      capture(
        snapshot(),
        authorized: () => authorized,
        confirmSelfie: (_) async {
          authorized = false;
          return true;
        },
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(sensors.photoCalls, 0);
    expect(await outbox.list(session.scope), isEmpty);
  });
  test(
    'session change during camera discards the new uncommitted photo',
    () async {
      var authorized = true;
      sensors.afterPhoto = () => authorized = false;
      await expectLater(
        capture(snapshot(), authorized: () => authorized),
        throwsA(isA<AppFailure>()),
      );
      expect(await outbox.list(session.scope), isEmpty);
      expect(
        await photos.list(recursive: true).where((e) => e is File).toList(),
        isEmpty,
      );
    },
  );
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
      expect(sensors.photoCalls, 0);
    },
  );
}
