import '../../../core/config/supabase_config.dart';

enum KycDocumentType { aadhaar, pan, gst, other }
enum KycStatus { notStarted, pending, verified, failed }

class KycVerification {
  const KycVerification({
    required this.documentType,
    required this.status,
    this.provider,
    this.failureReason,
  });

  final KycDocumentType documentType;
  final KycStatus status;
  final String? provider;
  final String? failureReason;

  factory KycVerification.fromMap(Map<String, dynamic> map) {
    return KycVerification(
      documentType: KycDocumentType.values.firstWhere(
        (e) => e.name == map['document_type'],
        orElse: () => KycDocumentType.aadhaar,
      ),
      status: _statusFromDb(map['status'] as String?),
      provider: map['provider'] as String?,
      failureReason: map['failure_reason'] as String?,
    );
  }

  static KycStatus _statusFromDb(String? value) => switch (value) {
        'pending' => KycStatus.pending,
        'verified' => KycStatus.verified,
        'failed' => KycStatus.failed,
        _ => KycStatus.notStarted,
      };
}

/// Provider-agnostic KYC data layer (migration 012). Whichever of
/// Digio/Signzy/Karza gets chosen, integration means: call their API,
/// then write the result here via `recordProviderResult` -- nothing else
/// in the app needs to know which provider was used.
class KycRepository {
  Future<KycVerification?> getStatus(String accountId, {KycDocumentType documentType = KycDocumentType.aadhaar}) async {
    final row = await supabase
        .from('kyc_verifications')
        .select()
        .eq('account_id', accountId)
        .eq('document_type', documentType.name)
        .maybeSingle();
    return row == null ? null : KycVerification.fromMap(row);
  }

  /// Call once you've picked a provider and wired their API -- this just
  /// records the outcome; it doesn't call any provider itself.
  Future<void> recordProviderResult({
    required String accountId,
    required String provider,
    required String providerReference,
    required KycStatus status,
    KycDocumentType documentType = KycDocumentType.aadhaar,
    String? failureReason,
  }) async {
    await supabase.from('kyc_verifications').upsert({
      'account_id': accountId,
      'document_type': documentType.name,
      'provider': provider,
      'provider_reference': providerReference,
      'status': switch (status) {
        KycStatus.pending => 'pending',
        KycStatus.verified => 'verified',
        KycStatus.failed => 'failed',
        KycStatus.notStarted => 'not_started',
      },
      'failure_reason': failureReason,
      if (status == KycStatus.verified) 'verified_at': DateTime.now().toIso8601String(),
    });
  }
}
