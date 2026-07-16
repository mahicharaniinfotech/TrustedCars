/// KDMC — Typography Tokens
///
/// Three type roles, each with a job:
///   - Sora           -> display: headings, section titles
///   - Inter           -> body: everything you read
///   - IBM Plex Mono    -> data: prices and odometer/km figures specifically
///                          (never used for general body text)
///
/// RULE: screens never call GoogleFonts.* directly. They use AppTypography
/// or, once wired into ThemeData, Theme.of(context).textTheme.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme => TextTheme(
        // Display / headings — Sora
        displayLarge: GoogleFonts.sora(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.sora(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.sora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),

        // Body — Inter
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

  /// Odometer/price treatment — IBM Plex Mono. This is the signature
  /// typographic choice: numbers a buyer scans for (price, KM driven)
  /// get a dashboard-readout feel instead of blending into body text.
  static TextStyle priceLarge = GoogleFonts.ibmPlexMono(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.inkNavy,
    letterSpacing: -0.5,
  );

  static TextStyle priceMedium = GoogleFonts.ibmPlexMono(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.inkNavy,
  );

  static TextStyle specData = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
