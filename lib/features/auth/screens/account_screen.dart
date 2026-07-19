import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../models/account.dart';
import '../providers/auth_providers.dart';

/// Account/Settings screen -- profile summary, sign out, and self-service
/// account deletion. Reached from a new "Account" icon on the home screen
/// (replacing the old direct Sign Out icon, which now lives here instead,
/// matching the reference app's dedicated Account section).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountProvider).value;
    final theme = Theme.of(context);

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.fullName ?? 'No name set', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                if (account.phone != null)
                  _InfoRow(icon: Icons.phone_outlined, label: account.phone!),
                if (account.email != null)
                  _InfoRow(icon: Icons.email_outlined, label: account.email!),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: account.accountType == AccountType.dealer
                      ? 'Dealer account'
                      : 'Individual account',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton.secondary(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/dashboard');
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Divider(color: theme.colorScheme.outline),
          const SizedBox(height: AppSpacing.md),
          Text('Danger zone', style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
              )),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Deleting your account permanently removes your profile and '
            'listings. This cannot be undone.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, listings, and messages. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !context.mounted) return;

    // Second, explicit confirmation -- irreversible destructive action.
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text('Type nothing needed -- just confirm one more time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !context.mounted) return;

    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      if (context.mounted) context.go('/dashboard');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: $e')),
        );
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
