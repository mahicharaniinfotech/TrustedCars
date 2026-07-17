import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import 'kyc_providers.dart';
import 'kyc_repository.dart';

/// Placeholder identity verification screen -- ready to plug in whichever
/// KYC provider gets chosen (Digio/Signzy/Karza), but honest about not
/// being wired up yet rather than pretending to work. Deliberately NOT
/// part of the mandatory signup flow (see app_router.dart) -- forcing an
/// incomplete verification step into onboarding would block everyone from
/// using the app until a provider is actually live.
class KycStatusScreen extends ConsumerWidget {
  const KycStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(kycStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: statusAsync.when(
          data: (kyc) {
            if (kyc == null || kyc.status == KycStatus.notStarted) {
              return _NotStartedState();
            }
            return switch (kyc.status) {
              KycStatus.pending => const _PendingState(),
              KycStatus.verified => const _VerifiedState(),
              KycStatus.failed => _FailedState(reason: kyc.failureReason),
              KycStatus.notStarted => _NotStartedState(),
            };
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load verification status: $e')),
        ),
      ),
    );
  }
}

class _NotStartedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text('Verify your identity', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Identity verification is being set up and isn\'t live yet. Once available, '
          'verifying your Aadhaar unlocks the Verified badge on your listings and builds '
          'trust with buyers.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.primary(
          label: 'Coming soon',
          onPressed: null,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}

class _PendingState extends StatelessWidget {
  const _PendingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text('Verification in progress', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This usually takes a few minutes. We\'ll update your account automatically.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _VerifiedState extends StatelessWidget {
  const _VerifiedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 48, color: Colors.green),
        const SizedBox(height: AppSpacing.md),
        Text('You\'re verified', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your account shows a Verified badge to buyers on all your listings.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _FailedState extends StatelessWidget {
  const _FailedState({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text('Verification unsuccessful', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(reason ?? 'Please try again or contact support.', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
