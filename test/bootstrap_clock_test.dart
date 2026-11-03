import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/core/diagnostics/parsing_diagnostic.dart';
import 'package:ponto_aqui_app/core/errors/app_failure.dart';
import 'package:ponto_aqui_app/features/auth/domain/mobile_session.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/bootstrap_repository.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';

import 'support.dart';

Map<String, dynamic> clockPayload() {
  final body = fixture('relogio');
  body['setores_disponiveis'] = [
    {'id': body['setor']['id'], 'nome': body['setor']['nome']},
    {'id': '77777777-7777-4777-8777-777777777777', 'nome': 'Unidade Norte'},
  ];
  return body;
}

void main() {
  setUpAll(tz.initializeTimeZones);
  test('employee on authorized shared device accepts RELOGIO without personal fields', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => FakeAdapter.json(clockPayload()))),
      now: () => DateTime.utc(2026, 10, 5, 15),
    );
    final snapshot = await repository.refresh(session);
    expect(snapshot.data.modoOperacao, ModoOperacao.relogio);
    expect(snapshot.data.funcionario, isNull);
    expect(snapshot.data.alocacoes, isEmpty);
    expect(snapshot.data.marcacoesRecentes, isEmpty);
    expect(snapshot.data.setoresDisponiveis.map((s) => s.nome), [
      'Sede',
      'Unidade Norte',
    ]);
    final cached = await repository.cached(session);
    expect(cached!.data.toJson(), snapshot.data.toJson());
    expect(cached.data.setoresDisponiveis, hasLength(2));
  });
  test('RELOGIO ignores personal-only fields instead of parsing them', () {
    final body = clockPayload()
      ..['funcionario'] = 'not-a-personal-object'
      ..['escala'] = false
      ..['alocacoes'] = {'not': 'a personal list'}
      ..['marcacoes_recentes'] = 42;
    final dto = MobileSyncDto.fromJson(body);
    expect(dto.funcionario, isNull);
    expect(dto.escala, isNull);
    expect(dto.alocacoes, isEmpty);
    expect(dto.marcacoesRecentes, isEmpty);
    final serialized = dto.toJson();
    expect(serialized.containsKey('funcionario'), isFalse);
    expect(serialized.containsKey('alocacoes'), isFalse);
    expect(serialized.containsKey('marcacoes_recentes'), isFalse);
    expect(serialized['setores_disponiveis'], body['setores_disponiveis']);
  });

  test('PESSOAL does not require clock catalogs', () {
    final body = fixture()
      ..['funcionarios'] = false
      ..['escalas'] = 42
      ..['setores_disponiveis'] = 'irrelevant in personal mode';
    final dto = MobileSyncDto.fromJson(body);
    expect(dto.funcionario!.usuarioId, session.userId);
    expect(dto.funcionarios, isEmpty);
    expect(dto.setoresDisponiveis, isEmpty);
    expect(dto.toJson().containsKey('setores_disponiveis'), isFalse);
  });

  test('legacy RELOGIO without sector catalog remains readable', () {
    final dto = MobileSyncDto.fromJson(fixture('relogio'));
    expect(dto.setoresDisponiveis, isEmpty);
    expect(
      MobileSyncDto.fromJson(dto.toJson()).modoOperacao,
      ModoOperacao.relogio,
    );
  });

  test(
    'empty clock sector accepts SEM_FUNCIONARIOS without personal fields',
    () {
      final body = clockPayload()
        ..['funcionarios'] = []
        ..['escalas'] = []
        ..['status'] = 'SEM_FUNCIONARIOS';
      final dto = MobileSyncDto.fromJson(body);
      expect(dto.funcionarios, isEmpty);
      expect(dto.status, 'SEM_FUNCIONARIOS');
    },
  );

  for (final field in ['setor', 'funcionarios', 'escalas']) {
    test('RELOGIO still requires $field', () {
      final body = clockPayload()..remove(field);
      expect(() => MobileSyncDto.fromJson(body), throwsFormatException);
    });
  }

  for (final invalid in [
    'not-list',
    'invalid-id',
    'duplicate',
    'wrong-sector',
  ]) {
    test('invalid clock sector catalog $invalid is rejected', () {
      final body = clockPayload();
      final sectors = body['setores_disponiveis'] as List;
      switch (invalid) {
        case 'not-list':
          body['setores_disponiveis'] = {};
        case 'invalid-id':
          sectors[0]['id'] = 'invalid';
        case 'duplicate':
          sectors.add(sectors.first);
        case 'wrong-sector':
          sectors.removeAt(0);
      }
      expect(() => MobileSyncDto.fromJson(body), throwsFormatException);
    });
  }

  for (final role in ['USUARIO_SETOR', 'RH', 'SUPERADMIN', 'UNKNOWN']) {
    test(
      'RELOGIO role $role ${role == 'USUARIO_SETOR' ? 'can' : 'cannot'} restore clock load',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final account = MobileSession.fromJson({
          ...session.toJson(),
          'role': role,
        });
        final repo = BootstrapRepository(
          db,
          fakeApi(FakeAdapter((_) => FakeAdapter.json(clockPayload()))),
          reportParsingFailure: (_) {},
        );
        if (role == 'USUARIO_SETOR') {
          expect(
            (await repo.refresh(account)).data.modoOperacao,
            ModoOperacao.relogio,
          );
        } else {
          await expectLater(repo.refresh(account), throwsA(isA<AppFailure>()));
          expect(await repo.cached(account), isNull);
        }
      },
    );
  }

  test('USUARIO_SETOR cannot receive a personal load', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final account = MobileSession.fromJson({
      ...session.toJson(),
      'role': 'USUARIO_SETOR',
    });
    final repo = BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => FakeAdapter.json(fixture()))),
      reportParsingFailure: (_) {},
    );
    await expectLater(repo.refresh(account), throwsA(isA<AppFailure>()));
  });

  test('personal employee identity mismatch remains rejected', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final body = fixture();
    body['funcionario']['usuario_id'] = '77777777-7777-4777-8777-777777777777';
    final repo = BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => FakeAdapter.json(body))),
      reportParsingFailure: (_) {},
    );
    await expectLater(repo.refresh(session), throwsA(isA<AppFailure>()));
    expect(await repo.cached(session), isNull);
  });

  test('full exception and parsing stack are logged with token/password redaction and cache preserved', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final messages = <String>[];
    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previousPrint);
    var body = clockPayload();
    final repo = BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => FakeAdapter.json(body))),
      now: () => DateTime.utc(2026, 10, 5, 15),
    );
    final valid = await repo.refresh(session);
    const password = 'DO-NOT-LOG-PASSWORD-123456';
    body = clockPayload()
      ..['fuso_horario'] = 'Invalid/${session.token}/$password'
      ..['diagnostic'] = {'senha': password};
    await expectLater(repo.refresh(session), throwsA(isA<AppFailure>()));
    final logged = messages.join('\n');
    expect(
      logged,
      contains('[bootstrap.parse][api] modo=RELOGIO papel=FUNCIONARIO'),
    );
    expect(logged, contains('LocationNotFoundException'));
    expect(logged, contains('BootstrapRepository._parse'));
    expect(logged, contains('BootstrapRepository.refresh'));
    expect(logged, contains('[REDACTED]'));
    expect(logged, isNot(contains(session.token)));
    expect(logged, isNot(contains(password)));
    expect((await repo.cached(session))!.data.toJson(), valid.data.toJson());
  });

  test(
    'invalid clock shape records field and full trace without replacing cache',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final diagnostics = <ParsingDiagnostic>[];
      var body = clockPayload();
      final repo = BootstrapRepository(
        db,
        fakeApi(FakeAdapter((_) => FakeAdapter.json(body))),
        reportParsingFailure: diagnostics.add,
      );
      final valid = await repo.refresh(session);
      body = clockPayload()..remove('funcionarios');
      await expectLater(repo.refresh(session), throwsA(isA<AppFailure>()));
      expect(diagnostics, hasLength(1));
      expect(
        diagnostics.single.exceptionText,
        contains('funcionarios deve ser uma lista'),
      );
      expect(
        diagnostics.single.stackTrace.toString(),
        contains('MobileSyncDto.fromJson'),
      );
      expect((await repo.cached(session))!.data.toJson(), valid.data.toJson());
    },
  );

  test('corrupt cached JSON emits message and offset but never JSON source containing secrets', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final diagnostics = <ParsingDiagnostic>[];
    const cachePassword = 'NEVER-LOG-CACHED-PASSWORD';
    await db
        .into(db.bootstrapCaches)
        .insert(
          BootstrapCachesCompanion.insert(
            scope: session.scope,
            payload:
                '{"senha":"$cachePassword", "access_token":"${session.token}", broken}',
            receivedMs: 0,
            offsetMs: 0,
            roundTripMs: 0,
          ),
        );
    final repo = BootstrapRepository(
      db,
      fakeApi(FakeAdapter((_) => throw StateError('No network'))),
      reportParsingFailure: diagnostics.add,
    );
    await expectLater(repo.cached(session), throwsA(isA<AppFailure>()));
    final diagnostic = diagnostics.single;
    expect(diagnostic.source, 'cache');
    expect(diagnostic.exceptionText, contains('FormatException'));
    expect(diagnostic.exceptionText, contains('offset'));
    expect(diagnostic.exceptionText, isNot(contains(cachePassword)));
    expect(diagnostic.exceptionText, isNot(contains(session.token)));
    expect(
      diagnostic.stackTrace.toString(),
      contains('BootstrapRepository.cached'),
    );
    expect(await db.select(db.bootstrapCaches).get(), hasLength(1));
  });

  test('diagnostic sanitizes nested credentials and trace without retaining the raw exception source', () {
    const password = 'NESTED-PASSWORD-MUST-NOT-APPEAR';
    const refreshToken = 'REFRESH-TOKEN-MUST-NOT-APPEAR';
    final payload = {
      'nested': [
        {'password': password, 'refresh_token': refreshToken},
      ],
    };
    final diagnostic = ParsingDiagnostic.capture(
      source: 'api',
      role: 'FUNCIONARIO',
      token: session.token,
      payload: payload,
      error: FormatException(
        'campo invalido: $password e $refreshToken',
        jsonEncode(payload),
        7,
      ),
      stackTrace: StackTrace.fromString(
        '#0 parser ($password:1)\n#1 refresh (Bearer ${session.token})',
      ),
    );
    final logged = '${diagnostic.message}\n${diagnostic.stackTrace}';
    for (final secret in [password, refreshToken, session.token]) {
      expect(logged, isNot(contains(secret)));
    }
    expect(logged, contains('campo invalido'));
    expect(logged, contains('#0 parser'));
    expect(logged, contains('#1 refresh'));
    expect(logged, contains('offset 7'));
  });

  test(
    'logging failure never hides the controlled AppFailure or alters the cache',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var body = clockPayload();
      final repo = BootstrapRepository(
        db,
        fakeApi(FakeAdapter((_) => FakeAdapter.json(body))),
        reportParsingFailure: (_) => throw StateError('Logger unavailable'),
      );
      final valid = await repo.refresh(session);
      body = clockPayload()..remove('escalas');
      await expectLater(repo.refresh(session), throwsA(isA<AppFailure>()));
      expect((await repo.cached(session))!.data.toJson(), valid.data.toJson());
    },
  );
}
