import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository());

final pendingVerificationsProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).getPendingVerifications();
});

final allListingsProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).getAllListings();
});

final platformStatsProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).getPlatformStats();
});
