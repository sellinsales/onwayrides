import 'package:flutter/material.dart';

class OnWayTheme {
  static const Color yellow = Color(0xFFFFC107);
  static const Color black = Color(0xFF111111);
  static const Color white = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF1B1B1B);
  static const Color slate = Color(0xFF2B2B2B);
  static const Color fog = Color(0xFFF5F5F5);

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: yellow,
      brightness: Brightness.dark,
    ).copyWith(
      primary: yellow,
      secondary: yellow,
      surface: charcoal,
      onSurface: white,
      onPrimary: black,
      outline: Colors.white24,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: black,
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: charcoal,
        indicatorColor: Color(0xFFFFC107),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: white,
          fontSize: 42,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
        displayMedium: TextStyle(
          color: white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
        headlineMedium: TextStyle(
          color: white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: white,
          fontSize: 15,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: Colors.white60,
          fontSize: 12,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          color: black,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: slate,
        selectedColor: yellow,
        disabledColor: Colors.white10,
        side: BorderSide.none,
        labelStyle: const TextStyle(color: white, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(
          color: black,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      cardTheme: CardThemeData(
        color: charcoal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: slate,
        hintStyle: const TextStyle(color: Colors.white54),
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIconColor: yellow,
        suffixIconColor: Colors.white70,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: yellow, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: black,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          minimumSize: const Size(0, 54),
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: Colors.white12,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: slate,
        contentTextStyle: const TextStyle(color: white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
