// ignore_for_file: unnecessary_underscores, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_dimensions.dart';
import '../auth/models/account.dart';
import '../marketplace/models/vehicle.dart';
import 'admin_providers.dart';

/// Sprint 8 -- the Admin Portal. Reachable only by account_type='admin'
/// (gated in the router, see app_router.dart), and relies on the admin
/// RLS bypass policies from migration 011 to see other users' data at all.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Portal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Verification'),
              Tab(text: 'Listings'),
              Tab(text: 'Overview'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_VerificationTab(), _ListingsTab(), _OverviewTab()],
        ),
      ),
    );
  }
}

// ============================================================================
// VERIFICATION
// ============================================================================
class _VerificationTab extends ConsumerWidget {
  const _VerificationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingVerificationsProvider);
    final theme = Theme.of(context);

    return pendingAsync.when(
      data: (accounts) => accounts.isEmpty
          ? Center(
              child: Text(
                'No accounts pending review',
                style: theme.textTheme.bodyMedium,
              ),
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(pendingVerificationsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: accounts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) =>
                    _VerificationTile(account: accounts[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load accounts: $e')),
    );
  }
}

class _VerificationTile extends ConsumerWidget {
  const _VerificationTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(
              account.isDealer
                  ? Icons.storefront_outlined
                  : Icons.person_outline,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.fullName?.isNotEmpty == true
                      ? account.fullName!
                      : 'No name set',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '${account.accountType.name} · ${account.verificationStatus.name} · ${account.phone ?? "no phone"}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.close, color: Colors.redAccent),
            onPressed: () async {
              await ref
                  .read(adminRepositoryProvider)
                  .setVerificationStatus(
                    account.id,
                    VerificationStatus.rejected,
                  );
              ref.invalidate(pendingVerificationsProvider);
            },
          ),
          IconButton(
            tooltip: 'Verify',
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            onPressed: () async {
              await ref
                  .read(adminRepositoryProvider)
                  .setVerificationStatus(
                    account.id,
                    VerificationStatus.verified,
                  );
              ref.invalidate(pendingVerificationsProvider);
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LISTINGS (MODERATION)
// ============================================================================
class _ListingsTab extends ConsumerWidget {
  const _ListingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(allListingsProvider);
    final theme = Theme.of(context);

    return listingsAsync.when(
      data: (vehicles) => vehicles.isEmpty
          ? Center(
              child: Text('No listings yet', style: theme.textTheme.bodyMedium),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(allListingsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: vehicles.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) =>
                    _ModerationTile(vehicle: vehicles[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load listings: $e')),
    );
  }
}

class _ModerationTile extends ConsumerWidget {
  const _ModerationTile({required this.vehicle});

  final Vehicle vehicle;

  Future<void> _showRemoveDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Reason (shown in audit log)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      await ref.read(adminRepositoryProvider).removeListing(vehicle.id, reason);
      ref.invalidate(allListingsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRemoved = vehicle.status == VehicleStatus.removed;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Image.network(
                vehicle.primaryImageUrl ??
                    'https://images.unsplash.com/photo-1552519507-da3b142c6e3d',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.title,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${vehicle.status.name} · ${vehicle.formattedPrice}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (isRemoved)
            TextButton(
              onPressed: () async {
                await ref
                    .read(adminRepositoryProvider)
                    .restoreListing(vehicle.id);
                ref.invalidate(allListingsProvider);
              },
              child: const Text('Restore'),
            )
          else
            IconButton(
              tooltip: 'Remove listing',
              icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              onPressed: () => _showRemoveDialog(context, ref),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// OVERVIEW
// ============================================================================
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final items = [
          ('Total Users', '${stats.totalUsers}', Icons.people_outline),
          ('Dealers', '${stats.totalDealers}', Icons.storefront_outlined),
          (
            'Published Listings',
            '${stats.totalListings}',
            Icons.directions_car_outlined,
          ),
          (
            'Pending Verification',
            '${stats.pendingVerifications}',
            Icons.hourglass_empty,
          ),
        ];
        return GridView.count(
          padding: const EdgeInsets.all(AppSpacing.md),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.4,
          children: items.map((item) {
            final (label, value, icon) = item;
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: Theme.of(context).textTheme.displayMedium),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load stats: $e')),
    );
  }
}
