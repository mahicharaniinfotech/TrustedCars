import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_repository.dart';
import '../data/account_repository.dart';
import '../models/account.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository());

/// Emits every time Firebase's auth state changes — login, logout, token
/// refresh. Screens/router watch this rather than polling.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The current signed-in user's `accounts` row, or null if logged out.
/// Re-fetches automatically whenever auth state changes.
final currentAccountProvider = FutureProvider<Account?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;
  return ref.watch(accountRepositoryProvider).getAccount(user.uid);
});
