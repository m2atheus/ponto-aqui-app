import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:ponto_aqui_app/core/device/evidence_sensors.dart';

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

class WidgetSensors implements EvidenceSensors {
  WidgetSensors({required this.outside});
  final bool outside;
  int photoCalls = 0;
  @override
  Future<PositionEvidence> location({required bool ignored}) async =>
      PositionEvidence({
        'latitude': outside ? -8.01 : -8.0,
        'longitude': -35.0,
        'precisao_metros': 5.0,
      }, 'capturada');
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
  for (final outside in [false, true]) {
    testWidgets(
      'personal flow ${outside ? 'outside with required selfie' : 'inside without selfie'} persists before transport',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final captureSensors = WidgetSensors(outside: outside);
        final photoDirectory = Directory.systemTemp.createTempSync(
          'pontoaqui-widget-',
        );
        addTearDown(() => photoDirectory.deleteSync(recursive: true));
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
          photos: photoDirectory,
          sensors: captureSensors,
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
        await tester.ensureVisible(find.text('Entrada'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entrada'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Confirmar entrada'), 160);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar entrada'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (outside) {
          expect(find.text('Selfie necessária'), findsOneWidget);
          expect(
            find.textContaining('Você está fora dos locais vinculados'),
            findsOneWidget,
          );
          expect(captureSensors.photoCalls, 0);
          await tester.runAsync(() async {
            expect(await runtime.outbox.list(session.scope), isEmpty);
          });
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(find.text('Selfie necessária'), findsNothing);
          await tester.runAsync(() async {
            expect(await runtime.outbox.list(session.scope), isEmpty);
          });
          await tester.ensureVisible(find.text('Confirmar entrada'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirmar entrada'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Tirar selfie'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }
        // A foto passa por varias operacoes reais de arquivo. Liberar IO e
        // microtasks do widget entre cada etapa, sem esperar o spinner assentar.
        for (
          var attempt = 0;
          attempt < 100 &&
              container.read(workProvider(session.scope)).capturing;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(container.read(workProvider(session.scope)).capturing, isFalse);
        await tester.runAsync(() async {
          expect(await runtime.outbox.list(session.scope), hasLength(1));
        });
        await tester.pumpAndSettle();
        expect(find.text('Fila de sincronização'), findsOneWidget);
        expect(find.text('Salvo no aparelho'), findsOneWidget);
        expect(captureSensors.photoCalls, outside ? 1 : 0);
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
  }
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
      await tester.ensureVisible(find.text('Entrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
