import 'package:flutter/material.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/kdmc_theme_extension.dart';
import '../models/account.dart';

/// The one branch point in onboarding: Individual (buyer, and can become a
/// verified seller later) or Dealer (business account). Used on the
/// Complete Profile screen right after first phone-OTP login.
class RoleToggle extends StatelessWidget {
  const RoleToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleOption(
            label: 'Buyer / Individual Seller',
            icon: Icons.person_outline,
            isSelected: selected == AccountType.individual,
            onTap: () => onChanged(AccountType.individual),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _RoleOption(
            label: 'Dealer',
            icon: Icons.storefront_outlined,
            isSelected: selected == AccountType.dealer,
            onTap: () => onChanged(AccountType.dealer),
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.kdmcTokens;

    return InkWell(
      onTap: onTap,
      borderRadius: tokens.cardRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: isSelected
              // ignore: deprecated_member_use
              ? theme.colorScheme.primary.withOpacity(0.06)
              : theme.colorScheme.surface,
          borderRadius: tokens.cardRadius,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodySmall?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
