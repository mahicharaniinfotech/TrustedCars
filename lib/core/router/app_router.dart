// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/phone_entry_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/complete_profile_screen.dart';
import '../../features/marketplace/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/marketplace/screens/vehicle_detail_screen.dart';
import '../../features/sell/screens/sell_vehicle_screen.dart';
import '../../features/chat/screens/conversation_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/dealer/dealer_dashboard_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/kyc/kyc_status_screen.dart';
import '../../features/auth/models/account.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/splash_providers.dart';
import 'page_transitions.dart';
import '../../features/sell/screens/sell_landing_screen.dart';
import '../../features/auth/screens/account_screen.dart';

/// Single source of truth for navigation.
///
/// IMPORTANT: this provider builds the GoRouter instance exactly ONCE.
/// It deliberately does NOT `ref.watch(...)` auth state at the top level --
/// doing so would make Riverpod rebuild (recreate) the entire GoRouter
/// object every time login state changes, which resets navigation back to
/// `initialLocation` for a frame before redirect logic corrects it.
///
/// Instead: `redirect` reads live state via `ref.read()` each time it
/// runs, and `refreshListenable` (_AuthRefreshNotifier below) is what
/// tells GoRouter *when* to re-run redirect -- without ever touching the
/// router object itself.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Hold on the animated splash until its entrance animation finishes.
      final splashDone = ref.read(splashCompleteProvider);
      if (!splashDone) {
        return loc == '/splash' ? null : '/splash';
      }
      // Splash hands off to Home, not the phone screen -- guests land
      // straight on the marketplace, matching the "browse first, log in
      // only when you need to" design.
      if (loc == '/splash') return '/dashboard';

      final authState = ref.read(authStateChangesProvider);
      final isLoggedIn = authState.value != null;
      final isPreAuthRoute = loc == '/phone' || loc == '/otp';

      // Guest-accessible routes: browsing needs no login at all. Everything
      // else (selling, chat, dashboards) still requires an account.
      final isPublicRoute =
          loc == '/dashboard' ||
          loc == '/search' ||
          loc.startsWith('/vehicle/');

      if (!isLoggedIn) {
        if (isPublicRoute || isPreAuthRoute) return null;
        return '/phone';
      }

      // Logged in from here on. Wait for the account row to load before
      // deciding whether onboarding is complete, to avoid a false bounce.
      final account = ref.read(currentAccountProvider).value;
      if (account == null) return null;

      final profileIncomplete = !account.isProfileComplete;
      if (profileIncomplete) {
        return loc == '/complete-profile' ? null : '/complete-profile';
      }

      if (isPreAuthRoute || loc == '/complete-profile') return '/dashboard';

      // Admin portal is gated by account_type, not just login state.
      if (loc == '/admin' && account.accountType != AccountType.admin) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/phone',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const PhoneEntryScreen(),
        ),
      ),
      GoRoute(
        path: '/otp',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, String>;
          return fadeTransitionPage(
            context: context,
            state: state,
            child: OtpVerificationScreen(
              phone: args['phone']!,
              verificationId: args['verificationId']!,
            ),
          );
        },
      ),
      GoRoute(
        path: '/complete-profile',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const CompleteProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/vehicle/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return fadeTransitionPage(
            context: context,
            state: state,
            child: VehicleDetailScreen(vehicleId: id),
          );
        },
      ),
      GoRoute(
        path: '/sell',
        builder: (context, state) => const SellLandingScreen(),
      ),
      GoRoute(
        path: '/sell/details',
        builder: (context, state) => const SellVehicleScreen(),
      ),
      GoRoute(
        path: '/messages',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const ConversationListScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, String?>?;
          return fadeTransitionPage(
            context: context,
            state: state,
            child: ChatScreen(
              conversationId: id,
              otherPartyName: extra?['otherPartyName'],
              vehicleTitle: extra?['vehicleTitle'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/dealer',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const DealerDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/kyc',
        pageBuilder: (context, state) => fadeTransitionPage(
          context: context,
          state: state,
          child: const KycStatusScreen(),
        ),
      ),
    ],
  );
});

/// Bridges Riverpod's stream/future-based state into GoRouter's
/// Listenable-based refresh mechanism, so `redirect` re-evaluates the
/// instant splash completes, login, logout, or account data changes --
/// without recreating the GoRouter object itself.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this.ref) {
    ref.listen(splashCompleteProvider, (_, __) => notifyListeners());
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
    ref.listen(currentAccountProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
