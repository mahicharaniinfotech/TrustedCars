import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/kdmc_theme_extension.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/trust_badge.dart';
import '../../../shared/widgets/vehicle_card.dart';
import '../../search/providers/favorites_providers.dart';
import '../models/vehicle.dart';
import '../providers/marketplace_providers.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));

    return Scaffold(
      body: vehicleAsync.when(
        data: (vehicle) => vehicle == null
            ? const _NotFound()
            : _VehicleDetailContent(vehicle: vehicle),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load this vehicle: $e')),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This listing is no longer available',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

class _VehicleDetailContent extends ConsumerStatefulWidget {
  const _VehicleDetailContent({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_VehicleDetailContent> createState() =>
      _VehicleDetailContentState();
}

class _VehicleDetailContentState extends ConsumerState<_VehicleDetailContent> {
  final _pageController = PageController();
  int _currentImage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.kdmcTokens;
    final vehicle = widget.vehicle;
    final favoriteIds = ref.watch(favoriteIdsProvider).value ?? {};
    final isFavorite = favoriteIds.contains(vehicle.id);
    final images = vehicle.imageUrls.isNotEmpty
        ? vehicle.imageUrls
        : ['https://images.unsplash.com/photo-1552519507-da3b142c6e3d'];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 300,
          leading: const _CircleIconButton(icon: Icons.arrow_back),
          actions: [
            _CircleIconButton(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? AppColors.ember : null,
              onPressed: () =>
                  ref.read(favoriteIdsProvider.notifier).toggle(vehicle.id),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _currentImage = i),
                  itemBuilder: (context, i) =>
                      Image.network(images[i], fit: BoxFit.cover),
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: AppSpacing.md,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentImage ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: i == _currentImage ? 1 : 0.5,
                            ),
                            borderRadius: AppRadius.pillAll,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.title,
                            style: theme.textTheme.displayMedium,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                vehicle.cityName ?? 'India',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (vehicle.sellerVerified)
                      TrustBadge(
                        kind: vehicle.isDealerListing
                            ? TrustBadgeKind.dealer
                            : TrustBadgeKind.owner,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(vehicle.formattedPrice, style: tokens.priceStyleLarge),

                const SizedBox(height: AppSpacing.lg),
                _SpecsGrid(vehicle: vehicle),

                if (vehicle.description != null &&
                    vehicle.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Description', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(vehicle.description!, style: theme.textTheme.bodyMedium),
                ],

                const SizedBox(height: AppSpacing.lg),
                Text(
                  vehicle.isDealerListing ? 'Dealer' : 'Seller',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SellerCard(vehicle: vehicle),

                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  label:
                      'Chat with ${vehicle.isDealerListing ? "Dealer" : "Seller"}',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat arrives in Sprint 6')),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xl),
                Text('Similar Vehicles', style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                _SimilarVehicles(vehicle: vehicle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final specs = [
      (Icons.calendar_today_outlined, 'Year', '${vehicle.year}'),
      (Icons.speed_outlined, 'KM Driven', vehicle.formattedKm),
      (Icons.local_gas_station_outlined, 'Fuel', vehicle.fuelLabel),
      (Icons.settings_outlined, 'Transmission', vehicle.transmissionLabel),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.6,
      children: specs.map((spec) {
        final (icon, label, value) = spec;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = vehicle.isDealerListing
        ? (vehicle.dealerBusinessName ??
              vehicle.sellerName ??
              'Verified Dealer')
        : (vehicle.sellerName ?? 'Seller');

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
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(
              vehicle.isDealerListing
                  ? Icons.storefront_outlined
                  : Icons.person_outline,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge),
                if (vehicle.isDealerListing && vehicle.dealerRating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        '${vehicle.dealerRating!.toStringAsFixed(1)} · ${vehicle.dealerVehiclesSold ?? 0} sold',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  )
                else if (vehicle.sellerVerified)
                  Text(
                    vehicle.isDealerListing
                        ? 'Verified Dealer'
                        : 'Verified Owner',
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

class _SimilarVehicles extends ConsumerWidget {
  const _SimilarVehicles({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (
      excludeVehicleId: vehicle.id,
      brandId: vehicle.brandId,
      category: vehicle.category,
    );
    final similarAsync = ref.watch(similarVehiclesProvider(params));
    final favoriteIds = ref.watch(favoriteIdsProvider).value ?? {};

    return SizedBox(
      height: 300,
      child: similarAsync.when(
        data: (vehicles) => vehicles.isEmpty
            ? Center(
                child: Text(
                  'No similar vehicles found',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vehicles.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final v = vehicles[i];
                  return SizedBox(
                    width: 260,
                    child: VehicleCard(
                      imageUrl:
                          v.primaryImageUrl ??
                          'https://images.unsplash.com/photo-1552519507-da3b142c6e3d',
                      title: v.title,
                      price: v.formattedPrice,
                      year: '${v.year}',
                      km: v.formattedKm.replaceAll(' km', ''),
                      fuel: v.fuelLabel,
                      location: v.cityName ?? 'India',
                      verified: true,
                      isFavorite: favoriteIds.contains(v.id),
                      onFavoriteToggle: () =>
                          ref.read(favoriteIdsProvider.notifier).toggle(v.id),
                      onTap: () => context.go('/vehicle/${v.id}'),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, this.color, this.onPressed});

  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color ?? Colors.white),
          ),
        ),
      ),
    );
  }
}
