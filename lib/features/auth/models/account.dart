enum AccountType { individual, dealer, admin }

enum VerificationStatus { unverified, pending, verified, rejected }

AccountType _accountTypeFromString(String? value) => AccountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AccountType.individual,
    );

VerificationStatus _verificationFromString(String? value) => VerificationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VerificationStatus.unverified,
    );

/// Mirrors a row in the `accounts` table (001_foundation_schema.sql).
class Account {
  const Account({
    required this.id,
    required this.accountType,
    required this.verificationStatus,
    this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final AccountType accountType;
  final VerificationStatus verificationStatus;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;

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
    );
  }
}
