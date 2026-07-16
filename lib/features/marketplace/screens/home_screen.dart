import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/vehicle_card.dart';
import '../../auth/providers/auth_providers.dart';
import '../../search/providers/favorites_providers.dart';
import '../models/vehicle.dart';
import '../providers/category_filter_provider.dart';
import '../providers/marketplace_providers.dart';
import '../widgets/category_chip.dart';

/// The real home screen -- Sprint 2. Replaces the placeholder dashboard
/// that only existed to prove auth worked end-to-end.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountProvider).value;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final featured = ref.watch(featuredVehiclesProvider);
    final categoryVehicles = ref.watch(
      vehiclesByCategoryProvider(selectedCategory),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TrustedCars',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredVehiclesProvider);
          ref.invalidate(vehiclesByCategoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (account?.fullName != null && account!.fullName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Hi ${account.fullName!.split(' ').first}, find your next vehicle',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),

            _SearchBarStub(),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'Browse by',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  CategoryChip(
                    label: 'Cars',
                    icon: Icons.directions_car_outlined,
                    isSelected: selectedCategory == VehicleCategory.car,
                    onTap: () => ref
                        .read(selectedCategoryProvider.notifier)
                        .select(VehicleCategory.car),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CategoryChip(
                    label: 'Bikes',
                    icon: Icons.two_wheeler_outlined,
                    isSelected: selectedCategory == VehicleCategory.bike,
                    onTap: () => ref
                        .read(selectedCategoryProvider.notifier)
                        .select(VehicleCategory.bike),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CategoryChip(
                    label: 'Commercial',
                    icon: Icons.local_shipping_outlined,
                    isSelected: selectedCategory == VehicleCategory.commercial,
                    onTap: () => ref
                        .read(selectedCategoryProvider.notifier)
                        .select(VehicleCategory.commercial),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const CategoryChip(
                    label: 'Coming Soon',
                    icon: Icons.hourglass_empty,
                    isSelected: false,
                    enabled: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Text(
              'Featured Vehicles',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 300,
              child: featured.when(
                data: (vehicles) => vehicles.isEmpty
                    ? const _EmptyState(message: 'No featured vehicles yet.')
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: vehicles.length,
                        // ignore: unnecessary_underscores
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) => SizedBox(
                          width: 260,
                          child: _VehicleCardFromModel(vehicle: vehicles[i]),
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _EmptyState(
                  message: 'Could not load featured vehicles: $e',
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Text(
              'Recently Listed ${_categoryLabel(selectedCategory)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            categoryVehicles.when(
              data: (vehicles) => vehicles.isEmpty
                  ? _EmptyState(
                      message:
                          'No ${_categoryLabel(selectedCategory).toLowerCase()} listed yet.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.maxWidth / 280)
                            .floor()
                            .clamp(1, 4);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: vehicles.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: AppSpacing.sm,
                                crossAxisSpacing: AppSpacing.sm,
                                childAspectRatio: 0.72,
                              ),
                          itemBuilder: (context, i) =>
                              _VehicleCardFromModel(vehicle: vehicles[i]),
                        );
                      },
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  _EmptyState(message: 'Could not load listings: $e'),
            ),

            const SizedBox(height: AppSpacing.xl),
            Text(
              'Trusted Dealers Near You',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _DealerSectionPlaceholder(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.car:
        return 'Cars';
      case VehicleCategory.bike:
        return 'Bikes';
      case VehicleCategory.commercial:
        return 'Commercial Vehicles';
    }
  }
}

/// Bridges the Vehicle model to VehicleCard's individual named parameters,
/// and wires up the favorite toggle. Falls back to a placeholder image
/// since Sell Vehicle (Sprint 5) -- which is what actually uploads real
/// photos -- doesn't exist yet.
class _VehicleCardFromModel extends ConsumerWidget {
  const _VehicleCardFromModel({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoriteIdsProvider).value ?? {};

    return VehicleCard(
      imageUrl:
          vehicle.primaryImageUrl ??
          'https://images.unsplash.com/photo-1552519507-da3b142c6e3d',
      title: vehicle.title,
      price: vehicle.formattedPrice,
      year: '${vehicle.year}',
      km: vehicle.formattedKm.replaceAll(' km', ''),
      fuel: vehicle.fuelLabel,
      location: vehicle.cityName ?? 'India',
      verified: true,
      isFavorite: favoriteIds.contains(vehicle.id),
      onFavoriteToggle: () =>
          ref.read(favoriteIdsProvider.notifier).toggle(vehicle.id),
      onTap: () {
        // Vehicle detail screen lands in Sprint 4.
      },
    );
  }
}

class _SearchBarStub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: () => context.push('/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Search cars, bikes, brands...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealerSectionPlaceholder extends StatelessWidget {
  const _DealerSectionPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront_outlined,
            color: theme.colorScheme.outline,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dealer storefronts launching soon',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Verified dealer profiles and inventory arrive in Module 3.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
