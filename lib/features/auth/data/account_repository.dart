import '../../../core/config/supabase_config.dart';
import '../models/account.dart';

/// Reads and writes the `accounts` table.
class AccountRepository {
  Future<Account?> getAccount(String userId) async {
    final row = await supabase
        .from('accounts')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Account.fromMap(row);
  }

  /// Firebase-authenticated users never touch Supabase's own auth.users
  /// table, so the DB trigger that used to auto-create this row (see
  /// migration 001) never fires for them. Call this right after phone
  /// verification succeeds instead — creates the row on first login,
  /// or just syncs the phone number if the account already exists.
  Future<void> ensureAccountExists(String userId, {String? phone}) async {
    final existing = await getAccount(userId);
    if (existing != null) {
      if (phone != null && existing.phone != phone) {
        await updateProfile(userId, phone: phone);
      }
      return;
    }
    await supabase.from('accounts').insert({
      'id': userId,
      'phone': phone,
      'account_type': 'individual',
    });
  }

  /// Called from CompleteProfileScreen to record whether this user is an
  /// individual or a dealer — the one branch point in onboarding.
  Future<void> setAccountType(String userId, AccountType type) async {
    await supabase
        .from('accounts')
        .update({'account_type': type.name})
        .eq('id', userId);
  }

  Future<void> updateProfile(
    String userId, {
    String? fullName,
    String? phone,
    String? email,
    Gender? gender,
    int? cityId,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;
    if (gender != null) updates['gender'] = gender.dbValue;
    if (cityId != null) updates['city_id'] = cityId;
    if (updates.isEmpty) return;
    await supabase.from('accounts').update(updates).eq('id', userId);
  }

  /// Calls the delete-account Edge Function, which runs with service-role
  /// privileges to delete the auth.users row (the client SDK deliberately
  /// can't do this directly). supabase.functions.invoke() automatically
  /// attaches the current session's JWT as the Authorization header, so
  /// the function can identify the caller without any params here — see
  /// supabase/functions/delete-account/index.ts for the server side.
  Future<void> deleteAccount() async {
    final response = await supabase.functions.invoke('delete-account');
    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : response.data;
      throw Exception(error?.toString() ?? 'Account deletion failed');
    }
  }
}
