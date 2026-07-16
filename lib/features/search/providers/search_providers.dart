import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../marketplace/models/vehicle.dart';
import '../../marketplace/providers/marketplace_providers.dart';
import '../models/vehicle_filter.dart';

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchFilterNotifier extends Notifier<VehicleFilter> {
  @override
  VehicleFilter build() => const VehicleFilter();
  void update(VehicleFilter Function(VehicleFilter) updater) => state = updater(state);
  void reset() => state = state.clearAllFilters();
}

final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, VehicleFilter>(SearchFilterNotifier.new);

class SortOptionNotifier extends Notifier<SortOption> {
  @override
  SortOption build() => SortOption.newest;
  void select(SortOption option) => state = option;
}

final sortOptionProvider = NotifierProvider<SortOptionNotifier, SortOption>(SortOptionNotifier.new);

/// Combines the query text into the active filter, then runs the search.
/// Re-runs automatically whenever query, filter, or sort changes.
final searchResultsProvider = FutureProvider<List<Vehicle>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchFilterProvider);
  final sort = ref.watch(sortOptionProvider);

  final effectiveFilter =
      query.isEmpty ? filter.copyWith(clearSearchQuery: true) : filter.copyWith(searchQuery: query);

  return ref.watch(vehicleRepositoryProvider).searchVehicles(effectiveFilter, sort: sort);
});
