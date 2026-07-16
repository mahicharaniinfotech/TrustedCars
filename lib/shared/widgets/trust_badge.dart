import 'package:flutter/material.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/kdmc_theme_extension.dart';

enum TrustBadgeKind { owner, dealer }

/// The signature trust element — "TrustedCars Verified Owner" / "TrustedCars Verified
/// Dealer". Signal Teal is reserved exclusively for this badge across the
/// entire app, so it always reads as "this is verified" at a glance.
class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key, required this.kind, this.compact = false});

  final TrustBadgeKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.kdmcTokens;
    final label = kind == TrustBadgeKind.owner
        ? 'TrustedCars Verified Owner'
        : 'TrustedCars Verified Dealer';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.sm + 2,
        vertical: compact ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.trustColorBg,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: compact ? 12 : 14, color: tokens.trustColor),
          const SizedBox(width: 4),
          Text(
            compact ? 'Verified' : label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.trustColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
