import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/auth_providers.dart';
import '../utils/phone_utils.dart';
import '../widgets/auth_text_field.dart';

/// Entry point for both new and returning users — TrustedCars uses phone
/// OTP as the primary identity, matching how buyers/sellers actually
/// expect a vehicle marketplace to work in India (no passwords to remember).
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final e164Phone = PhoneUtils.toE164India(_phoneController.text);
    try {
      final verificationId = await ref.read(authRepositoryProvider).signInWithOtp(phone: e164Phone);
      if (mounted) {
        context.push('/otp', extra: {'phone': e164Phone, 'verificationId': verificationId});
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not send OTP: $e');
      // ignore: avoid_print
      print('OTP send error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    Text('TrustedCars', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "India's trusted vehicle marketplace",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AuthTextField(
                      label: 'Mobile Number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixText: '+91  ',
                      maxLength: 10,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      validator: (value) => (value == null || !PhoneUtils.isValidIndianMobile(value))
                          ? 'Enter a valid 10-digit mobile number'
                          : null,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      label: _isSubmitting ? 'Sending OTP...' : 'Continue',
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      "We'll text you a one-time code. No password needed.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
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
