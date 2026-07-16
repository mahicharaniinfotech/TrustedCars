/// KDMC — Spacing, Radius & Shadow Tokens
///
/// Same rule as colors/typography: no magic numbers for padding, margin,
/// or corner radius anywhere else in the app. Reference AppSpacing /
/// AppRadius / AppShadows instead. This is what makes the UI feel
/// consistent (Spinny-like) rather than every screen inventing its own
/// spacing (Cars24-like).
library;

import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

abstract final class AppShadows {
  /// Soft, low-elevation shadow used on cards — this single definition is
  /// what gives every card in the app the same "lift" instead of each
  /// screen picking its own blur/opacity.
  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF14213D).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get raised => [
    BoxShadow(
      color: const Color(0xFF14213D).withValues(alpha: 0.10),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];
}
