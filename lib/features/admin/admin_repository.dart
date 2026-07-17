import '../../core/config/supabase_config.dart';
import '../auth/models/account.dart';
import '../marketplace/models/vehicle.dart';

class PlatformStats {
  const PlatformStats({
    required this.totalUsers,
    required this.totalDealers,
    required this.totalListings,
    required this.pendingVerifications,
  });

  final int totalUsers;
  final int totalDealers;
  final int totalListings;
  final int pendingVerifications;
}

class AdminRepository {
  /// Every account not yet verified -- covers both accounts that never
  /// requested verification and any (future) explicit "pending" request
  /// flow, since neither currently distinguishes itself from the other in
  /// the UI. Admin reviews and decides either way.
  Future<List<Account>> getPendingVerifications() async {
    final rows = await supabase
        .from('accounts')
        .select()
        .neq('verification_status', 'verified')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Account.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> setVerificationStatus(String accountId, VerificationStatus status) async {
    await supabase.from('accounts').update({'verification_status': status.name}).eq('id', accountId);
  }

  /// All published listings, for moderation -- unlike the public
  /// marketplace queries, this includes everything regardless of who owns
  /// it (relies on the admin RLS policy from migration 011).
  Future<List<Vehicle>> getAllListings({int limit = 100}) async {
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
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => Vehicle.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> removeListing(int vehicleId, String reason) async {
    await supabase
        .from('vehicles')
        .update({'status': 'removed', 'removed_reason': reason})
        .eq('id', vehicleId);
  }

  Future<void> restoreListing(int vehicleId) async {
    await supabase
        .from('vehicles')
        .update({'status': 'published', 'removed_reason': null})
        .eq('id', vehicleId);
  }

  Future<PlatformStats> getPlatformStats() async {
    final accounts = await supabase.from('accounts').select('account_type, verification_status');
    final accountList = (accounts as List).cast<Map<String, dynamic>>();

    final vehicles = await supabase.from('vehicles').select('id').eq('status', 'published');
    final vehicleList = (vehicles as List);

    return PlatformStats(
      totalUsers: accountList.length,
      totalDealers: accountList.where((a) => a['account_type'] == 'dealer').length,
      totalListings: vehicleList.length,
      pendingVerifications: accountList.where((a) => a['verification_status'] != 'verified').length,
    );
  }
}
