import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class Brand {
  static const navy = Color(0xFF0B3158);
  static const teal = Color(0xFF008E89);
  static const background = Color(0xFFF3F7F9);
}

final themePreferencesProvider = Provider<SharedPreferences?>((ref) => null);
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const preferenceKey = 'appearance.theme_mode';
  @override
  ThemeMode build() {
    final saved = ref.watch(themePreferencesProvider)?.getString(preferenceKey);
    return ThemeMode.values.where((mode) => mode.name == saved).firstOrNull ??
        ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      await ref
          .read(themePreferencesProvider)
          ?.setString(preferenceKey, mode.name);
    } catch (_) {
      // A escolha continua ativa nesta sessao se o armazenamento falhar.
    }
  }
}

class ThemeSettingsButton extends ConsumerWidget {
  const ThemeSettingsButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Configurações de aparência',
      icon: const Icon(Icons.contrast),
      initialValue: selected,
      onSelected: (mode) =>
          unawaited(ref.read(themeModeProvider.notifier).setMode(mode)),
      itemBuilder: (_) => [
        for (final mode in ThemeMode.values)
          CheckedPopupMenuItem(
            value: mode,
            checked: mode == selected,
            child: Text(switch (mode) {
              ThemeMode.system => 'Usar tema do sistema',
              ThemeMode.light => 'Tema claro',
              ThemeMode.dark => 'Tema escuro',
            }),
          ),
      ],
    );
  }
}

abstract final class AppTheme {
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: Brand.navy,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFA7CBF2) : Brand.navy,
          onPrimary: isDark ? const Color(0xFF073058) : Colors.white,
          secondary: isDark ? const Color(0xFF67D5CA) : const Color(0xFF006B67),
          onSecondary: isDark ? const Color(0xFF003733) : Colors.white,
          surface: isDark ? const Color(0xFF101821) : Colors.white,
          onSurface: isDark ? const Color(0xFFE5EDF5) : const Color(0xFF18334B),
        );
    final background = isDark ? const Color(0xFF0C141D) : Brand.background;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarThemeData(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 54),
          shape: shape,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.secondaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.secondaryContainer,
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
    );
  }
}
