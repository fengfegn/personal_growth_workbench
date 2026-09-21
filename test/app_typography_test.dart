import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/app/theme/app_theme.dart';
import 'package:personal_growth_workbench/app/theme/app_typography.dart';

void main() {
  test('uses the bundled Noto Sans SC family and approved weights', () {
    final theme = AppTheme.light(ThemePalette.yuan1);
    final styles = [
      theme.textTheme.bodyMedium,
      theme.textTheme.titleMedium,
      theme.textTheme.titleLarge,
      theme.textTheme.headlineMedium,
    ];

    expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.fontFamily);
    expect(styles.every((style) => style?.fontFamily == 'NotoSansSC'), isTrue);
    expect(
      styles.map((style) => style?.fontWeight),
      containsAll(<FontWeight>[
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
      ]),
    );
  });
}
