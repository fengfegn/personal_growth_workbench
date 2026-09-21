import 'package:flutter/material.dart';

import 'app_typography.dart';

enum ThemePalette {
  yuan1('壹元·青禾', Color(0xFF5C7A59), Color(0xFFF5F7F3)),
  yuan5('伍元·黛紫', Color(0xFF72527F), Color(0xFFF8F4F8)),
  yuan10('拾元·澄蓝', Color(0xFF386A84), Color(0xFFF2F7F9)),
  yuan20('贰拾·茶棕', Color(0xFF966142), Color(0xFFFAF5F1)),
  yuan50('伍拾·翡翠', Color(0xFF246B57), Color(0xFFF0F7F4)),
  yuan100('壹佰·朱砂', Color(0xFFA33C54), Color(0xFFFAF2F4));

  const ThemePalette(this.label, this.primary, this.lightBackground);

  final String label;
  final Color primary;
  final Color lightBackground;
}

enum DisplayMode {
  system('跟随系统', ThemeMode.system),
  light('浅色', ThemeMode.light),
  dark('深色', ThemeMode.dark);

  const DisplayMode(this.label, this.themeMode);

  final String label;
  final ThemeMode themeMode;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light(ThemePalette palette) {
    return _build(palette, Brightness.light);
  }

  static ThemeData dark(ThemePalette palette) {
    return _build(palette, Brightness.dark);
  }

  static ThemeData _build(ThemePalette palette, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    final textTheme = AppTypography.textTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: isLight
          ? palette.lightBackground
          : const Color(0xFF151816),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : const Color(0xFF202522),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF1A1E1B),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
