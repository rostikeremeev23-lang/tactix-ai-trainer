import 'package:flutter/material.dart';

class TactixTheme {
  TactixTheme._();

  static const Color gold = Color(0xFFE0B64A);
  static const Color cyan = Color(0xFF32B9E8);

  static const Color bg = Color(0xFF060B10);
  static const Color panel = Color(0xFF0D151D);
  static const Color panel2 = Color(0xFF111C25);
  static const Color line = Color(0xFF233746);
  static const Color textMuted = Color(0xFF8FA4B5);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
    ).copyWith(
      primary: gold,
      secondary: cyan,
      surface: panel,
      outline: line,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      fontFamily: 'Arial',
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          side: BorderSide(
            color: line,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: line,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: line,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: gold,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

