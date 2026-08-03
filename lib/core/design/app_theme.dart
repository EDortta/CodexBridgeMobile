import 'package:flutter/material.dart';

import 'operational_text_theme.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: const Color(0xff006c4c),
      brightness: brightness,
    );
    final TextTheme text = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
      ),
      extensions: <ThemeExtension<OperationalTextTheme>>[
        OperationalTextTheme(
          metadata: text.labelMedium!.copyWith(color: colors.onSurfaceVariant),
          code: text.bodyMedium!.copyWith(
            color: colors.onSurface,
            fontFamily: 'monospace',
          ),
          log: text.bodySmall!.copyWith(
            color: colors.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
