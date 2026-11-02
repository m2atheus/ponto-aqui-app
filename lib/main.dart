import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/router/app_router.dart';
import 'app/app_runtime.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // O tema do sistema funciona mesmo sem preferencias persistidas.
  }
  try {
    final runtime = await AppRuntime.open();
    runApp(
      ProviderScope(
        overrides: [
          runtimeProvider.overrideWithValue(runtime),
          themePreferencesProvider.overrideWithValue(preferences),
        ],
        child: const PontoAquiApp(),
      ),
    );
  } catch (_) {
    runApp(
      ProviderScope(
        overrides: [themePreferencesProvider.overrideWithValue(preferences)],
        child: const _StartupFailureApp(),
      ),
    );
  }
}

class PontoAquiApp extends ConsumerWidget {
  const PontoAquiApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Ponto Aqui',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(routerProvider),
  );
}

class _StartupFailureApp extends ConsumerWidget {
  const _StartupFailureApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    home: const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_outlined, size: 56),
                SizedBox(height: 20),
                Text(
                  'Não foi possível iniciar o Ponto Aqui',
                  style: TextStyle(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Verifique a configuração da API e a disponibilidade do armazenamento seguro. Solicite uma versão configurada ao responsável pelo aplicativo.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
