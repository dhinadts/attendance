import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IndustrialColors {
  // Primary colors
  static const Color primary = Color(0xFF00288E);
  static const Color primaryContainer = Color(0xFF1E40AF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFA8B8FF);

  // Secondary colors
  static const Color secondary = Color(0xFF006D30);
  static const Color secondaryContainer = Color(0xFF92F5A4);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF007233);

  // Tertiary colors (Error/Alert)
  static const Color tertiary = Color(0xFF700006);
  static const Color tertiaryContainer = Color(0xFF9B000C);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFFFFA398);

  // Surface colors
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceContainer = Color(0xFFE6EEFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainerHigh = Color(0xFFDEE9FC);
  static const Color surfaceContainerHighest = Color(0xFFD9E3F6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD0DBED);
  static const Color surfaceBright = Color(0xFFF8F9FF);
  static const Color surfaceVariant = Color(0xFFE6EEFF);
  static const Color onSurface = Color(0xFF121C2A);
  static const Color onSurfaceVariant = Color(0xFF444653);

  // Background
  static const Color background = Color(0xFFF8F9FF);
  static const Color onBackground = Color(0xFF121C2A);

  // Other colors
  static const Color outline = Color(0xFF757684);
  static const Color outlineVariant = Color(0xFFC4C5D5);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // Inverse colors
  static const Color inverseSurface = Color(0xFF27313F);
  static const Color inverseOnSurface = Color(0xFFEAF1FF);
  static const Color inversePrimary = Color(0xFFB8C4FF);
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
          TargetPlatform.android: _NoPageTransitionsBuilder(),
          TargetPlatform.iOS: _NoPageTransitionsBuilder(),
          TargetPlatform.macOS: _NoPageTransitionsBuilder(),
          TargetPlatform.windows: _NoPageTransitionsBuilder(),
          TargetPlatform.linux: _NoPageTransitionsBuilder(),
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

class _NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
