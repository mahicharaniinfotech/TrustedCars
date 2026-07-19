// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/kdmc_theme_extension.dart';
import '../../../shared/widgets/app_button.dart';
import '../auth/providers/auth_providers.dart';
import '../chat/providers/chat_providers.dart';
import '../marketplace/models/vehicle.dart';
import 'dealer_profile.dart';
import 'dealer_providers.dart';
import 'dealer_profile_setup_screen.dart';

/// The Dealer Dashboard -- Sprint 7. Gated by two things: a dealer_profiles
/// row existing (business details submitted at all), AND the account
/// being verified (admin has approved those business details via the
/// existing Admin Portal review). Either gap shows the setup/status
/// screen instead -- it internally branches on pending/rejected/no
/// submission yet.
class DealerDashboardScreen extends ConsumerWidget {
  const DealerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(dealerProfileProvider);
    final account = ref.watch(currentAccountProvider).value;

    return profileAsync.when(
      data: (profile) {
        final needsSetupOrReview = profile == null || !(account?.isVerified ?? false);
        return needsSetupOrReview
            ? const DealerProfileSetupScreen()
            : _DealerDashboardContent(profile: profile);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Could not load dealer profile: $e')),
      ),
    );
  }
}

class _DealerDashboardContent extends StatelessWidget {
  const _DealerDashboardContent({required this.profile});

  final DealerProfile profile;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(profile.businessName, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Inventory'),
              Tab(text: 'Leads'),
              Tab(text: 'Analytics'),
              Tab(text: 'Subscription'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _InventoryTab(),
            _LeadsTab(),
            _AnalyticsTab(),
            _SubscriptionTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/sell'),
          icon: const Icon(Icons.add),
          label: const Text('Add Vehicle'),
        ),
      ),
    );
  }
}

// ============================================================================
// INVENTORY
// ============================================================================
class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(dealerInventoryProvider);
    final theme = Theme.of(context);

    return inventoryAsync.when(
      data: (vehicles) => vehicles.isEmpty
          ? Center(
              child: Text(
                'No vehicles listed yet',
                style: theme.textTheme.bodyMedium,
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(dealerInventoryProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: vehicles.length,
                // ignore: duplicate_ignore
                // ignore: unnecessary_underscores
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) =>
                    _InventoryTile(vehicle: vehicles[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load inventory: $e')),
    );
  }
}

class _InventoryTile extends ConsumerWidget {
  const _InventoryTile({required this.vehicle});

  final Vehicle vehicle;

  Color _statusColor(BuildContext context, VehicleStatus status) {
    final tokens = context.kdmcTokens;
    return switch (status) {
      VehicleStatus.published => tokens.trustColor,
      VehicleStatus.sold => Theme.of(context).colorScheme.outline,
      VehicleStatus.draft => const Color(0xFFE0B419),
      VehicleStatus.removed => Theme.of(context).colorScheme.error,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: SizedBox(
              width: 72,
              height: 72,
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusColor(context, vehicle.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.status.name[0].toUpperCase() +
                          vehicle.status.name.substring(1),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${vehicle.viewsCount}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(vehicle.formattedPrice, style: theme.textTheme.labelLarge),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final repo = ref.read(dealerRepositoryProvider);
              if (value == 'sold') {
                await repo.updateVehicleStatus(vehicle.id, VehicleStatus.sold);
              } else if (value == 'republish') {
                await repo.updateVehicleStatus(
                  vehicle.id,
                  VehicleStatus.published,
                );
              } else if (value == 'delete') {
                await repo.deleteVehicle(vehicle.id);
              } else if (value == 'view') {
                if (context.mounted) context.push('/vehicle/${vehicle.id}');
              }
              ref.invalidate(dealerInventoryProvider);
              ref.invalidate(dealerAnalyticsProvider);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('View listing')),
              if (vehicle.status != VehicleStatus.sold)
                const PopupMenuItem(value: 'sold', child: Text('Mark as sold')),
              if (vehicle.status == VehicleStatus.sold)
                const PopupMenuItem(
                  value: 'republish',
                  child: Text('Republish'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LEADS
// ============================================================================
class _LeadsTab extends ConsumerWidget {
  const _LeadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final theme = Theme.of(context);

    return conversationsAsync.when(
      data: (conversations) {
        final leads = conversations.where((c) => !c.isBuyer).toList();
        if (leads.isEmpty) {
          return Center(
            child: Text('No leads yet', style: theme.textTheme.bodyMedium),
          );
        }
        return ListView.separated(
          itemCount: leads.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final lead = leads[i];
            return ListTile(
              title: Text(
                lead.otherPartyName,
                style: theme.textTheme.titleLarge,
              ),
              subtitle: Text(
                lead.vehicleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/chat/${lead.id}',
                extra: {
                  'otherPartyName': lead.otherPartyName,
                  'vehicleTitle': lead.vehicleTitle,
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load leads: $e')),
    );
  }
}

// ============================================================================
// ANALYTICS
// ============================================================================
class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(dealerAnalyticsProvider);

    return analyticsAsync.when(
      data: (analytics) {
        if (analytics == null) return const SizedBox.shrink();
        final stats = [
          ('Listed', '${analytics.totalListed}', Icons.list_alt_outlined),
          (
            'Published',
            '${analytics.totalPublished}',
            Icons.check_circle_outline,
          ),
          ('Sold', '${analytics.totalSold}', Icons.sell_outlined),
          ('Total Views', '${analytics.totalViews}', Icons.visibility_outlined),
          ('Leads', '${analytics.totalLeads}', Icons.chat_bubble_outline),
        ];
        return GridView.count(
          padding: const EdgeInsets.all(AppSpacing.md),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.5,
          children: stats
              .map((s) => _StatCard(label: s.$1, value: s.$2, icon: s.$3))
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load analytics: $e')),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: theme.textTheme.displayMedium),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ============================================================================
// SUBSCRIPTION
// ============================================================================
class _SubscriptionTab extends ConsumerWidget {
  const _SubscriptionTab();

  static const _tiers = [
    (
      'starter',
      'Starter',
      'Free',
      ['Up to 10 active listings', 'Basic storefront', 'Standard support'],
    ),
    (
      'professional',
      'Professional',
      '₹999/month',
      [
        'Up to 50 active listings',
        'Featured listing credits',
        'Priority support',
        'Analytics dashboard',
      ],
    ),
    (
      'enterprise',
      'Enterprise',
      'Contact us',
      [
        'Unlimited listings',
        'Dedicated account manager',
        'API access',
        'Custom storefront branding',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(dealerProfileProvider);

    return profileAsync.when(
      data: (profile) {
        final currentTier = profile?.subscriptionTier ?? 'starter';
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: _tiers.map((tier) {
            final (id, name, price, features) = tier;
            final isCurrent = id == currentTier;
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: isCurrent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: theme.textTheme.titleLarge),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: AppRadius.pillAll,
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  Text(price, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(f, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isCurrent) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.secondary(
                      label: 'Upgrade',
                      expand: false,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payments arrive in a future update'),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load subscription: $e')),
    );
  }
}
