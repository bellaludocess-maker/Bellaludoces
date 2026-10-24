import 'package:flutter/material.dart';
import 'bella_colors.dart';

/// Design System e ThemeData oficial da Bella Lu Doces.
class BellaTheme {
  BellaTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BellaColors.pinkPrimary,
      primary: BellaColors.pinkPrimary,
      onPrimary: Colors.white,
      secondary: BellaColors.darkChocolate,
      onSecondary: Colors.white,
      surface: BellaColors.cardSurface,
      onSurface: BellaColors.darkChocolate,
      error: BellaColors.errorRed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BellaColors.creamBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: BellaColors.creamBackground,
        foregroundColor: BellaColors.darkChocolate,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: BellaColors.darkChocolate,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: BellaColors.darkChocolate,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          color: BellaColors.darkChocolate,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: BellaColors.darkChocolate,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: BellaColors.darkChocolate,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: BellaColors.darkChocolate,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: BellaColors.mediumBrown,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: BellaColors.darkChocolate,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: BellaColors.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: BellaColors.pinkBorder,
            width: 1.2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BellaColors.pinkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BellaColors.pinkPrimary,
          side: const BorderSide(color: BellaColors.pinkPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: BellaColors.softCocoa, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BellaColors.pinkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BellaColors.pinkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: BellaColors.pinkPrimary,
            width: 2,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BellaColors.pinkSoft,
        selectedColor: BellaColors.pinkPrimary,
        labelStyle: const TextStyle(
          color: BellaColors.darkChocolate,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: BellaColors.pinkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BellaColors.pinkBorder,
        thickness: 1,
      ),
    );
  }
}
