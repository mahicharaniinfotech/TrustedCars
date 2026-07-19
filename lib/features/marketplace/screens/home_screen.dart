import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/vehicle_card.dart';
import '../../../shared/widgets/gradient_action_card.dart';
import '../../../shared/widgets/quick_service_tile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/router/require_auth.dart';
import '../../search/providers/favorites_providers.dart';
import '../../search/providers/lookup_providers.dart';
import '../../location/providers/location_providers.dart';
import '../models/vehicle.dart';
import '../providers/category_filter_provider.dart';
import '../providers/marketplace_providers.dart';
import '../widgets/category_chip.dart';

/// The real home screen -- Sprint 2. Replaces the placeholder dashboard
/// that only existed to prove auth worked end-to-end.
///
/// Now a ConsumerStatefulWidget (was ConsumerWidget) so it can trigger
/// device-location resolution exactly once on first load via initState --
/// see resolveFromDeviceLocation() in location_providers.dart. This is
/// silent and non-blocking: if permission is denied or resolution fails,
/// the feed just stays unfiltered (all cities) until the user picks one
/// manually via the city chip under the AppBar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(selectedCityIdProvider.notifier).resolveFromDeviceLocation();
  }

  Future<void> _showCityPicker() async {
    final citiesAsync = ref.read(citiesProvider);
    final cities = citiesAsync.value;
    if (cities == null) return;

    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? cities
                : cities.where((c) => c.name.toLowerCase().contains(query)).toList();

            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.7,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select your city',
                        style: Theme.of(sheetContext).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search your city...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () {
                        ref.read(selectedCityIdProvider.notifier).setCity(null);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Show all India'),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final city = filtered[i];
                          return ListTile(
                            title: Text(city.name),
                            onTap: () {
                              ref
                                  .read(selectedCityIdProvider.notifier)
                                  .setCity(city.id);
                              Navigator.of(sheetContext).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentAccountProvider).value;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final featured = ref.watch(featuredVehiclesProvider);
    final categoryVehicles = ref.watch(
      vehiclesByCategoryProvider(selectedCategory),
    );
    final cityNameAsync = ref.watch(selectedCityNameProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TrustedCars',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: AppRadius.pillAll,
                onTap: _showCityPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        cityNameAsync.value ?? 'Detecting location...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          if (account != null && !account.isVerified)
            IconButton(
              tooltip: 'Verify identity',
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: () => context.push('/kyc'),
            ),
          if (account?.accountType == AccountType.admin)
            IconButton(
              tooltip: 'Admin Portal',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push('/admin'),
            ),
          if (account?.accountType == AccountType.dealer)
            IconButton(
              tooltip: 'Dealer Dashboard',
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: () => context.push('/dealer'),
            ),
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              if (requireAuth(
                    context,
                    ref,
                    message: 'Sign in to view your messages',
                  ) !=
                  null) {
                context.push('/messages');
              }
            },
          ),
          if (account != null)
            IconButton(
              tooltip: 'Account',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.push('/account'),
            )
          else
            IconButton(
              tooltip: 'Sign in',
              icon: const Icon(Icons.login),
              onPressed: () => context.push('/phone'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (requireAuth(
                context,
                ref,
                message: 'Sign in to list your vehicle',
              ) !=
              null) {
            context.push('/sell');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Sell'),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 16),
              child: child,
            ),
          );
        },
        child: RefreshIndicator(
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

              Row(
                children: [
                  Expanded(
                    child: GradientActionCard(
                      title: 'Buy a Vehicle',
                      subtitle: 'Browse verified listings',
                      icon: Icons.directions_car_filled,
                      gradientColors: AppColors.buyGradient,
                      onTap: () => context.push('/search'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GradientActionCard(
                      title: 'Sell your Vehicle',
                      subtitle: 'List in minutes, free',
                      icon: Icons.sell,
                      gradientColors: AppColors.sellGradient,
                      onTap: () => context.push('/sell'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  QuickServiceTile(
                    label: 'Insurance',
                    icon: Icons.shield_outlined,
                    gradientColors: AppColors.buyGradient,
                    comingSoon: true,
                  ),
                  QuickServiceTile(
                    label: 'Loans',
                    icon: Icons.account_balance_outlined,
                    gradientColors: AppColors.sellGradient,
                    comingSoon: true,
                  ),
                  QuickServiceTile(
                    label: 'RC Transfer',
                    icon: Icons.assignment_turned_in_outlined,
                    gradientColors: AppColors.accentGradient,
                    comingSoon: true,
                  ),
                  QuickServiceTile(
                    label: 'Inspection',
                    icon: Icons.fact_check_outlined,
                    gradientColors: AppColors.accentGradient,
                    comingSoon: true,
                  ),
                  QuickServiceTile(
                    label: 'Favorites',
                    icon: Icons.favorite_border,
                    gradientColors: AppColors.sellGradient,
                    onTap: () => context.push('/search'),
                  ),
                ],
              ),
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
                      isSelected:
                          selectedCategory == VehicleCategory.commercial,
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
      onFavoriteToggle: () {
        if (requireAuth(context, ref, message: 'Sign in to save favorites') !=
            null) {
          ref.read(favoriteIdsProvider.notifier).toggle(vehicle.id);
        }
      },
      onTap: () => context.push('/vehicle/${vehicle.id}'),
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
