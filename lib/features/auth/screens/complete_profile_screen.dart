import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../models/account.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/role_toggle.dart';

/// Shown exactly once, right after a user's first successful phone-OTP
/// verification — collects the two things phone auth doesn't give us for
/// free: their name, and whether they're here as an individual or a dealer.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  AccountType _selectedType = AccountType.individual;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId != null) {
      final accountRepo = ref.read(accountRepositoryProvider);
      await accountRepo.updateProfile(userId, fullName: _nameController.text.trim());
      await accountRepo.setAccountType(userId, _selectedType);
      // Refresh so the router sees the now-complete profile immediately.
      ref.invalidate(currentAccountProvider);
    }
    // Router redirect takes it from here.
    if (mounted) setState(() => _isSubmitting = false);
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
                    Text("You're verified", style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'A couple of quick details to finish setting up.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('I am a...', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    RoleToggle(
                      selected: _selectedType,
                      onChanged: (type) => setState(() => _selectedType = type),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AuthTextField(
                      label: _selectedType == AccountType.dealer ? 'Contact Name' : 'Full Name',
                      controller: _nameController,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Required' : null,
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
