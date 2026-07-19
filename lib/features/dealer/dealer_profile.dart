class DealerProfile {
  const DealerProfile({
    required this.accountId,
    required this.businessName,
    this.gstNumber,
    this.panNumber,
    this.businessAddress,
    this.yearsInBusiness,
    this.rating = 0.0,
    this.vehiclesSoldCount = 0,
    this.subscriptionTier = 'starter',
    this.subscriptionActive = false,
  });

  final String accountId;
  final String businessName;
  final String? gstNumber;
  final String? panNumber;
  final String? businessAddress;
  final int? yearsInBusiness;
  final double rating;
  final int vehiclesSoldCount;
  final String subscriptionTier;
  final bool subscriptionActive;

  factory DealerProfile.fromMap(Map<String, dynamic> map) {
    return DealerProfile(
      accountId: map['account_id'] as String,
      businessName: map['business_name'] as String,
      gstNumber: map['gst_number'] as String?,
      panNumber: map['pan_number'] as String?,
      businessAddress: map['business_address'] as String?,
      yearsInBusiness: map['years_in_business'] as int?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      vehiclesSoldCount: map['vehicles_sold_count'] as int? ?? 0,
      subscriptionTier: map['subscription_tier'] as String? ?? 'starter',
      subscriptionActive: map['subscription_active'] as bool? ?? false,
    );
  }
}

class DealerAnalytics {
  const DealerAnalytics({
    required this.totalListed,
    required this.totalPublished,
    required this.totalSold,
    required this.totalViews,
    required this.totalLeads,
  });

  final int totalListed;
  final int totalPublished;
  final int totalSold;
  final int totalViews;
  final int totalLeads;
}
