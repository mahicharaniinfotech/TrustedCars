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
