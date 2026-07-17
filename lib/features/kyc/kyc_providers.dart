import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_providers.dart';
import 'kyc_repository.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) => KycRepository());

final kycStatusProvider = FutureProvider<KycVerification?>((ref) async {
  final account = await ref.watch(currentAccountProvider.future);
  if (account == null) return null;
  return ref.watch(kycRepositoryProvider).getStatus(account.id);
});
