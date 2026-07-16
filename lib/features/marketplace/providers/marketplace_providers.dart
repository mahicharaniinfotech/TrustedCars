import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vehicle_repository.dart';
import '../models/vehicle.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) => VehicleRepository());

final featuredVehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  return ref.watch(vehicleRepositoryProvider).getFeaturedVehicles();
});

final recentVehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  return ref.watch(vehicleRepositoryProvider).getRecentVehicles();
});

/// Family provider -- one instance per category, so switching category
/// tabs on the home screen doesn't refetch everything each time.
final vehiclesByCategoryProvider =
    FutureProvider.family<List<Vehicle>, VehicleCategory>((ref, category) {
  return ref.watch(vehicleRepositoryProvider).getVehiclesByCategory(category);
});

/// Sprint 4 -- a single vehicle's full detail, including seller/dealer info.
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
