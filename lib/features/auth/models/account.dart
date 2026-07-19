enum AccountType { individual, dealer, admin }

enum VerificationStatus { unverified, pending, verified, rejected }

/// Mirrors the `gender_type` Postgres enum (migration 016).
enum Gender { male, female, other, preferNotToSay }

extension GenderDbValue on Gender {
  /// Postgres enum value is 'prefer_not_to_say' (snake_case); everything
  /// else matches the Dart enum name.
  String get dbValue => this == Gender.preferNotToSay ? 'prefer_not_to_say' : name;
}

AccountType _accountTypeFromString(String? value) => AccountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AccountType.individual,
    );

VerificationStatus _verificationFromString(String? value) => VerificationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VerificationStatus.unverified,
    );

/// Postgres enum value is 'prefer_not_to_say' (snake_case), Dart enum name
/// is preferNotToSay (camelCase) -- everything else matches by name.
Gender? _genderFromString(String? value) {
  if (value == null) return null;
  if (value == 'prefer_not_to_say') return Gender.preferNotToSay;
  for (final g in Gender.values) {
    if (g.name == value) return g;
  }
  return null;
}

/// Mirrors a row in the `accounts` table (001_foundation_schema.sql,
/// extended by migration 016 for gender). city_id/gender are gathered on
/// the Complete Profile screen alongside full_name.
class Account {
  const Account({
    required this.id,
    required this.accountType,
    required this.verificationStatus,
    this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.gender,
    this.cityId,
  });

  final String id;
  final AccountType accountType;
  final VerificationStatus verificationStatus;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final Gender? gender;
  final int? cityId;

  bool get isDealer => accountType == AccountType.dealer;
  bool get isVerified => verificationStatus == VerificationStatus.verified;

  /// Phone-OTP signup creates the account with no name/role chosen yet —
  /// this tells the router whether to send the user to CompleteProfileScreen.
  bool get isProfileComplete => fullName != null && fullName!.trim().isNotEmpty;

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      accountType: _accountTypeFromString(map['account_type'] as String?),
      verificationStatus: _verificationFromString(map['verification_status'] as String?),
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      gender: _genderFromString(map['gender'] as String?),
      cityId: map['city_id'] as int?,
    );
  }

  /// For writing back to Supabase (Complete Profile submit, Edit Profile).
  Map<String, dynamic> toUpdateMap() {
    return {
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
      if (gender != null) 'gender': gender!.dbValue,
      if (cityId != null) 'city_id': cityId,
    };
  }
}
