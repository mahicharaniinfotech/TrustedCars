/// KDMC — Semantic Theme Extension
///
/// Flutter's built-in ThemeData has no slot for concepts like "trust color"
/// or "price text style" — this extension adds them, so widgets can do:
///
///   final tokens = context.kdmcTokens;
///   Text(price, style: tokens.priceStyle)
///   Icon(Icons.verified, color: tokens.trustColor)
///
/// instead of reaching for AppColors directly. Screens should prefer this
/// extension over AppColors/AppTypography where a semantic token exists —
/// it reads as "what this means" rather than "what color this happens to be".
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

@immutable
class KdmcTokens extends ThemeExtension<KdmcTokens> {
  const KdmcTokens({
    required this.trustColor,
    required this.trustColorBg,
    required this.priceStyle,
    required this.priceStyleLarge,
    required this.specDataStyle,
    required this.cardShadow,
    required this.cardRadius,
    required this.ctaColor,
  });

  final Color trustColor;
  final Color trustColorBg;
  final TextStyle priceStyle;
  final TextStyle priceStyleLarge;
  final TextStyle specDataStyle;
  final List<BoxShadow> cardShadow;
  final BorderRadius cardRadius;
  final Color ctaColor;

  static final KdmcTokens light = KdmcTokens(
    trustColor: AppColors.signalTeal,
    trustColorBg: AppColors.signalTealLight,
    priceStyle: AppTypography.priceMedium,
    priceStyleLarge: AppTypography.priceLarge,
    specDataStyle: AppTypography.specData,
    cardShadow: AppShadows.card,
    cardRadius: AppRadius.mdAll,
    ctaColor: AppColors.ember,
  );

  @override
  KdmcTokens copyWith({
    Color? trustColor,
    Color? trustColorBg,
    TextStyle? priceStyle,
    TextStyle? priceStyleLarge,
    TextStyle? specDataStyle,
    List<BoxShadow>? cardShadow,
    BorderRadius? cardRadius,
    Color? ctaColor,
  }) {
    return KdmcTokens(
      trustColor: trustColor ?? this.trustColor,
      trustColorBg: trustColorBg ?? this.trustColorBg,
      priceStyle: priceStyle ?? this.priceStyle,
      priceStyleLarge: priceStyleLarge ?? this.priceStyleLarge,
      specDataStyle: specDataStyle ?? this.specDataStyle,
      cardShadow: cardShadow ?? this.cardShadow,
      cardRadius: cardRadius ?? this.cardRadius,
      ctaColor: ctaColor ?? this.ctaColor,
    );
  }

  @override
  KdmcTokens lerp(ThemeExtension<KdmcTokens>? other, double t) {
    if (other is! KdmcTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor: `context.kdmcTokens.trustColor`
extension KdmcThemeContext on BuildContext {
  KdmcTokens get kdmcTokens => Theme.of(this).extension<KdmcTokens>()!;
}
