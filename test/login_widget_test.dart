import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponto_aqui_app/app/app.dart';
import 'package:ponto_aqui_app/app/app_runtime.dart';
import 'package:ponto_aqui_app/core/config/app_config.dart';
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/core/clock/clock_sample.dart';
import 'package:ponto_aqui_app/features/bootstrap/presentation/work_view_model.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets(
    'personal flow confirms local persistence and shows pending transport',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final signals = FakeConnections();
      addTearDown(signals.controller.close);
      final body = fixture();
      final now = DateTime.now().toUtc();
      body['server_timestamp'] = now.toIso8601String();
      body['data_referencia'] = ClockSample.civilDate(
        now,
        body['fuso_horario'] as String,
      );
      for (final sector in [body['setor'], body['alocacoes'][0]['setor']]) {
        sector['politicas']['ignorar_localizacao'] = true;
      }
      final adapter = FakeAdapter((request) {
        if (request.path.endsWith('/me')) {
          return FakeAdapter.json({'usuario': profile()});
        }
        if (request.path.endsWith('/sync')) return FakeAdapter.json(body);
        return FakeAdapter.json({
          'erro': {'mensagem': 'Tente novamente'},
        }, 503);
      });
      final runtime = AppRuntime(
        config: AppConfig(session.origin),
        db: db,
        api: fakeApi(adapter),
        storage: MemorySessionStorage(session),
        photos: Directory.systemTemp,
        installationUuid: session.deviceUuid,
        connections: signals,
      );
      final container = ProviderContainer(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
      );
      var disposed = false;
      addTearDown(() {
        if (!disposed) {
          container.dispose();
        }
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PontoAquiApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (
          var attempt = 0;
          attempt < 100 &&
              container.read(workProvider(session.scope)).snapshot == null;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Olá, Ana'), findsOneWidget);
      await tester.ensureVisible(find.text('Registrar ponto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar ponto'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Confirmar entrada'), 160);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar entrada'));
      await tester.runAsync(() async {
        for (
          var attempt = 0;
          attempt < 100 && (await runtime.outbox.list(session.scope)).isEmpty;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Fila de sincronização'), findsOneWidget);
      expect(find.text('Salvo no aparelho'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        container.dispose();
        disposed = true;
        await db.close();
      });
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets(
    'restoration routes to Portuguese login and exposes actual provisioning requirement',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final runtime = AppRuntime(
        config: AppConfig(session.origin),
        db: db,
        api: fakeApi(
          FakeAdapter((_) => throw StateError('no automatic login')),
        ),
        storage: MemorySessionStorage(),
        photos: Directory.systemTemp,
        installationUuid: session.deviceUuid,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [runtimeProvider.overrideWithValue(runtime)],
          child: const PontoAquiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sua jornada começa aqui.'), findsOneWidget);
      expect(find.text('ID cadastrado do aparelho'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
