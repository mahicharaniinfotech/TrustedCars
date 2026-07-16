/// TrustedCars — App Theme
///
/// THE single source of truth for how the app looks.
///
/// Every screen and widget in TrustedCars gets its styling from here — via
/// `Theme.of(context)` for standard Material properties (colors, text
/// styles, button styles, input decoration, app bar, bottom nav) and via
/// `context.trustedCarsTokens` for TrustedCars-specific concepts (trust color, price
/// style, card shadow).
///
/// To restyle the entire app — change the brand color, swap a font, adjust
/// corner radius everywhere — you edit the token files (app_colors.dart /
/// app_typography.dart / app_dimensions.dart) and this file. You never
/// hunt through individual screens. That is the whole point of this file
/// existing.
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';
import 'kdmc_theme_extension.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: textTheme.bodyMedium?.fontFamily,

      colorScheme: const ColorScheme.light(
        primary: AppColors.inkNavy,
        onPrimary: AppColors.textOnDark,
        secondary: AppColors.ember,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.errorRed,
        onError: Colors.white,
        outline: AppColors.border,
      ),

      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ember,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkNavy,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.inkNavy,
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.inkNavy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.inkNavy,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: textTheme.bodySmall,
        unselectedLabelStyle: textTheme.bodySmall,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSunken,
        labelStyle: textTheme.bodySmall,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        side: BorderSide.none,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // TrustedCars semantic tokens ride alongside the standard theme.
      extensions: [KdmcTokens.light],
    );
  }
}
