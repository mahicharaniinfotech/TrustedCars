import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/auth_providers.dart';
import '../utils/phone_utils.dart';
import '../widgets/auth_text_field.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone, required this.verificationId});

  /// E.164 formatted phone number (e.g. +919876543210).
  final String phone;

  /// Firebase's verification session ID, needed alongside the SMS code
  /// to actually verify. Passed via GoRouter's `extra` from PhoneEntryScreen.
  final String verificationId;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  late String _verificationId = widget.verificationId;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _resendSecondsLeft = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSecondsLeft = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final userId = await ref.read(authRepositoryProvider).verifyPhoneOtp(
            verificationId: _verificationId,
            token: _otpController.text.trim(),
          );
      await ref.read(accountRepositoryProvider).ensureAccountExists(userId, phone: widget.phone);
      // Router redirect takes it from here.
    } catch (e) {
      setState(() => _errorMessage = 'Verify failed: $e');
      // ignore: avoid_print
      print('OTP verify error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resend() async {
    try {
      final newVerificationId = await ref.read(authRepositoryProvider).signInWithOtp(phone: widget.phone);
      setState(() => _verificationId = newVerificationId);
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP resent')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not resend OTP')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
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
                    Text('Enter the code', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sent to ${PhoneUtils.formatForDisplay(widget.phone)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AuthTextField(
                      label: '6-digit code',
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      validator: (value) =>
                          (value == null || value.trim().length != 6) ? 'Enter the 6-digit code' : null,
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
                      label: _isSubmitting ? 'Verifying...' : 'Verify & Continue',
                      onPressed: _isSubmitting ? null : _verify,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: _resendSecondsLeft == 0 ? _resend : null,
                      child: Text(
                        _resendSecondsLeft == 0
                            ? 'Resend code'
                            : 'Resend code in ${_resendSecondsLeft}s',
                      ),
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
