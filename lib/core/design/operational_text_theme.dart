import 'package:flutter/material.dart';

@immutable
class OperationalTextTheme extends ThemeExtension<OperationalTextTheme> {
  const OperationalTextTheme({
    required this.metadata,
    required this.code,
    required this.log,
  });

  final TextStyle metadata;
  final TextStyle code;
  final TextStyle log;

  @override
  OperationalTextTheme copyWith({
    TextStyle? metadata,
    TextStyle? code,
    TextStyle? log,
  }) {
    return OperationalTextTheme(
      metadata: metadata ?? this.metadata,
      code: code ?? this.code,
      log: log ?? this.log,
    );
  }

  @override
  OperationalTextTheme lerp(
    covariant ThemeExtension<OperationalTextTheme>? other,
    double t,
  ) {
    if (other is! OperationalTextTheme) {
      return this;
    }

    return OperationalTextTheme(
      metadata: TextStyle.lerp(metadata, other.metadata, t)!,
      code: TextStyle.lerp(code, other.code, t)!,
      log: TextStyle.lerp(log, other.log, t)!,
    );
  }
}
