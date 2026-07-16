/// TrustedCars — Raw Color Tokens
///
/// RULE: This is the ONLY file in the entire app allowed to contain literal
/// hex color values. Every other file — screens, widgets, other theme files —
/// must reference colors through [AppColors] or through the theme
/// (Theme.of(context) / context.trustedCarsTokens). If you catch yourself typing
/// `Color(0xFF...)` anywhere outside this file, stop and add a token here
/// instead. That discipline is what makes a brand refresh a one-file change.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ---- Brand -----------------------------------------------------------
  /// Primary brand color. Confident navy — headers, primary buttons, nav bar.
  static const Color inkNavy = Color(0xFF14213D);
  static const Color inkNavyLight = Color(0xFF24345A);
  static const Color inkNavyDark = Color(0xFF0B1428);

  /// Accent — used ONLY for calls-to-action and price emphasis.
  /// Do not reuse for decoration; it needs to stay meaningful.
  static const Color ember = Color(0xFFFF6A3D);
  static const Color emberLight = Color(0xFFFF8A63);
  static const Color emberDark = Color(0xFFE04F22);

  /// Trust / verification — used ONLY for the "TrustedCars Verified" badge family.
  static const Color signalTeal = Color(0xFF0FA37F);
  static const Color signalTealLight = Color(0xFFE3F7F1);

  /// Alerts / subscription nudges.
  static const Color amberWarning = Color(0xFFE0B419);
  static const Color errorRed = Color(0xFFD64545);

  // ---- Neutrals ----------------------------------------------------------
  static const Color background = Color(0xFFFAFAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSunken = Color(0xFFF2F2EF);
  static const Color border = Color(0xFFE4E4E0);
  static const Color divider = Color(0xFFECECE8);

  static const Color textPrimary = Color(0xFF14213D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFF5F5F3);

  // ---- Gradients -----------------------------------------------------
  /// Bottom scrim on vehicle card images, so specs stay legible over photos.
  static const List<Color> cardImageScrim = [
    Color(0x00000000),
    Color(0xB3000000),
  ];

  /// Promotional action-card gradients (home screen Buy/Sell tiles, quick
  /// service icons). Built from our own brand colors, not decoration for
  /// its own sake -- "buy" uses the primary navy, "sell" uses the ember
  /// accent (since selling is the call-to-action we most want to drive).
  /// Signal Teal is deliberately excluded here -- it stays reserved
  /// exclusively for verification, per the trust-badge design rule.
  static const List<Color> buyGradient = [Color(0xFF14213D), Color(0xFF2C4270)];
  static const List<Color> sellGradient = [Color(0xFFFF6A3D), Color(0xFFE04F22)];

  /// A third decorative gradient for quick-service tiles that aren't
  /// specifically "buy" or "sell" actions -- kept visually distinct from
  /// Signal Teal so trust badges remain the only teal element on screen.
  static const List<Color> accentGradient = [Color(0xFF6B5CE0), Color(0xFF4C3FB8)];
}
