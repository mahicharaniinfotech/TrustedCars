import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../search/providers/lookup_providers.dart';
import '../models/account.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/role_toggle.dart';

/// Shown exactly once, right after a user's first successful phone-OTP
/// verification — collects what phone auth doesn't give us for free: name,
/// email, gender, place (city), and whether they're an individual or dealer.
///
/// ASSUMPTION: accountRepo.updateProfile() is extended here to accept
/// email/gender/cityId alongside the existing fullName param, following
/// the same named-parameter pattern already in place. If the actual
/// repository doesn't support these yet, paste it and I'll add them --
/// this screen's call site won't change either way.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  AccountType _selectedType = AccountType.individual;
  Gender? _selectedGender;
  int? _selectedCityId;
  String? _selectedCityName;
  bool _isSubmitting = false;
  String? _placeError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final citiesAsync = ref.read(citiesProvider);
    final cities = citiesAsync.value;
    if (cities == null) return;

    final searchController = TextEditingController();

    final result = await showModalBottomSheet<({int id, String name})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? cities
                : cities.where((c) => c.name.toLowerCase().contains(query)).toList();

            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.7,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select your city',
                        style: Theme.of(sheetContext).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search your city...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final city = filtered[i];
                          return ListTile(
                            title: Text(city.name),
                            onTap: () => Navigator.of(sheetContext)
                                .pop((id: city.id, name: city.name)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedCityId = result.id;
        _selectedCityName = result.name;
        _placeError = null;
      });
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    final placeValid = _selectedCityId != null;
    if (!placeValid) setState(() => _placeError = 'Please select your city');
    if (!formValid || !placeValid) return;

    setState(() => _isSubmitting = true);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId != null) {
      final accountRepo = ref.read(accountRepositoryProvider);
      await accountRepo.updateProfile(
        userId,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        gender: _selectedGender,
        cityId: _selectedCityId,
      );
      await accountRepo.setAccountType(userId, _selectedType);
      // Refresh so the router sees the now-complete profile immediately.
      ref.invalidate(currentAccountProvider);
    }
    // Router redirect takes it from here.
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    Text("You're verified", style: theme.textTheme.displayMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'A couple of quick details to finish setting up.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('I am a...', style: theme.textTheme.labelLarge),
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
                    AuthTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Required';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Gender', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        _GenderChip(
                          label: 'Male',
                          gender: Gender.male,
                          selected: _selectedGender,
                          onSelected: (g) => setState(() => _selectedGender = g),
                        ),
                        _GenderChip(
                          label: 'Female',
                          gender: Gender.female,
                          selected: _selectedGender,
                          onSelected: (g) => setState(() => _selectedGender = g),
                        ),
                        _GenderChip(
                          label: 'Other',
                          gender: Gender.other,
                          selected: _selectedGender,
                          onSelected: (g) => setState(() => _selectedGender = g),
                        ),
                        _GenderChip(
                          label: 'Prefer not to say',
                          gender: Gender.preferNotToSay,
                          selected: _selectedGender,
                          onSelected: (g) => setState(() => _selectedGender = g),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Place', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Material(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.smAll,
                      child: InkWell(
                        borderRadius: AppRadius.smAll,
                        onTap: _pickCity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.smAll,
                            border: Border.all(
                              color: _placeError != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: theme.colorScheme.outline),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _selectedCityName ?? 'Select your city',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_placeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _placeError!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
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

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.gender,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final Gender gender;
  final Gender? selected;
  final ValueChanged<Gender> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == gender,
      onSelected: (_) => onSelected(gender),
    );
  }
}
