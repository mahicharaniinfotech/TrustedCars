import 'package:flutter/material.dart';
import '../../core/theme/app_dimensions.dart';

/// A single tile in the "quick services" grid -- circular gradient icon
/// background + label, matching the icon-tile pattern from services like
/// Insurance/Loans/Check Price. Tiles for features that don't exist yet
/// show an honest "Soon" badge rather than pretending to be functional.
class QuickServiceTile extends StatelessWidget {
  const QuickServiceTile({
    super.key,
    required this.label,
    required this.icon,
    required this.gradientColors,
    this.onTap,
    this.comingSoon = false,
  });

  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: comingSoon ? 0.55 : 1.0,
      child: InkWell(
        onTap: comingSoon ? null : onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  if (comingSoon)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B5563),
                          borderRadius: AppRadius.pillAll,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'Soon',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
