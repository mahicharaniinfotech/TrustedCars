import '../../../core/config/supabase_config.dart';
import '../models/vehicle.dart';
import '../../search/models/vehicle_filter.dart';

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

  /// Full search with filters + sort (Sprint 3). Text search resolves
  /// matching brand/model names first, then filters vehicles by their ids
  /// -- more robust than relying on PostgREST's embedded-resource filter
  /// syntax across a join, and easier to reason about when something
  /// doesn't match as expected.
  Future<List<Vehicle>> searchVehicles(
    VehicleFilter filter, {
    SortOption sort = SortOption.newest,
    int limit = 50,
  }) async {
    var query = supabase
        .from('vehicles')
        .select(_selectWithJoins)
        .eq('status', 'published')
        .eq('category', filter.category.name);

    if (filter.brandId != null) query = query.eq('brand_id', filter.brandId!);
    if (filter.cityId != null) query = query.eq('city_id', filter.cityId!);
    if (filter.fuelType != null) query = query.eq('fuel_type', filter.fuelType!.name);
    if (filter.transmission != null) query = query.eq('transmission', filter.transmission!.name);
    if (filter.minPrice != null) query = query.gte('price', filter.minPrice!);
    if (filter.maxPrice != null) query = query.lte('price', filter.maxPrice!);
    if (filter.minYear != null) query = query.gte('year', filter.minYear!);
    if (filter.maxYear != null) query = query.lte('year', filter.maxYear!);

    final q = filter.searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      final matchingBrandIds = await _matchingBrandIds(q);
      final matchingModelIds = await _matchingModelIds(q);

      final orParts = <String>['variant.ilike.%$q%'];
      if (matchingBrandIds.isNotEmpty) {
        orParts.add('brand_id.in.(${matchingBrandIds.join(",")})');
      }
      if (matchingModelIds.isNotEmpty) {
        orParts.add('model_id.in.(${matchingModelIds.join(",")})');
      }
      query = query.or(orParts.join(','));
    }

    final transformed = switch (sort) {
      SortOption.newest => query.order('created_at', ascending: false),
      SortOption.priceLowHigh => query.order('price', ascending: true),
      SortOption.priceHighLow => query.order('price', ascending: false),
      SortOption.kmLowHigh => query.order('km_driven', ascending: true),
    };

    final rows = await transformed.limit(limit);
    return (rows as List).map((r) => Vehicle.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<int>> _matchingBrandIds(String q) async {
    final rows = await supabase.from('brands').select('id').ilike('name', '%$q%');
    return (rows as List).map((r) => r['id'] as int).toList();
  }

  Future<List<int>> _matchingModelIds(String q) async {
    final rows = await supabase.from('vehicle_models').select('id').ilike('name', '%$q%');
    return (rows as List).map((r) => r['id'] as int).toList();
  }
}
