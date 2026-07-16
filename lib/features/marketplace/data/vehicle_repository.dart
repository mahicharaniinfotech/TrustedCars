import '../../../core/config/supabase_config.dart';
import '../models/vehicle.dart';

/// Reads vehicle listings. All queries here rely on the RLS policies from
/// migration 004 -- "published" vehicles are visible to everyone (guests
/// included, deliberately, for SEO), draft/removed only to their owner.
class VehicleRepository {
  /// Shared select shape: pulls in brand/model names, city, and images so
  /// the UI never has to make N+1 queries per card.
  static const _selectWithJoins = '''
    id, account_id, category, variant, year, fuel_type, transmission,
    km_driven, price, description, status, is_featured,
    brands ( name ),
    vehicle_models ( name ),
    cities ( name ),
    vehicle_images ( image_url, is_primary, sort_order )
  ''';

  Future<List<Vehicle>> getFeaturedVehicles({int limit = 10}) async {
    final rows = await supabase
        .from('vehicles')
        .select(_selectWithJoins)
        .eq('status', 'published')
        .eq('is_featured', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => Vehicle.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Vehicle>> getRecentVehicles({int limit = 20}) async {
    final rows = await supabase
        .from('vehicles')
        .select(_selectWithJoins)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => Vehicle.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Vehicle>> getVehiclesByCategory(VehicleCategory category, {int limit = 20}) async {
    final rows = await supabase
        .from('vehicles')
        .select(_selectWithJoins)
        .eq('status', 'published')
        .eq('category', category.name)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => Vehicle.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Vehicle?> getVehicleById(int id) async {
    final row = await supabase
        .from('vehicles')
        .select(_selectWithJoins)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Vehicle.fromMap(row);
  }
}
