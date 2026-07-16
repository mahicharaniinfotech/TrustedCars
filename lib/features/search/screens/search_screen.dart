import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/vehicle_card.dart';
import '../../marketplace/models/vehicle.dart';
import '../providers/favorites_providers.dart';
import '../widgets/filter_sheet.dart';
import '../providers/search_providers.dart';
import '../models/vehicle_filter.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(searchFilterProvider);
    final sort = ref.watch(sortOptionProvider);
    final results = ref.watch(searchResultsProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider).value ?? {};

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search cars, brands, models...',
            border: InputBorder.none,
          ),
          onChanged: (value) => ref.read(searchQueryProvider.notifier).setQuery(value),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showFilterSheet(context),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(
                      filter.hasActiveFilters ? 'Filters (${filter.activeFilterCount})' : 'Filters',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<SortOption>(
                    initialValue: sort,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: const [
                      DropdownMenuItem(value: SortOption.newest, child: Text('Newest')),
                      DropdownMenuItem(value: SortOption.priceLowHigh, child: Text('Price: Low to High')),
                      DropdownMenuItem(value: SortOption.priceHighLow, child: Text('Price: High to Low')),
                      DropdownMenuItem(value: SortOption.kmLowHigh, child: Text('KM: Low to High')),
                    ],
                    onChanged: (value) {
                      if (value != null) ref.read(sortOptionProvider.notifier).select(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              data: (vehicles) => vehicles.isEmpty
                  ? Center(
                      child: Text('No vehicles match your search', style: theme.textTheme.bodyMedium),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.maxWidth / 280).floor().clamp(1, 4);
                        return GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: vehicles.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, i) {
                            final vehicle = vehicles[i];
                            return VehicleCard(
                              imageUrl: vehicle.primaryImageUrl ??
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
                              onTap: () => context.go('/vehicle/${vehicle.id}'),
                            );
                          },
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Search failed: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
