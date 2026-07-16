import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../auth/providers/auth_providers.dart';
import '../auth/widgets/auth_text_field.dart';
import 'dealer_providers.dart';

/// Shown once, the first time a dealer account visits the Dealer
/// Dashboard without a dealer_profiles row yet -- selecting "Dealer" at
/// signup only sets account_type; this is what actually creates their
/// business identity.
class DealerProfileSetupScreen extends ConsumerStatefulWidget {
  const DealerProfileSetupScreen({super.key});

  @override
  ConsumerState<DealerProfileSetupScreen> createState() => _DealerProfileSetupScreenState();
}

class _DealerProfileSetupScreenState extends ConsumerState<DealerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final account = ref.read(currentAccountProvider).value;
    if (account != null) {
      await ref.read(dealerRepositoryProvider).upsertDealerProfile(
            account.id,
            businessName: _businessNameController.text.trim(),
            gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
            businessAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          );
      ref.invalidate(dealerProfileProvider);
    }

    if (mounted) context.go('/dealer');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Dealership')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('A few details about your business', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'This becomes your public storefront -- buyers see this, not your personal name.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AuthTextField(
                      label: 'Business Name',
                      controller: _businessNameController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthTextField(
                      label: 'GST Number (optional)',
                      controller: _gstController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthTextField(
                      label: 'Business Address (optional)',
                      controller: _addressController,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      label: _isSubmitting ? 'Saving...' : 'Continue',
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
