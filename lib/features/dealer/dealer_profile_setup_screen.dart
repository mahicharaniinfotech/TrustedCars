import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../auth/models/account.dart';
import '../auth/providers/auth_providers.dart';
import '../auth/widgets/auth_text_field.dart';
import 'dealer_providers.dart';

/// Shown once, the first time a dealer account visits the Dealer
/// Dashboard without a dealer_profiles row yet -- selecting "Dealer" at
/// signup only sets account_type; this is what actually creates their
/// business identity. Also shown (instead of the form) while the
/// submission is pending admin review, or if it was rejected -- the
/// dashboard itself (DealerDashboardScreen) is what decides when to show
/// this screen vs. the real dashboard, based on both dealer_profiles
/// existing AND account.isVerified.
class DealerProfileSetupScreen extends ConsumerStatefulWidget {
  const DealerProfileSetupScreen({super.key});

  @override
  ConsumerState<DealerProfileSetupScreen> createState() => _DealerProfileSetupScreenState();
}

class _DealerProfileSetupScreenState extends ConsumerState<DealerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _businessNameController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final account = ref.read(currentAccountProvider).value;
    if (account != null) {
      try {
        await ref.read(dealerRepositoryProvider).upsertDealerProfile(
              account.id,
              businessName: _businessNameController.text.trim(),
              gstNumber: _gstController.text.trim(),
              panNumber: _panController.text.trim(),
              businessAddress: _addressController.text.trim().isEmpty
                  ? null
                  : _addressController.text.trim(),
            );
        ref.invalidate(dealerProfileProvider);
        ref.invalidate(currentAccountProvider);
      } catch (e) {
        setState(() => _error = 'Could not submit: $e');
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
    // Deliberately NOT navigating away on success -- DealerDashboardScreen
    // watches both dealerProfileProvider and the account's verification
    // status, so once those refresh this screen naturally gives way to
    // either the pending-status view (below) or the real dashboard.
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentAccountProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Dealer Verification')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: switch (account?.verificationStatus) {
                VerificationStatus.pending => const _StatusMessage(
                    icon: Icons.hourglass_top_outlined,
                    title: 'Verification pending',
                    message:
                        'Your business details are under review. This usually '
                        'takes 1-2 business days. You\'ll get access to your '
                        'dealer dashboard once approved.',
                  ),
                VerificationStatus.rejected => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _StatusMessage(
                        icon: Icons.error_outline,
                        title: 'Verification not approved',
                        message:
                            'Your submission couldn\'t be verified. Please '
                            'double-check your details and resubmit below.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildForm(context),
                    ],
                  ),
                _ => _buildForm(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('A few details about your business', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This becomes your public storefront -- buyers see this, not your '
            'personal name. Reviewed manually, usually within 1-2 business days.',
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
            label: 'GST Number / Firm Registration Number',
            controller: _gstController,
            textCapitalization: TextCapitalization.characters,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AuthTextField(
            label: 'PAN Number',
            controller: _panController,
            textCapitalization: TextCapitalization.characters,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Required';
              if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(value)) {
                return 'Enter a valid PAN (e.g. ABCDE1234F)';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AuthTextField(
            label: 'Business Address (optional)',
            controller: _addressController,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: _isSubmitting ? 'Submitting...' : 'Submit for review',
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}
