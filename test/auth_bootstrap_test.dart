import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ponto_aqui_app/app/app_runtime.dart';
import 'package:ponto_aqui_app/core/config/app_config.dart';
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/core/errors/app_failure.dart';
import 'package:ponto_aqui_app/features/auth/data/auth_repository.dart';
import 'package:ponto_aqui_app/features/auth/presentation/auth_view_model.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/bootstrap_repository.dart';
import 'package:ponto_aqui_app/features/bootstrap/presentation/work_view_model.dart';

import 'support.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  test(
    'changed administrative role cannot restore stale offline authority',
    () async {
      final storage = MemorySessionStorage(session);
      final api = fakeApi(
        FakeAdapter(
          (_) => FakeAdapter.json({'usuario': profile()..['papel'] = 'RH'}),
        ),
      );
      final restored = await AuthRepository(api, storage).restore();
      expect(restored!.canSend, isFalse);
      expect(storage.value!.canSend, isFalse);
    },
  );
  test(
    'mobile login sends only actual contract fields and verifies /me',
    () async {
      final adapter = FakeAdapter((request) {
        if (request.path.endsWith('/login')) {
          expect(request.data, {
            'email': session.email,
            'senha': 'test-password',
            'device_uuid': session.deviceUuid,
          });
          expect(request.headers.containsKey('Authorization'), isFalse);
          return FakeAdapter.json({
            'access_token': session.token,
            'token_type': 'Bearer',
            'usuario': profile(),
          });
        }
        expect(request.path, '/api/mobile/auth/me');
        expect(request.headers['Authorization'], 'Bearer ${session.token}');
        return FakeAdapter.json({'usuario': profile()});
      });
      final storage = MemorySessionStorage();
      final repository = AuthRepository(fakeApi(adapter), storage);
      final signedIn = await repository.login(session.email, 'test-password');
      expect(signedIn.scope, session.scope);
      expect(storage.value!.scope, session.scope);
      expect(adapter.requests, hasLength(2));
    },
  );
  test('only previously validated secure session restores offline; 401 persists block', () async {
    final storage = MemorySessionStorage(session);
    final offline = fakeApi(
      FakeAdapter(
        (request) => throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    expect((await AuthRepository(offline, storage).restore())!.canSend, isTrue);
    final denied = fakeApi(
      FakeAdapter(
        (_) => FakeAdapter.json({
          'erro': {'mensagem': 'Expirado'},
        }, 401),
      ),
    );
    expect((await AuthRepository(denied, storage).restore())!.canSend, isFalse);
    final noRequests = FakeAdapter(
      (_) => throw StateError('must remain blocked offline'),
    );
    expect(
      (await AuthRepository(fakeApi(noRequests), storage).restore())!.canSend,
      isFalse,
    );
    expect(noRequests.requests, isEmpty);
  });
  test(
    'malformed refresh preserves previous validated cache atomically',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var valid = true;
      final api = fakeApi(
        FakeAdapter(
          (_) => FakeAdapter.json(valid ? fixture() : {'status': 'OK'}),
        ),
      );
      final repository = BootstrapRepository(
        db,
        api,
        now: () => DateTime.utc(2026, 10, 5, 15),
      );
      await repository.refresh(session);
      valid = false;
      await expectLater(
        repository.refresh(session),
        throwsA(isA<AppFailure>()),
      );
      expect(
        (await repository.cached(session))!.data.funcionario!.nome,
        'Ana Silva',
      );
    },
  );
  test('invalid IANA timezone never replaces cache', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final body = fixture()..['fuso_horario'] = 'Invalid/Zone';
    final repo = BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => FakeAdapter.json(body))),
    );
    await expectLater(repo.refresh(session), throwsA(isA<AppFailure>()));
    expect(await repo.cached(session), isNull);
  });
  test(
    'client refuses cross-origin requests even when a token is supplied',
    () async {
      final adapter = FakeAdapter(
        (_) => throw StateError('must not reach network'),
      );
      await expectLater(
        fakeApi(adapter)
            .request('GET', 'https://other.example.test/me', session: session),
        throwsA(isA<AppFailure>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'viewmodels preserve outbox on logout and pause/resume gates new requests',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final signals = FakeConnections();
      addTearDown(signals.controller.close);
      final storage = MemorySessionStorage(session);
      final adapter = FakeAdapter((request) {
        if (request.path.endsWith('/me')) {
          return FakeAdapter.json({'usuario': profile()});
        }
        if (request.path.endsWith('/sync')) return FakeAdapter.json(fixture());
        final marks = (request.data as Map)['marcacoes'] as List;
        return FakeAdapter.json({
          'resultados': marks.indexed
              .map((m) => receipt(m.$2 as Map<String, dynamic>, m.$1))
              .toList(),
        });
      });
      final runtime = AppRuntime(
        config: AppConfig(session.origin),
        db: db,
        api: fakeApi(adapter),
        storage: storage,
        photos: Directory.systemTemp,
        installationUuid: session.deviceUuid,
        connections: signals,
      );
      final container = ProviderContainer(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      final listener = container.listen(workProvider(session.scope), (_, _) {});
      addTearDown(listener.close);
      await pumpEventQueue(times: 30);
      expect(container.read(workProvider(session.scope)).snapshot, isNotNull);
      expect(container.read(workProvider(session.scope)).offline, isTrue);
      final vm = container.read(workProvider(session.scope).notifier);
      vm.setForeground(false);
      final payload = evidence();
      await runtime.outbox.save(session.scope, event(payload));
      final previousRequests = adapter.requests.length;
      await vm.synchronize(manual: true);
      expect(adapter.requests.length, previousRequests);
      vm.setForeground(true);
      await vm.refresh();
      expect(
        (await runtime.outbox.list(session.scope)).single.transport,
        'confirmada',
      );
      await container.read(authProvider.notifier).logout();
      expect(await runtime.outbox.list(session.scope), hasLength(1));
      expect(container.read(authProvider).asData!.value, isNull);
    },
  );
}
