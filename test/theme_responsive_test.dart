import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:ponto_aqui_app/app/app.dart';
import 'package:ponto_aqui_app/app/router/app_router.dart';
import 'package:ponto_aqui_app/app/theme/app_theme.dart';
import 'package:ponto_aqui_app/core/clock/clock_sample.dart';
import 'package:ponto_aqui_app/features/auth/domain/mobile_session.dart';
import 'package:ponto_aqui_app/features/auth/presentation/auth_view_model.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';
import 'package:ponto_aqui_app/features/bootstrap/domain/bootstrap_snapshot.dart';
import 'package:ponto_aqui_app/features/bootstrap/presentation/work_view_model.dart';
import 'package:ponto_aqui_app/features/marcacoes/presentation/work_views.dart';

import 'support.dart';

class _Authenticated extends AuthViewModel {
  @override
  Future<MobileSession?> build() async => session;
}

class _Work extends WorkViewModel {
  _Work(this.snapshot) : super(session.scope);
  final BootstrapSnapshot snapshot;
  @override
  WorkState build() => WorkState(snapshot: snapshot, offline: false);
}

void main() {
  setUpAll(tz.initializeTimeZones);

  test(
    'system is the default and an explicit theme survives provider recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [themePreferencesProvider.overrideWithValue(preferences)],
      );
      expect(first.read(themeModeProvider), ThemeMode.system);
      await first.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      first.dispose();
      final restored = ProviderContainer(
        overrides: [themePreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(restored.dispose);
      expect(restored.read(themeModeProvider), ThemeMode.dark);
      await restored.read(themeModeProvider.notifier).setMode(ThemeMode.system);
      expect(
        preferences.getString(ThemeModeController.preferenceKey),
        'system',
      );
    },
  );

  test('light and dark foregrounds have readable contrast', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final colors = theme.colorScheme;
      for (final pair in [
        (colors.primary, colors.onPrimary),
        (colors.secondary, colors.onSecondary),
        (colors.surface, colors.onSurface),
        (colors.surfaceContainerLow, colors.onSurface),
        (colors.surfaceContainerLow, colors.onSurfaceVariant),
        (colors.primaryContainer, colors.onPrimaryContainer),
        (colors.secondaryContainer, colors.onSecondaryContainer),
        (colors.tertiaryContainer, colors.onTertiaryContainer),
      ]) {
        final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
        final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} $pair',
        );
      }
    }
  });

  testWidgets(
    'the app follows OS changes and lets the user override and restore system mode',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              appBar: null,
              body: Center(child: ThemeSettingsButton()),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [routerProvider.overrideWithValue(router)],
          child: const PontoAquiApp(),
        ),
      );
      await tester.pumpAndSettle();
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(ThemeSettingsButton))).brightness;
      expect(brightness(), Brightness.dark);
      await tester.tap(find.byTooltip('Configurações de aparência'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<ThemeMode> &&
              widget.value == ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      await tester.tap(find.byTooltip('Configurações de aparência'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<ThemeMode> &&
              widget.value == ThemeMode.system,
        ),
      );
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scenario in [
    (size: const Size(320, 640), mode: 'pessoal', dark: false, scale: 1.0),
    (size: const Size(599, 800), mode: 'pessoal', dark: true, scale: 1.0),
    (size: const Size(600, 800), mode: 'pessoal', dark: false, scale: 1.0),
    (size: const Size(1024, 600), mode: 'pessoal', dark: true, scale: 1.0),
    (size: const Size(320, 640), mode: 'pessoal', dark: true, scale: 2.0),
    (size: const Size(1024, 600), mode: 'relogio', dark: true, scale: 1.0),
    (size: const Size(600, 480), mode: 'relogio', dark: false, scale: 2.0),
  ]) {
    testWidgets(
      'responsive ${scenario.mode} ${scenario.size} dark=${scenario.dark} scale=${scenario.scale}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final body = fixture(scenario.mode);
        final now = DateTime.now().toUtc();
        body['server_timestamp'] = now.toIso8601String();
        body['data_referencia'] = ClockSample.civilDate(
          now,
          body['fuso_horario'] as String,
        );
        final snapshot = BootstrapSnapshot(
          MobileSyncDto.fromJson(body),
          ClockSample(offsetMs: 0, receivedAt: now, roundTripMs: 0),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_Authenticated.new),
              workProvider(session.scope).overrideWith(() => _Work(snapshot)),
            ],
            child: MaterialApp(
              theme: scenario.dark ? AppTheme.dark : AppTheme.light,
              home: MediaQuery(
                data: MediaQueryData(
                  size: scenario.size,
                  textScaler: TextScaler.linear(scenario.scale),
                ),
                child: const Scaffold(body: SafeArea(child: HomeView())),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final isTablet = scenario.size.width >= 600;
        final layout = find.byKey(
          ValueKey(isTablet ? 'home-tablet' : 'home-mobile'),
        );
        expect(layout, findsOneWidget);
        if (scenario.mode == 'pessoal') {
          final button = find.widgetWithText(FilledButton, 'Entrada');
          expect(button, findsOneWidget);
          final entry = tester.getRect(button);
          final interval = tester.getRect(
            find.widgetWithText(FilledButton, 'Início de intervalo'),
          );
          if (!isTablet) {
            expect(entry.width, closeTo(scenario.size.width - 32, .01));
            expect(interval.top, greaterThanOrEqualTo(entry.bottom));
          } else if (scenario.size.width >= 1000) {
            expect(interval.left, greaterThanOrEqualTo(entry.right));
            expect(interval.top, closeTo(entry.top, .01));
          }
        } else {
          expect(find.text('Você: Ana Silva'), findsOneWidget);
          expect(find.byType(FilledButton), findsNWidgets(4));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
