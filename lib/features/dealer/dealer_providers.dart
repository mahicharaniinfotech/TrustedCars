import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_providers.dart';
import '../marketplace/models/vehicle.dart';
import 'dealer_profile.dart';
import 'dealer_repository.dart';

final dealerRepositoryProvider = Provider<DealerRepository>((ref) => DealerRepository());

final dealerProfileProvider = FutureProvider<DealerProfile?>((ref) async {
  final account = await ref.watch(currentAccountProvider.future);
  if (account == null) return null;
  return ref.watch(dealerRepositoryProvider).getDealerProfile(account.id);
});

/// Same lookup, but for an arbitrary account id -- used by the Admin
/// Portal's verification review, which needs to see a dealer's business
/// details (not just their own) before approving/rejecting them.
final dealerProfileForAccountProvider =
    FutureProvider.family<DealerProfile?, String>((ref, accountId) {
  return ref.watch(dealerRepositoryProvider).getDealerProfile(accountId);
});

final dealerInventoryProvider = FutureProvider<List<Vehicle>>((ref) async {
  final account = await ref.watch(currentAccountProvider.future);
  if (account == null) return [];
  return ref.watch(dealerRepositoryProvider).getInventory(account.id);
});

final dealerAnalyticsProvider = FutureProvider<DealerAnalytics?>((ref) async {
  final account = await ref.watch(currentAccountProvider.future);
  if (account == null) return null;
  return ref.watch(dealerRepositoryProvider).getAnalytics(account.id);
});
