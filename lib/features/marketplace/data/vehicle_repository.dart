import '../../../core/config/supabase_config.dart';
import '../models/vehicle.dart';
import '../../search/models/vehicle_filter.dart';

/// Reads vehicle listings. All queries here rely on the RLS policies from
/// migration 004 -- "published" vehicles are visible to everyone (guests
/// included, deliberately, for SEO), draft/removed only to their owner.
class VehicleRepository {
  /// Shared select shape for list views (home, search, similar vehicles):
  /// brand/model names, city, and images. Deliberately does NOT join
  /// seller/dealer info, to keep list queries fast -- use
  /// getVehicleDetail for that.
  static const _selectWithJoins = '''
    id, account_id, category, brand_id, variant, year, fuel_type, transmission,
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

  /// For the vehicle detail screen. Deliberately three flat, independent
  /// queries rather than one clever embedded join:
  ///   1. The vehicle itself (brand/model/city/images -- a relationship
  ///      PostgREST resolves reliably, since those are direct FKs on
  ///      `vehicles`).
  ///   2. The seller's public profile (migration 007's view), looked up
  ///      directly by vehicle.accountId -- no embedding, just a plain
  ///      `.eq()`, so there's no relationship-inference to get wrong.
  ///   3. If the seller is a dealer, their dealer_profiles row -- same
  ///      reasoning: dealer_profiles relates to vehicles through accounts
  ///      (two hops), which PostgREST can't embed directly in one query
  ///      anyway, so a direct lookup is both the safe choice and the only
  ///      one that actually works.
  /// If steps 2/3 fail for any reason, the vehicle itself still renders --
  /// it just won't show seller/dealer info.
  Future<Vehicle?> getVehicleDetail(int id) async {
    final row = await supabase
        .from('vehicles')
        .select(_selectWithJoins)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    var vehicle = Vehicle.fromMap(row);

    try {
      final profile = await supabase
          .from('public_profiles')
          .select('full_name, account_type, verification_status')
          .eq('id', vehicle.accountId)
          .maybeSingle();

      if (profile == null) return vehicle;

      final sellerAccountType = switch (profile['account_type'] as String?) {
        'dealer' => AccountType.dealer,
        'admin' => AccountType.admin,
        _ => AccountType.individual,
      };

      String? dealerBusinessName;
      double? dealerRating;
      int? dealerVehiclesSold;

      if (sellerAccountType == AccountType.dealer) {
        final dealer = await supabase
            .from('dealer_profiles')
            .select('business_name, rating, vehicles_sold_count')
            .eq('account_id', vehicle.accountId)
            .maybeSingle();
        dealerBusinessName = dealer?['business_name'] as String?;
        dealerRating = (dealer?['rating'] as num?)?.toDouble();
        dealerVehiclesSold = dealer?['vehicles_sold_count'] as int?;
      }

      vehicle = vehicle.copyWithSeller(
        sellerName: profile['full_name'] as String?,
        sellerAccountType: sellerAccountType,
        sellerVerified: profile['verification_status'] == 'verified',
        dealerBusinessName: dealerBusinessName,
        dealerRating: dealerRating,
        dealerVehiclesSold: dealerVehiclesSold,
      );
    } catch (_) {
      // Seller profile lookup failed -- vehicle still renders without it.
    }

    return vehicle;
  }

  Future<List<Vehicle>> getSimilarVehicles({
    required int excludeVehicleId,
    int? brandId,
    required VehicleCategory category,
    int limit = 8,
  }) async {
    var query = supabase
        .from('vehicles')
        .select(_selectWithJoins)
        .eq('status', 'published')
        .eq('category', category.name)
        .neq('id', excludeVehicleId);

    if (brandId != null) query = query.eq('brand_id', brandId);

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return (rows as List).map((r) => Vehicle.fromMap(r as Map<String, dynamic>)).toList();
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
