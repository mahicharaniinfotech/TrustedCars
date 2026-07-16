import '../../../core/config/supabase_config.dart';
import '../marketplace/models/vehicle.dart';
import 'dealer_profile.dart';

class DealerRepository {
  Future<DealerProfile?> getDealerProfile(String accountId) async {
    final row = await supabase
        .from('dealer_profiles')
        .select()
        .eq('account_id', accountId)
        .maybeSingle();
    return row == null ? null : DealerProfile.fromMap(row);
  }

  /// Called from the one-time Dealer Profile Setup screen. Creates the
  /// dealer_profiles row if it doesn't exist yet (nothing does this
  /// automatically -- unlike accounts, there's no trigger for it, since
  /// not every account is a dealer).
  Future<void> upsertDealerProfile(
    String accountId, {
    required String businessName,
    String? gstNumber,
    String? businessAddress,
  }) async {
    await supabase.from('dealer_profiles').upsert({
      'account_id': accountId,
      'business_name': businessName,
      'gst_number': gstNumber,
      'business_address': businessAddress,
    });
  }

  /// Every vehicle this dealer owns, regardless of status -- unlike the
  /// public marketplace queries, this deliberately does NOT filter to
  /// 'published' only, since the dealer needs to see and manage drafts
  /// and sold vehicles too. Relies on the "Owners can view own vehicles"
  /// half of the vehicles SELECT policy (migration 004).
  Future<List<Vehicle>> getInventory(String accountId) async {
    final rows = await supabase
        .from('vehicles')
        .select('''
          id, account_id, category, brand_id, variant, year, fuel_type, transmission,
          km_driven, price, description, status, is_featured, views_count,
          brands ( name ),
          vehicle_models ( name ),
          cities ( name ),
          vehicle_images ( image_url, is_primary, sort_order )
        ''')
        .eq('account_id', accountId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Vehicle.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> updateVehicleStatus(int vehicleId, VehicleStatus status) async {
    await supabase.from('vehicles').update({'status': status.name}).eq('id', vehicleId);

    // Selling through the platform bumps the dealer's public sold count --
    // best-effort, not critical if it fails (e.g. for individual sellers,
    // there's no dealer_profiles row to increment at all).
    if (status == VehicleStatus.sold) {
      try {
        final vehicle = await supabase.from('vehicles').select('account_id').eq('id', vehicleId).single();
        final accountId = vehicle['account_id'] as String;
        final profile = await getDealerProfile(accountId);
        if (profile != null) {
          await supabase
              .from('dealer_profiles')
              .update({'vehicles_sold_count': profile.vehiclesSoldCount + 1})
              .eq('account_id', accountId);
        }
      } catch (_) {
        // Not a dealer, or update failed -- not critical.
      }
    }
  }

  Future<void> deleteVehicle(int vehicleId) async {
    await supabase.from('vehicles').delete().eq('id', vehicleId);
  }

  Future<DealerAnalytics> getAnalytics(String accountId) async {
    final vehicles = await supabase
        .from('vehicles')
        .select('status, views_count')
        .eq('account_id', accountId);

    final list = (vehicles as List).cast<Map<String, dynamic>>();
    final totalListed = list.length;
    final totalPublished = list.where((v) => v['status'] == 'published').length;
    final totalSold = list.where((v) => v['status'] == 'sold').length;
    final totalViews = list.fold<int>(0, (sum, v) => sum + (v['views_count'] as int? ?? 0));

    final leadsResult = await supabase
        .from('conversations')
        .select('id')
        .eq('seller_id', accountId);
    final totalLeads = (leadsResult as List).length;

    return DealerAnalytics(
      totalListed: totalListed,
      totalPublished: totalPublished,
      totalSold: totalSold,
      totalViews: totalViews,
      totalLeads: totalLeads,
    );
  }
}
