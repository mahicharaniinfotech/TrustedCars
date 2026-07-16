import '../../../core/config/supabase_config.dart';

/// Reads and writes the `favorites` table (migration 006). RLS already
/// restricts every operation to the caller's own rows.
class FavoritesRepository {
  Future<Set<int>> getFavoriteVehicleIds(String accountId) async {
    final rows = await supabase
        .from('favorites')
        .select('vehicle_id')
        .eq('account_id', accountId);
    return (rows as List).map((r) => r['vehicle_id'] as int).toSet();
  }

  Future<void> addFavorite(String accountId, int vehicleId) async {
    await supabase.from('favorites').upsert({
      'account_id': accountId,
      'vehicle_id': vehicleId,
    });
  }

  Future<void> removeFavorite(String accountId, int vehicleId) async {
    await supabase
        .from('favorites')
        .delete()
        .eq('account_id', accountId)
        .eq('vehicle_id', vehicleId);
  }
}
