import 'package:flutter/material.dart';
import '../../../core/theme/app_dimensions.dart';

/// A single "Browse by" category pill on the home screen (Cars / Bikes /
/// Commercial / Coming Soon). Kept as its own widget for the same reason
/// as VehicleCard -- one definition, used wherever category selection
/// shows up (home screen now, search filters later).
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foreground = !enabled
        ? theme.colorScheme.outline
        : isSelected
            ? Colors.white
            : theme.colorScheme.primary;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
