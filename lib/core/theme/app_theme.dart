import 'package:flutter/material.dart';

class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.statusGood,
    required this.statusWarning,
    required this.statusCritical,
  });

  static const AppStatusColors dark = AppStatusColors(
    statusGood: Color(0xFF22C55E),
    statusWarning: Color(0xFFF59E0B),
    statusCritical: Color(0xFFEF4444),
  );

  static const AppStatusColors light = AppStatusColors(
    statusGood: Color(0xFF16A34A),
    statusWarning: Color(0xFFD97706),
    statusCritical: Color(0xFFDC2626),
  );

  final Color statusGood;
  final Color statusWarning;
  final Color statusCritical;

  @override
  AppStatusColors copyWith({
    Color? statusGood,
    Color? statusWarning,
    Color? statusCritical,
  }) {
    return AppStatusColors(
      statusGood: statusGood ?? this.statusGood,
      statusWarning: statusWarning ?? this.statusWarning,
      statusCritical: statusCritical ?? this.statusCritical,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) {
      return this;
    }

    return AppStatusColors(
      statusGood: Color.lerp(statusGood, other.statusGood, t) ?? statusGood,
      statusWarning:
          Color.lerp(statusWarning, other.statusWarning, t) ?? statusWarning,
      statusCritical:
          Color.lerp(statusCritical, other.statusCritical, t) ??
          statusCritical,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFF0B1220);
  static const Color surface = Color(0xFF121A2B);
  static const Color primary = Color(0xFF3B82F6);
  static const Color text = Color(0xFFE8EDF5);

  static const Color lightBackground = Color(0xFFF3F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF0B1220);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: lightSurface,
        onSurface: lightText,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
        bodySmall: TextStyle(color: Color(0xFF3D4A5C)),
        titleLarge: TextStyle(color: lightText),
      ),
      extensions: const [AppStatusColors.light],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: Color(0xFFC5CEDB)),
        titleLarge: TextStyle(color: Colors.white),
      ),
      extensions: const [AppStatusColors.dark],
    );
  }
}
