import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/phone_entry_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/complete_profile_screen.dart';
import '../../features/marketplace/screens/home_screen.dart';

/// Single source of truth for navigation. Redirect logic below is what
/// keeps a logged-out user out of the dashboard, sends a freshly-verified
/// user to finish their profile, and keeps a fully set-up user out of the
/// auth screens.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final accountAsync = ref.watch(currentAccountProvider);

  return GoRouter(
    initialLocation: '/phone',
    debugLogDiagnostics: true,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      // Firebase's authStateChanges emits User? directly -- no .session wrapper.
      final isLoggedIn = authState.value != null;
      final loc = state.matchedLocation;
      final isPreAuthRoute = loc == '/phone' || loc == '/otp';

      if (!isLoggedIn) {
        return isPreAuthRoute ? null : '/phone';
      }

      // Logged in from here on. Wait for the account row to load before
      // deciding whether onboarding is complete, to avoid a false bounce.
      final account = accountAsync.value;
      if (account == null) return null;

      final profileIncomplete = !account.isProfileComplete;
      if (profileIncomplete) {
        return loc == '/complete-profile' ? null : '/complete-profile';
      }

      if (isPreAuthRoute || loc == '/complete-profile') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/phone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final args = state.extra as Map<String, String>;
          return OtpVerificationScreen(
            phone: args['phone']!,
            verificationId: args['verificationId']!,
          );
        },
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

/// Bridges Riverpod's stream/future-based state into GoRouter's
/// Listenable-based refresh mechanism, so `redirect` re-evaluates the
/// instant login, logout, or account data changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this.ref) {
    // ignore: unnecessary_underscores
    // ignore: unnecessary_underscores
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
    // ignore: unnecessary_underscores
    ref.listen(currentAccountProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
