import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static const fontFamily = 'NotoSansSC';

  static TextTheme textTheme(Brightness brightness) {
    final source = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return source
        .copyWith(
          displayLarge: _weight(source.displayLarge, FontWeight.w400),
          displayMedium: _weight(source.displayMedium, FontWeight.w400),
          displaySmall: _weight(source.displaySmall, FontWeight.w400),
          headlineLarge: _weight(source.headlineLarge, FontWeight.w600),
          headlineMedium: _weight(source.headlineMedium, FontWeight.w600),
          headlineSmall: _weight(source.headlineSmall, FontWeight.w600),
          titleLarge: _weight(source.titleLarge, FontWeight.w600),
          titleMedium: _weight(source.titleMedium, FontWeight.w500),
          titleSmall: _weight(source.titleSmall, FontWeight.w500),
          bodyLarge: _weight(source.bodyLarge, FontWeight.w400),
          bodyMedium: _weight(source.bodyMedium, FontWeight.w400),
          bodySmall: _weight(source.bodySmall, FontWeight.w400),
          labelLarge: _weight(source.labelLarge, FontWeight.w500),
          labelMedium: _weight(source.labelMedium, FontWeight.w500),
          labelSmall: _weight(source.labelSmall, FontWeight.w500),
        )
        .apply(fontFamily: fontFamily);
  }

  static TextStyle? _weight(TextStyle? style, FontWeight weight) {
    return style?.copyWith(fontWeight: weight);
  }
}
