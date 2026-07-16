import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';

/// Placeholder landing screen after login. Real buyer/seller/dealer
/// dashboards get built out in Module 3 (Dealer Platform) and Module 2
/// (Marketplace) — this just proves auth + routing works end-to-end.
class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrustedCars'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: account.when(
          data: (acc) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 48, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                acc == null
                    ? 'Signed in, but no account record found.'
                    : 'Welcome, ${acc.fullName ?? acc.email ?? 'there'}\n'
                        'Account type: ${acc.accountType.name}',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error loading account: $e'),
        ),
      ),
    );
  }
}
