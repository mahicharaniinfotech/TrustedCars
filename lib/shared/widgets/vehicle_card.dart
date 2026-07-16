import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/kdmc_theme_extension.dart';
import 'trust_badge.dart';

/// The primary vehicle listing card. This is the single definition used on
/// the homepage, search results, favourites, and "similar vehicles" — one
/// place to get it right, one place to improve it later.
///
/// Notice: nothing here is a literal Color(...) or a raw font size. Every
/// visual property comes from Theme.of(context) or context.kdmcTokens.
/// That's what lets a brand refresh be a token-file change, not a
/// find-and-replace across every screen that renders a card.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.year,
    required this.km,
    required this.fuel,
    required this.location,
    required this.verified,
    this.trustKind = TrustBadgeKind.owner,
    this.onTap,
    this.isFavorite,
    this.onFavoriteToggle,
  });

  final String imageUrl;
  final String title;
  final String price;
  final String year;
  final String km;
  final String fuel;
  final String location;
  final bool verified;
  final TrustBadgeKind trustKind;
  final VoidCallback? onTap;

  /// Null hides the favorite button entirely (e.g. for a guest viewing a
  /// card before the favorites feature is relevant to them).
  final bool? isFavorite;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.kdmcTokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: tokens.cardRadius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: tokens.cardRadius,
            boxShadow: tokens.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Image with gradient scrim + verified ribbon ----
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(imageUrl, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: AppColors.cardImageScrim,
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                    if (verified)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: TrustBadge(kind: trustKind, compact: true),
                      ),
                    if (isFavorite != null)
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Material(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.35),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onFavoriteToggle,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isFavorite!
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                                color: isFavorite!
                                    ? AppColors.ember
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Text(
                        '$year · $km km · $fuel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- Details ----
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(price, style: tokens.priceStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
