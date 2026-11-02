import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'app/app_runtime.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try {
    final runtime = await AppRuntime.open();
    runApp(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const PontoAquiApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        theme: AppTheme.light,
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
      ),
    );
  }
}
