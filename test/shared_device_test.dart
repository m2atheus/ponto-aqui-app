import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:timezone/data/latest.dart' as tz;
import 'package:ponto_aqui_app/app/app_runtime.dart';
import 'package:ponto_aqui_app/core/clock/clock_sample.dart';
import 'package:ponto_aqui_app/core/config/app_config.dart';
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/core/device/evidence_sensors.dart';
import 'package:ponto_aqui_app/core/errors/app_failure.dart';
import 'package:ponto_aqui_app/features/auth/data/auth_repository.dart';
import 'package:ponto_aqui_app/features/auth/domain/mobile_session.dart';
import 'package:ponto_aqui_app/features/auth/presentation/auth_view_model.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/bootstrap_repository.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';
import 'package:ponto_aqui_app/features/bootstrap/domain/bootstrap_snapshot.dart';
import 'package:ponto_aqui_app/features/bootstrap/presentation/work_view_model.dart';
import 'package:ponto_aqui_app/features/marcacoes/data/outbox_repository.dart';
import 'package:ponto_aqui_app/features/marcacoes/domain/capture_punch.dart';
import 'package:ponto_aqui_app/features/marcacoes/domain/punch_event.dart';
import 'package:ponto_aqui_app/features/sincronizacao/domain/sync_worker.dart';

import 'support.dart';

const sectorA = '33333333-3333-4333-8333-333333333333';
const sectorB = '77777777-7777-4777-8777-777777777777';
const allocationB = '88888888-8888-4888-8888-888888888888';
final fixedNow = DateTime.utc(2026, 10, 5, 15);

Map<String, dynamic> clockBody({String sector = sectorA, DateTime? at}) {
  final body = fixture('relogio');
  final own = body['funcionarios'][0];
  final noAccount = jsonDecode(jsonEncode(own));
  noAccount['id'] = '66666666-6666-4666-8666-666666666666';
  noAccount['usuario_id'] = null;
  noAccount['nome'] = 'Pessoa sem conta';
  noAccount['alocacoes'][0]['id'] = '99999999-9999-4999-8999-999999999998';
  body['funcionarios'] = [noAccount, own];
  body['setor']['id'] = sector;
  body['setor']['nome'] = sector == sectorA ? 'Portaria' : 'Expedicao';
  body['setor']['latitude'] = sector == sectorA ? -8.0 : -9.0;
  body['setor']['politicas']['exige_selfie'] = sector == sectorB;
  if (sector == sectorB) own['alocacoes'][0]['id'] = allocationB;
  body['setores_disponiveis'] = [
    {'id': sectorA, 'nome': 'Portaria'},
    {'id': sectorB, 'nome': 'Expedicao'},
  ];
  final instant = at ?? fixedNow;
  body['server_timestamp'] = instant.toIso8601String();
  body['data_referencia'] = ClockSample.civilDate(instant, 'America/Sao_Paulo');
  return body;
}

class SharedSensors implements EvidenceSensors {
  double latitude = -8;
  int photos = 0;
  @override
  Future<PositionEvidence> location({required bool ignored}) async =>
      PositionEvidence({
        'latitude': latitude,
        'longitude': -35.0,
        'precisao_metros': 5.0,
      }, 'capturada');
  @override
  Future<Uint8List> selfie() async {
    photos++;
    return prepareSelfie(
      Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8))),
    );
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
  late AppDatabase db;
  late Directory photos;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    photos = await Directory.systemTemp.createTemp('ponto-shared-');
  });
  tearDown(() async {
    await db.close();
    await photos.delete(recursive: true);
  });

  test('UUID login derives internal device ID from server JWT and verifies /me without mandatory sector', () async {
    final token = testJwt(
      overrides: {
        'setor_id': sectorA,
        'setor_ids': [sectorA, sectorB],
      },
    );
    final adapter = FakeAdapter((request) {
      if (request.path.endsWith('/login')) {
        expect(request.data, {
          'email': session.email,
          'senha': 'synthetic-password',
          'device_uuid': session.deviceUuid,
        });
        return FakeAdapter.json({
          'access_token': token,
          'token_type': 'Bearer',
          'usuario': profile(),
          'setores_disponiveis': clockBody()['setores_disponiveis'],
        });
      }
      expect(request.path, '/api/mobile/auth/me');
      expect(request.headers['Authorization'], 'Bearer $token');
      return FakeAdapter.json({'usuario': profile()});
    });
    final storage = MemorySessionStorage();
    final result = await AuthRepository(
      fakeApi(adapter),
      storage,
    ).login(session.email, 'synthetic-password');
    expect(result.deviceId, session.deviceId);
    expect(result.deviceUuid, session.deviceUuid);
    expect(result.initialSectorId, sectorA);
    expect(result.authorizedSectorIds, [sectorA, sectorB]);
    expect(storage.value!.token, token);
    expect(adapter.requests, hasLength(2));
  });

  test(
    'optional login sector is sent without replacing installation UUID',
    () async {
      final token = testJwt(
        overrides: {
          'setor_id': sectorB,
          'setor_ids': [sectorA, sectorB],
        },
      );
      final adapter = FakeAdapter((request) {
        if (request.path.endsWith('/login')) {
          expect((request.data as Map)['setor_id'], sectorB);
          expect((request.data as Map)['device_uuid'], session.deviceUuid);
          expect((request.data as Map).containsKey('dispositivo_id'), isFalse);
          return FakeAdapter.json({
            'access_token': token,
            'token_type': 'Bearer',
            'usuario': profile(),
          });
        }
        return FakeAdapter.json({'usuario': profile()});
      });
      expect(
        (await AuthRepository(
          fakeApi(adapter),
          MemorySessionStorage(),
        ).login(session.email, 'synthetic', sectorId: sectorB)).initialSectorId,
        sectorB,
      );
    },
  );

  test('invalid credentials or unknown installation keep generic login error and never provision device', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json({
        'erro': {'codigo': 'LOGIN_INVALIDO', 'mensagem': 'Internal detail'},
      }, 401),
    );
    await expectLater(
      AuthRepository(
        fakeApi(adapter),
        MemorySessionStorage(),
      ).login('invalid@example.test', 'synthetic'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'Usuário ou senha inválidos',
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/api/mobile/auth/login');
  });

  test('device UUID disagreement never persists a session', () async {
    final storage = MemorySessionStorage();
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json({
        'access_token': testJwt(overrides: {'device_uuid': sectorB}),
        'token_type': 'Bearer',
        'usuario': profile(),
      }),
    );
    await expectLater(
      AuthRepository(
        fakeApi(adapter),
        storage,
      ).login(session.email, 'synthetic'),
      throwsA(isA<AppFailure>()),
    );
    expect(storage.value, isNull);
  });

  test('clock selects only authenticated employee, ignores first catalog entry without account and accepts open-ended allocation', () {
    final snapshot = BootstrapSnapshot(
      MobileSyncDto.fromJson(clockBody()),
      ClockSample(offsetMs: 0, receivedAt: fixedNow, roundTripMs: 0),
    );
    expect(snapshot.employeeFor(session.userId)!.nome, 'Ana Silva');
    final own = snapshot.allocationsFor(session.userId).single;
    expect(own.id, evidence()['alocacao_id']);
    expect(own.dataFim, isNull);
    expect(own.escala!.id, snapshot.data.escalas.single.id);
    expect(
      snapshot.captureRestriction(
        fixedNow,
        userId: session.userId,
        role: session.role,
      ),
      isNull,
    );
    expect(snapshot.allocationsFor('not-a-user'), isEmpty);
    expect(
      snapshot.captureRestriction(fixedNow, userId: 'not-a-user'),
      isNotNull,
    );
    expect(
      snapshot.captureRestriction(
        fixedNow,
        userId: session.userId,
        role: 'USUARIO_SETOR',
      ),
      isNotNull,
    );
  });

  test('sector caches, selected context and policies remain independent without changing JWT', () async {
    final adapter = FakeAdapter(
      (request) => FakeAdapter.json(
        clockBody(
          sector: request.queryParameters['setor_id'] as String? ?? sectorA,
        ),
      ),
    );
    final repo = BootstrapRepository(db, fakeApi(adapter), now: () => fixedNow);
    final a = await repo.refresh(session);
    await repo.selectSector(session, sectorB);
    final b = await repo.refresh(session);
    expect(b.data.setor!.politicas.exigeSelfie, isTrue);
    expect(a.data.setor!.politicas.exigeSelfie, isFalse);
    final restarted = BootstrapRepository(
      db,
      fakeApi(adapter),
      now: () => fixedNow,
    );
    expect(await restarted.selectedSector(session), sectorB);
    expect((await restarted.cached(session))!.data.setor!.id, sectorB);
    expect(
      (await restarted.cached(session, sectorId: sectorA))!.data.toJson(),
      a.data.toJson(),
    );
    expect(adapter.requests.last.queryParameters, {'setor_id': sectorB});
    expect(adapter.requests.map((r) => r.headers['Authorization']).toSet(), {
      'Bearer ${session.token}',
    });
    final other = MobileSession.fromJson({
      ...session.toJson(),
      'userId': sectorB,
    });
    expect(await repo.cached(other, sectorId: sectorB), isNull);
  });

  test('legacy cache is read only for its own sector, without requiring setores_disponiveis', () async {
    await db
        .into(db.bootstrapCaches)
        .insert(
          BootstrapCachesCompanion.insert(
            scope: session.scope,
            payload: jsonEncode(fixture('relogio')),
            receivedMs: fixedNow.millisecondsSinceEpoch,
            offsetMs: 0,
            roundTripMs: 0,
          ),
        );
    final repo = BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => throw StateError('No network'))),
    );
    expect(
      (await repo.cached(session, sectorId: sectorA))!.data.setor!.id,
      sectorA,
    );
    expect(await repo.cached(session, sectorId: sectorB), isNull);
  });

  test('capture in two sectors freezes own allocation and original policy metadata, with selfie required in B', () async {
    final sensors = SharedSensors();
    final outbox = OutboxRepository(db);
    final capture = CapturePunch(outbox, sensors, photos, now: () => fixedNow);
    for (final sector in [sectorA, sectorB]) {
      sensors.latitude = sector == sectorA ? -8 : -9;
      final snapshot = BootstrapSnapshot(
        MobileSyncDto.fromJson(clockBody(sector: sector)),
        ClockSample(offsetMs: 0, receivedAt: fixedNow, roundTripMs: 0),
      );
      await capture(
        session: session,
        snapshot: snapshot,
        allocationId: snapshot.allocationsFor(session.userId).single.id,
        type: PunchType.entrada,
        offlineSignal: true,
        authorized: () => true,
      );
    }
    final rows = await outbox.list(session.scope);
    expect(rows, hasLength(2));
    final a = rows.singleWhere(
      (r) => jsonDecode(r.payload)['alocacao_id'] != allocationB,
    );
    final b = rows.singleWhere(
      (r) => jsonDecode(r.payload)['alocacao_id'] == allocationB,
    );
    expect(a.photoPath, isNull);
    expect(b.photoPath, isNotNull);
    expect(sensors.photos, 1);
    expect(jsonDecode(a.metadata)['setor_id'], sectorA);
    expect(jsonDecode(b.metadata)['setor_id'], sectorB);
    expect(jsonDecode(b.payload).keys.toSet(), {
      'evento_cliente_id',
      'dispositivo_id',
      'alocacao_id',
      'tipo',
      'ocorrido_em',
      'desvio_relogio_segundos',
      'registrado_offline',
      'posicao',
    });
    final before = a.payload;
    await BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => FakeAdapter.json(clockBody()))),
    ).selectSector(session, sectorB);
    expect(
      (await outbox.list(session.scope))
          .singleWhere((r) => r.eventId == a.eventId)
          .payload,
      before,
    );
  });

  test(
    'allocation from another employee is rejected before GPS or camera',
    () async {
      final sensors = SharedSensors();
      final snapshot = BootstrapSnapshot(
        MobileSyncDto.fromJson(clockBody()),
        ClockSample(offsetMs: 0, receivedAt: fixedNow, roundTripMs: 0),
      );
      await expectLater(
        CapturePunch(
          OutboxRepository(db),
          sensors,
          photos,
          now: () => fixedNow,
        )(
          session: session,
          snapshot: snapshot,
          allocationId: snapshot.data.funcionarios.first.alocacoes.single.id,
          type: PunchType.entrada,
          offlineSignal: false,
          authorized: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(await OutboxRepository(db).list(session.scope), isEmpty);
      expect(sensors.photos, 0);
    },
  );

  test('migration from v1 preserves queued point, photo bytes, cache and immutable trigger', () async {
    await db.close();
    final file = File('${photos.path}/migration.sqlite');
    final photo = await File('${photos.path}/pending.jpg')
        .writeAsBytes([1, 2, 3, 4]);
    final original = event(
      evidence(),
      photoPath: photo.path,
      photoSha: sha256.convert(await photo.readAsBytes()).toString(),
    );
    var old = AppDatabase(NativeDatabase(file));
    await OutboxRepository(old).save(session.scope, original);
    await old
        .into(old.bootstrapCaches)
        .insert(
          BootstrapCachesCompanion.insert(
            scope: session.scope,
            payload: jsonEncode(fixture()),
            receivedMs: fixedNow.millisecondsSinceEpoch,
            offsetMs: 0,
            roundTripMs: 0,
          ),
        );
    await old.customStatement('DROP TABLE selected_contexts');
    await old.customStatement('PRAGMA user_version = 1');
    await old.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    try {
      final row = (await OutboxRepository(upgraded).list(session.scope)).single;
      expect(row.payload, original.payloadJson);
      expect(row.photoSha, original.photoSha);
      expect(await File(row.photoPath!).readAsBytes(), [1, 2, 3, 4]);
      expect(
        await upgraded.select(upgraded.bootstrapCaches).get(),
        hasLength(1),
      );
      expect(await upgraded.select(upgraded.selectedContexts).get(), isEmpty);
      await expectLater(
        upgraded.customStatement("UPDATE outbox_events SET payload = '{}'"),
        throwsA(anything),
      );
    } finally {
      await upgraded.close();
    }
  });
  Future<
    ({
      AppRuntime runtime,
      ProviderContainer container,
      WorkViewModel vm,
      MemorySessionStorage storage,
    })
  >
  workHarness(FakeAdapter adapter) async {
    final storage = MemorySessionStorage(session);
    final signals = FakeConnections();
    final runtime = AppRuntime(
      config: AppConfig(session.origin),
      db: db,
      api: fakeApi(adapter),
      storage: storage,
      photos: photos,
      installationUuid: session.deviceUuid,
      connections: signals,
      sensors: SharedSensors()..latitude = -9,
    );
    final container = ProviderContainer(
      overrides: [runtimeProvider.overrideWithValue(runtime)],
    );
    await container.read(authProvider.future);
    final listener = container.listen(workProvider(session.scope), (_, _) {});
    addTearDown(() async {
      listener.close();
      container.dispose();
      await signals.controller.close();
    });
    for (var attempt = 0; attempt < 200; attempt++) {
      final state = container.read(workProvider(session.scope));
      if (state.snapshot != null && !state.busy) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(container.read(workProvider(session.scope)).snapshot, isNotNull);
    return (
      runtime: runtime,
      container: container,
      vm: container.read(workProvider(session.scope).notifier),
      storage: storage,
    );
  }

  test('late response from previous sector cannot replace new state, selection or cached policies', () async {
    final held = Completer<ResponseBody>();
    final started = Completer<void>();
    var delayA = false;
    final adapter = FakeAdapter((request) {
      if (request.path.endsWith('/me')) {
        return FakeAdapter.json({'usuario': profile()});
      }
      if (request.path.endsWith('/sync')) {
        final sector =
            request.queryParameters['setor_id'] as String? ?? sectorA;
        if (delayA && sector == sectorA) {
          started.complete();
          return held.future;
        }
        return FakeAdapter.json(
          clockBody(sector: sector, at: DateTime.now().toUtc()),
        );
      }
      return FakeAdapter.json({}, 503);
    });
    final harness = await workHarness(adapter);
    delayA = true;
    final previous = harness.vm.refresh();
    await started.future;
    final next = harness.vm.selectSector(sectorB);
    expect(
      harness.container.read(workProvider(session.scope)).snapshot,
      isNull,
    );
    await next;
    expect(
      harness.container
          .read(workProvider(session.scope))
          .snapshot!
          .data
          .setor!
          .id,
      sectorB,
    );
    final stale = clockBody(at: DateTime.now().toUtc());
    stale['setor']['nome'] = 'STALE RESPONSE';
    held.complete(FakeAdapter.json(stale));
    await previous;
    final state = harness.container.read(workProvider(session.scope));
    expect(state.selectedSectorId, sectorB);
    expect(state.snapshot!.data.setor!.politicas.exigeSelfie, isTrue);
    expect(await harness.runtime.bootstrap.selectedSector(session), sectorB);
    expect(
      (await harness.runtime.bootstrap.cached(
        session,
        sectorId: sectorA,
      ))!.data.setor!.nome,
      'Portaria',
    );
  });

  test('network failure for uncached B never reuses A and reconnect retries B without changing JWT', () async {
    var unavailable = true;
    final adapter = FakeAdapter((request) {
      if (request.path.endsWith('/me')) {
        return FakeAdapter.json({'usuario': profile()});
      }
      final sector = request.queryParameters['setor_id'] as String? ?? sectorA;
      if (sector == sectorB && unavailable) return FakeAdapter.json({}, 503);
      return FakeAdapter.json(
        clockBody(sector: sector, at: DateTime.now().toUtc()),
      );
    });
    final harness = await workHarness(adapter);
    await harness.vm.selectSector(sectorB);
    var state = harness.container.read(workProvider(session.scope));
    expect(state.selectedSectorId, sectorB);
    expect(state.snapshot, isNull);
    expect(harness.storage.value!.canSend, isTrue);
    expect(
      await harness.vm.capture(
        evidence()['alocacao_id'] as String,
        PunchType.entrada,
      ),
      isFalse,
    );
    expect(await harness.runtime.outbox.list(session.scope), isEmpty);
    unavailable = false;
    await harness.vm.refresh();
    state = harness.container.read(workProvider(session.scope));
    expect(state.snapshot!.data.setor!.id, sectorB);
    expect(adapter.requests.last.queryParameters, {'setor_id': sectorB});
    expect(harness.storage.value!.token, session.token);
  });

  test('cached B supports offline capture under B policy instead of using A geofence', () async {
    var unavailable = false;
    final adapter = FakeAdapter((request) {
      if (request.path.endsWith('/me')) {
        return FakeAdapter.json({'usuario': profile()});
      }
      if (!request.path.endsWith('/sync')) return FakeAdapter.json({}, 503);
      final sector = request.queryParameters['setor_id'] as String? ?? sectorA;
      if (unavailable && sector == sectorB) return FakeAdapter.json({}, 503);
      return FakeAdapter.json(
        clockBody(sector: sector, at: DateTime.now().toUtc()),
      );
    });
    final harness = await workHarness(adapter);
    await harness.runtime.bootstrap.refresh(session, sectorId: sectorB);
    unavailable = true;
    await harness.vm.selectSector(sectorB);
    expect(
      harness.container
          .read(workProvider(session.scope))
          .snapshot!
          .data
          .setor!
          .id,
      sectorB,
    );
    expect(
      await harness.vm.capture(
        allocationB,
        PunchType.entrada,
        confirmSelfie: (_) async => true,
      ),
      isTrue,
    );
    await harness.vm.synchronize();
    final row = (await harness.runtime.outbox.list(session.scope)).single;
    expect(jsonDecode(row.payload)['alocacao_id'], allocationB);
    expect(jsonDecode(row.metadata)['setor_id'], sectorB);
    expect(row.photoPath, isNotNull);
    expect(row.transport, 'na_fila');
    await harness.vm.synchronize();
  });

  for (final denial in [
    (status: 401, code: 'TOKEN_INVALIDO'),
    (status: 403, code: 'DISPOSITIVO_NEGADO'),
    (status: 403, code: 'DISPOSITIVO_MODO_ALTERADO'),
  ]) {
    test(
      '${denial.code} requires login and preserves queued photo and event',
      () async {
        var deny = false;
        final adapter = FakeAdapter((request) {
          if (request.path.endsWith('/me')) {
            return FakeAdapter.json({'usuario': profile()});
          }
          if (deny) {
            return FakeAdapter.json({
              'erro': {'codigo': denial.code, 'mensagem': 'Denied'},
            }, denial.status);
          }
          return FakeAdapter.json(clockBody(at: DateTime.now().toUtc()));
        });
        final harness = await workHarness(adapter);
        final photo = await File('${photos.path}/retained.jpg')
            .writeAsBytes([7, 8, 9]);
        final original = event(
          evidence(),
          photoPath: photo.path,
          photoSha: sha256.convert(await photo.readAsBytes()).toString(),
        );
        await harness.runtime.outbox.save(session.scope, original);
        deny = true;
        await harness.vm.refresh();
        expect(harness.storage.value!.canSend, isFalse);
        if (denial.code == 'DISPOSITIVO_MODO_ALTERADO') {
          expect(harness.storage.value!.blockedReason, contains('convertido'));
        }
        final row = (await harness.runtime.outbox.list(session.scope)).single;
        expect(row.payload, original.payloadJson);
        expect(row.photoSha, original.photoSha);
        expect(await photo.readAsBytes(), [7, 8, 9]);
        final calls = adapter.requests.length;
        await harness.vm.synchronize(manual: true);
        expect(adapter.requests, hasLength(calls));
        expect(
          adapter.requests.where((r) => r.path.endsWith('/lote')),
          isEmpty,
        );
      },
    );
  }

  test('account switch never sends previous user photo and does not stall the new user queue', () async {
    final outbox = OutboxRepository(db);
    final second = MobileSession.fromJson({
      ...session.toJson(),
      'userId': sectorB,
      'token': testJwt(overrides: {'sub': sectorB}),
    });
    final photo = await File('${photos.path}/first-user.jpg')
        .writeAsBytes([1, 2, 3]);
    final firstPayload = evidence();
    final secondPayload = evidence();
    await outbox.save(
      session.scope,
      event(
        firstPayload,
        photoPath: photo.path,
        photoSha: sha256.convert([1, 2, 3]).toString(),
      ),
    );
    await outbox.save(second.scope, event(secondPayload));
    final started = Completer<void>();
    final held = Completer<ResponseBody>();
    var firstAuthorized = true;
    final adapter = FakeAdapter((request) {
      expect(request.path, '/api/mobile/marcacoes/lote');
      final sent = (request.data as Map)['marcacoes'] as List;
      if (request.headers['Authorization'] == 'Bearer ${session.token}') {
        expect(sent.single, firstPayload);
        started.complete();
        return held.future;
      }
      expect(request.headers['Authorization'], 'Bearer ${second.token}');
      expect(sent.single, secondPayload);
      return FakeAdapter.json({
        'resultados': [receipt(secondPayload, 0)],
      });
    });
    final worker = SyncWorker(outbox, fakeApi(adapter));
    final old = worker.run(
      session,
      authorized: () => firstAuthorized,
      onDenied: (_) async {},
    );
    await started.future;
    firstAuthorized = false;
    await worker.run(second, authorized: () => true, onDenied: (_) async {});
    expect((await outbox.list(second.scope)).single.transport, 'confirmada');
    held.complete(
      FakeAdapter.json({
        'resultados': [receipt(firstPayload, 0)],
      }),
    );
    await old;
    expect(adapter.requests, hasLength(2));
    expect((await outbox.list(session.scope)).single.photoTransport, 'na_fila');
    expect(await photo.exists(), isTrue);
  });

  test('after sector switch retries keep original point UUID, allocation, time and selfie bytes', () async {
    final outbox = OutboxRepository(db);
    final original = evidence();
    final bytes = [255, 216, 255, 42, 255, 217];
    final photo = await File('${photos.path}/immutable.jpg')
        .writeAsBytes(bytes);
    final hash = sha256.convert(bytes).toString();
    await outbox.save(
      session.scope,
      event(original, photoPath: photo.path, photoSha: hash),
    );
    var pointCalls = 0, photoCalls = 0;
    final adapter = FakeAdapter((request) {
      expect(request.queryParameters, isEmpty);
      if (request.path.endsWith('/lote')) {
        pointCalls++;
        expect((request.data as Map)['marcacoes'], [original]);
        if (pointCalls == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return FakeAdapter.json({
          'resultados': [
            receipt(original, 0, duplicate: true, situation: 'Recusada'),
          ],
        }, 207);
      }
      photoCalls++;
      expect(
        request.path,
        '/api/mobile/marcacoes/${original['evento_cliente_id']}/selfie',
      );
      expect((request.data as FormData).files.single.key, 'selfie');
      expect(photo.readAsBytesSync(), bytes);
      if (photoCalls == 1) return FakeAdapter.json({}, 503);
      return FakeAdapter.json({
        'evento_cliente_id': original['evento_cliente_id'],
        'selfie_id': sectorB,
        'sha256': hash,
        'content_type': 'image/jpeg',
        'duplicada': true,
      });
    });
    final repo = BootstrapRepository(db, fakeApi(adapter));
    await repo.selectSector(session, sectorB);
    final worker = SyncWorker(outbox, fakeApi(adapter));
    await worker.run(session, authorized: () => true, onDenied: (_) async {});
    await worker.run(
      session,
      authorized: () => true,
      onDenied: (_) async {},
      manual: true,
    );
    await worker.run(
      session,
      authorized: () => true,
      onDenied: (_) async {},
      manual: true,
    );
    final row = (await outbox.list(session.scope)).single;
    expect(row.transport, 'confirmada');
    expect(jsonDecode(row.receipt!)['situacao'], 'Recusada');
    expect(row.photoTransport, 'confirmada');
    expect(pointCalls, 2);
    expect(photoCalls, 2);
    expect(row.payload, jsonEncode(original));
    expect(row.photoSha, hash);
    expect(await photo.readAsBytes(), bytes);
  });
  test('logout and login of another employee preserve prior queue without reusing its session or sector selection', () async {
    final secondToken = testJwt(
      overrides: {
        'sub': sectorB,
        'setor_id': sectorB,
        'setor_ids': [sectorB],
      },
    );
    final secondProfile = {
      ...profile(),
      'id': sectorB,
      'nome': 'Outra pessoa',
      'email': 'other@example.test',
    };
    final adapter = FakeAdapter((request) {
      if (request.path.endsWith('/login')) {
        expect((request.data as Map)['device_uuid'], session.deviceUuid);
        return FakeAdapter.json({
          'access_token': secondToken,
          'token_type': 'Bearer',
          'usuario': secondProfile,
        });
      }
      if (request.path.endsWith('/me')) {
        return FakeAdapter.json({
          'usuario': request.headers['Authorization'] == 'Bearer $secondToken'
              ? secondProfile
              : profile(),
        });
      }
      return FakeAdapter.json(clockBody(at: DateTime.now().toUtc()));
    });
    final harness = await workHarness(adapter);
    final original = event(evidence());
    await harness.runtime.outbox.save(session.scope, original);
    await harness.container.read(authProvider.notifier).logout();
    expect(harness.storage.value, isNull);
    expect(harness.container.read(authProvider).asData!.value, isNull);
    await harness.container
        .read(authProvider.notifier)
        .login('other@example.test', 'synthetic');
    final next = harness.container.read(authProvider).asData!.value!;
    expect(next.userId, sectorB);
    expect(next.scope, isNot(session.scope));
    expect(next.deviceUuid, session.deviceUuid);
    expect(next.token, secondToken);
    expect(await harness.runtime.outbox.list(next.scope), isEmpty);
    expect(
      (await harness.runtime.outbox.list(session.scope)).single.payload,
      original.payloadJson,
    );
    expect(await harness.runtime.bootstrap.cached(next), isNull);
    expect(await harness.runtime.bootstrap.selectedSector(next), sectorB);
    expect(adapter.requests.where((r) => r.path.endsWith('/lote')), isEmpty);
  });

  test('personal-to-clock conversion with fresh JWT keeps historical evidence and enables only own clock allocation', () async {
    final outbox = OutboxRepository(db);
    final original = event(evidence());
    await outbox.save(session.scope, original);
    final token = testJwt(
      overrides: {
        'setor_id': sectorA,
        'setor_ids': [sectorA, sectorB],
      },
    );
    final adapter = FakeAdapter((request) {
      if (request.path.endsWith('/login')) {
        return FakeAdapter.json({
          'access_token': token,
          'token_type': 'Bearer',
          'usuario': profile(),
        });
      }
      if (request.path.endsWith('/me')) {
        return FakeAdapter.json({'usuario': profile()});
      }
      return FakeAdapter.json(clockBody());
    });
    final account = await AuthRepository(
      fakeApi(adapter),
      MemorySessionStorage(),
    ).login(session.email, 'synthetic');
    expect(account.scope, session.scope);
    final snapshot = await BootstrapRepository(
      db,
      fakeApi(adapter),
      now: () => fixedNow,
    ).refresh(account);
    expect(
      snapshot.captureRestriction(
        fixedNow,
        userId: account.userId,
        role: account.role,
      ),
      isNull,
    );
    expect(
      snapshot.allocationsFor(account.userId).single.id,
      evidence()['alocacao_id'],
    );
    expect(
      (await outbox.list(account.scope)).single.payload,
      original.payloadJson,
    );
  });
  test(
    'forbidden device login keeps the same generic credential error',
    () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json({
          'erro': {
            'codigo': 'DISPOSITIVO_NEGADO',
            'mensagem': 'Internal authorization detail',
          },
        }, 403),
      );
      await expectLater(
        AuthRepository(
          fakeApi(adapter),
          MemorySessionStorage(),
        ).login(session.email, 'synthetic'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            'Usuário ou senha inválidos',
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );
}
