import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vehicle_repository.dart';
import '../models/vehicle.dart';
import '../../location/providers/location_providers.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) => VehicleRepository());

/// Waits for the resolved city (if any) before querying, so the feed
/// doesn't flash "all cities" then immediately refetch once location
/// resolves a moment later. Re-runs automatically whenever the selected
/// city changes (manual pick or fresh GPS resolution).
final featuredVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final cityId = await ref.watch(selectedCityIdProvider.future);
  return ref.watch(vehicleRepositoryProvider).getFeaturedVehicles(cityId: cityId);
});

final recentVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final cityId = await ref.watch(selectedCityIdProvider.future);
  return ref.watch(vehicleRepositoryProvider).getRecentVehicles(cityId: cityId);
});

/// Family provider -- one instance per category, so switching category
/// tabs on the home screen doesn't refetch everything each time.
final vehiclesByCategoryProvider =
    FutureProvider.family<List<Vehicle>, VehicleCategory>((ref, category) async {
  final cityId = await ref.watch(selectedCityIdProvider.future);
  return ref.watch(vehicleRepositoryProvider).getVehiclesByCategory(category, cityId: cityId);
});

/// Sprint 4 -- a single vehicle's full detail, including seller/dealer info.
/// Deliberately NOT city-filtered -- once you're looking at a specific
/// vehicle by id, its city is irrelevant to whether it should load.
final vehicleDetailProvider = FutureProvider.family<Vehicle?, int>((ref, vehicleId) {
  return ref.watch(vehicleRepositoryProvider).getVehicleDetail(vehicleId);
});

/// "Similar vehicles" row on the detail screen -- same brand & category,
/// excluding the vehicle being viewed. Takes a record rather than the
/// whole Vehicle object so Riverpod's family caching compares by value
/// (Vehicle itself has no custom == , so two logically-identical
/// instances wouldn't be treated as the same cache key).
final similarVehiclesProvider =
    FutureProvider.family<List<Vehicle>, ({int excludeVehicleId, int? brandId, VehicleCategory category})>(
        (ref, params) {
  return ref.watch(vehicleRepositoryProvider).getSimilarVehicles(
        excludeVehicleId: params.excludeVehicleId,
        brandId: params.brandId,
        category: params.category,
      );
});
