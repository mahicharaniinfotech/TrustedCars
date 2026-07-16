import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) => FavoritesRepository());

/// The current user's favorited vehicle ids, as a Set for cheap membership
/// checks (VehicleCard just does `favoriteIds.contains(vehicle.id)`).
class FavoriteIdsNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final account = await ref.watch(currentAccountProvider.future);
    if (account == null) return {};
    return ref.watch(favoritesRepositoryProvider).getFavoriteVehicleIds(account.id);
  }

  Future<void> toggle(int vehicleId) async {
    final account = await ref.read(currentAccountProvider.future);
    if (account == null) return;

    final repo = ref.read(favoritesRepositoryProvider);
    final current = state.value ?? {};

    if (current.contains(vehicleId)) {
      state = AsyncData({...current}..remove(vehicleId));
      await repo.removeFavorite(account.id, vehicleId);
    } else {
      state = AsyncData({...current, vehicleId});
      await repo.addFavorite(account.id, vehicleId);
    }
  }
}

final favoriteIdsProvider = AsyncNotifierProvider<FavoriteIdsNotifier, Set<int>>(FavoriteIdsNotifier.new);
