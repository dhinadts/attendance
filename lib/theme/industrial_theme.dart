import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class IndustrialColors {
  // Primary colors
  static const Color primary = Color(0xFF0A5C36); // Deep forest green - SaaS Primary
  static const Color primaryContainer = Color(0xFFE2F0E7); // Soft sage container
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF063A20);

  // Secondary colors
  static const Color secondary = Color(0xFF0D9488); // Teal accent - SaaS Secondary
  static const Color secondaryContainer = Color(0xFFCCFBF1); // Mint/teal container
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF115E59);

  // Tertiary colors (Alert/Warning/Pending)
  static const Color tertiary = Color(0xFFD97706); // Amber/orange for warnings/pending
  static const Color tertiaryContainer = Color(0xFFFEF3C7);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF92400E);

  // Surface colors
  static const Color surface = Color(0xFFFFFFFF); // Clean white card background
  static const Color surfaceContainer = Color(0xFFF0F4EF); // Sage-gray tinted surface
  static const Color surfaceContainerLow = Color(0xFFF5F8F4);
  static const Color surfaceContainerHigh = Color(0xFFE5EDE3);
  static const Color surfaceContainerHighest = Color(0xFFD9E5D7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFE2ECE0);
  static const Color surfaceBright = Color(0xFFF7F9F6);
  static const Color surfaceVariant = Color(0xFFEFF3EE);
  static const Color onSurface = Color(0xFF122118); // Deep forest green-black text
  static const Color onSurfaceVariant = Color(0xFF43534A); // Slate sage text

  // Background
  static const Color background = Color(0xFFF7F9F6); // Soft eco-cream/off-white background
  static const Color onBackground = Color(0xFF122118);

  // Other colors
  static const Color outline = Color(0xFFD0DCD0); // Clean sage border
  static const Color outlineVariant = Color(0xFFE6EFE6);
  static const Color error = Color(0xFFBE123C); // Rose/Red for errors
  static const Color onError = Color(0xFFFFFFFF);

  // Inverse colors
  static const Color inverseSurface = Color(0xFF22332A);
  static const Color inverseOnSurface = Color(0xFFEAF5EF);
  static const Color inversePrimary = Color(0xFFA2DFBE);
}

class IndustrialTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: IndustrialColors.primary,
        onPrimary: IndustrialColors.onPrimary,
        primaryContainer: IndustrialColors.primaryContainer,
        onPrimaryContainer: IndustrialColors.onPrimaryContainer,
        secondary: IndustrialColors.secondary,
        onSecondary: IndustrialColors.onSecondary,
        secondaryContainer: IndustrialColors.secondaryContainer,
        onSecondaryContainer: IndustrialColors.onSecondaryContainer,
        tertiary: IndustrialColors.tertiary,
        onTertiary: IndustrialColors.onTertiary,
        tertiaryContainer: IndustrialColors.tertiaryContainer,
        onTertiaryContainer: IndustrialColors.onTertiaryContainer,
        error: IndustrialColors.error,
        onError: IndustrialColors.onError,
        surface: IndustrialColors.surface,
        onSurface: IndustrialColors.onSurface,
        outline: IndustrialColors.outline,
        outlineVariant: IndustrialColors.outlineVariant,
      ),
      scaffoldBackgroundColor: IndustrialColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: IndustrialColors.surface,
        foregroundColor: IndustrialColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      textTheme: TextTheme(
        // Headlines
        headlineLarge: GoogleFonts.workSans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: IndustrialColors.onSurface,
          height: 40 / 32,
          letterSpacing: -0.02,
        ),
        headlineMedium: GoogleFonts.workSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: IndustrialColors.onSurface,
          height: 28 / 20,
        ),
        headlineSmall: GoogleFonts.workSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: IndustrialColors.onSurface,
          height: 32 / 24,
        ),
        // Body
        bodyLarge: GoogleFonts.publicSans(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: IndustrialColors.onSurface,
          height: 28 / 18,
        ),
        bodyMedium: GoogleFonts.publicSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: IndustrialColors.onSurface,
          height: 24 / 16,
        ),
        bodySmall: GoogleFonts.publicSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: IndustrialColors.onSurfaceVariant,
          height: 20 / 14,
        ),
        // Labels
        labelLarge: GoogleFonts.atkinsonHyperlegible(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: IndustrialColors.onSurface,
          height: 20 / 14,
          letterSpacing: 0.05,
        ),
      ),
      buttonTheme: const ButtonThemeData(
        height: 48,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: IndustrialColors.outline,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: IndustrialColors.outlineVariant,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: IndustrialColors.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: IndustrialColors.surfaceContainerLowest,
        hintStyle: GoogleFonts.publicSans(
          fontSize: 16,
          color: IndustrialColors.onSurfaceVariant,
        ),
        labelStyle: GoogleFonts.publicSans(
          fontSize: 14,
          color: IndustrialColors.onSurfaceVariant,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: IndustrialColors.primary,
          foregroundColor: IndustrialColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.workSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IndustrialColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: IndustrialColors.outline, width: 1),
          textStyle: GoogleFonts.workSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      cardTheme: CardThemeData(
        color: IndustrialColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: IndustrialColors.outlineVariant,
            width: 1,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: IndustrialColors.secondaryContainer,
        labelStyle: GoogleFonts.atkinsonHyperlegible(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: IndustrialColors.onSecondaryContainer,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        expansionAnimationStyle: AnimationStyle.noAnimation,
      ),
    );
  }
}
