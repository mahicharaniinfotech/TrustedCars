import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/kdmc_theme_extension.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../marketplace/models/vehicle.dart';
import '../../marketplace/providers/marketplace_providers.dart';
import '../../marketplace/providers/listing_capture_provider.dart';
import '../../marketplace/widgets/category_chip.dart';
import '../../marketplace/widgets/listing_capture_body.dart';
import '../../search/providers/lookup_providers.dart';
import '../providers/sell_providers.dart';
import '../models/vehicle_draft.dart';

/// Sprint 5 -- the multi-step Sell Vehicle flow.
///
/// Steps 0-1 (Details, Price) only edit the in-memory VehicleDraft held by
/// vehicleDraftProvider — nothing touches Supabase yet. On reaching the
/// Photos step, a real `vehicles` row is created with status 'draft' (see
/// SellRepository.createDraft) so the structured photo checklist has a real
/// vehicleId to attach uploads to. Publish (final step) flips that row's
/// status to 'published', which the DB's completeness trigger (migration
/// 013) gates on.
class SellVehicleScreen extends ConsumerWidget {
  const SellVehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(sellStepProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('List Your Vehicle'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmDiscard(context, ref),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (step) {
                0 => const _VehicleInfoStep(key: ValueKey('step0')),
                1 => const _PriceLocationStep(key: ValueKey('step1')),
                2 => const _PhotosStep(key: ValueKey('step2')),
                _ => const _PreviewStep(key: ValueKey('step3')),
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDiscard(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this listing?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () {
              ref.read(vehicleDraftProvider.notifier).reset();
              ref.read(sellStepProvider.notifier).reset();
              Navigator.of(dialogContext).pop();
              context.pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  static const _labels = ['Details', 'Price', 'Photos', 'Preview'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isActive = i <= currentStep;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[i],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// STEP 1 -- Vehicle Info (unchanged)
// ============================================================================
class _VehicleInfoStep extends ConsumerStatefulWidget {
  const _VehicleInfoStep({super.key});

  @override
  ConsumerState<_VehicleInfoStep> createState() => _VehicleInfoStepState();
}

class _VehicleInfoStepState extends ConsumerState<_VehicleInfoStep> {
  late final TextEditingController _variantController;
  late final TextEditingController _kmController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(vehicleDraftProvider);
    _variantController = TextEditingController(text: draft.variant ?? '');
    _kmController = TextEditingController(
      text: draft.kmDriven?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _variantController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(vehicleDraftProvider);
    final notifier = ref.read(vehicleDraftProvider.notifier);
    final brandsAsync = ref.watch(brandsForCategoryProvider(draft.category));
    final currentYear = DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are you listing?', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              CategoryChip(
                label: 'Car',
                icon: Icons.directions_car_outlined,
                isSelected: draft.category == VehicleCategory.car,
                onTap: () => notifier.update(
                  (d) => VehicleDraft(category: VehicleCategory.car),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CategoryChip(
                label: 'Bike',
                icon: Icons.two_wheeler_outlined,
                isSelected: draft.category == VehicleCategory.bike,
                onTap: () => notifier.update(
                  (d) => VehicleDraft(category: VehicleCategory.bike),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Text('Brand', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          brandsAsync.when(
            data: (brands) => DropdownButtonFormField<int>(
              initialValue: draft.brandId,
              hint: const Text('Select brand'),
              isExpanded: true,
              items: brands
                  .map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  )
                  .toList(),
              onChanged: (value) {
                final brand = brands.firstWhere((b) => b.id == value);
                notifier.update(
                  (d) => d.copyWith(
                    brandId: value,
                    brandName: brand.name,
                    modelId: null,
                  ),
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text('Could not load brands', style: theme.textTheme.bodySmall),
          ),

          const SizedBox(height: AppSpacing.md),
          Text('Model', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          if (draft.brandId == null)
            Text('Select a brand first', style: theme.textTheme.bodySmall)
          else
            Consumer(
              builder: (context, ref, _) {
                final modelsAsync = ref.watch(
                  modelsForBrandProvider(draft.brandId!),
                );
                return modelsAsync.when(
                  data: (models) => DropdownButtonFormField<int>(
                    initialValue: draft.modelId,
                    hint: const Text('Select model'),
                    isExpanded: true,
                    items: models
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final model = models.firstWhere((m) => m.id == value);
                      notifier.update(
                        (d) =>
                            d.copyWith(modelId: value, modelName: model.name),
                      );
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Could not load models',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),

          const SizedBox(height: AppSpacing.md),
          Text('Variant (optional)', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _variantController,
            decoration: const InputDecoration(hintText: 'e.g. VXI, SX, ZXI'),
            onChanged: (value) =>
                notifier.update((d) => d.copyWith(variant: value)),
          ),

          const SizedBox(height: AppSpacing.md),
          Text('Year', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<int>(
            initialValue: draft.year,
            hint: const Text('Select year'),
            isExpanded: true,
            items: List.generate(currentYear - 2004, (i) => currentYear - i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (value) =>
                notifier.update((d) => d.copyWith(year: value)),
          ),

          const SizedBox(height: AppSpacing.md),
          Text('Fuel Type', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: FuelType.values.map((fuel) {
              return ChoiceChip(
                label: Text(
                  fuel.name[0].toUpperCase() + fuel.name.substring(1),
                ),
                selected: draft.fuelType == fuel,
                onSelected: (_) =>
                    notifier.update((d) => d.copyWith(fuelType: fuel)),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.md),
          Text('Transmission', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: TransmissionType.values.map((t) {
              return ChoiceChip(
                label: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                selected: draft.transmission == t,
                onSelected: (_) =>
                    notifier.update((d) => d.copyWith(transmission: t)),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.md),
          Text('KM Driven', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _kmController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 35000'),
            onChanged: (value) => notifier.update(
              (d) => d.copyWith(kmDriven: int.tryParse(value)),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Next',
            onPressed: draft.isStep1Complete
                ? () => ref.read(sellStepProvider.notifier).next()
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 2 -- Price & Location (unchanged)
// ============================================================================
class _PriceLocationStep extends ConsumerStatefulWidget {
  const _PriceLocationStep({super.key});

  @override
  ConsumerState<_PriceLocationStep> createState() => _PriceLocationStepState();
}

class _PriceLocationStepState extends ConsumerState<_PriceLocationStep> {
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _regNumberController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(vehicleDraftProvider);
    _priceController = TextEditingController(
      text: draft.price?.toStringAsFixed(0) ?? '',
    );
    _descriptionController = TextEditingController(
      text: draft.description ?? '',
    );
    _regNumberController = TextEditingController(
      text: draft.registrationNumber ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(vehicleDraftProvider);
    final notifier = ref.read(vehicleDraftProvider.notifier);
    final citiesAsync = ref.watch(citiesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asking Price (₹)', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 650000'),
            onChanged: (value) => notifier.update(
              (d) => d.copyWith(price: double.tryParse(value)),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Text('City', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          citiesAsync.when(
            data: (cities) => DropdownButtonFormField<int>(
              initialValue: draft.cityId,
              hint: const Text('Select city'),
              isExpanded: true,
              items: cities
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (value) {
                final city = cities.firstWhere((c) => c.id == value);
                notifier.update(
                  (d) => d.copyWith(cityId: value, cityName: city.name),
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text('Could not load cities', style: theme.textTheme.bodySmall),
          ),

          const SizedBox(height: AppSpacing.md),
          Text('Description (optional)', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Condition, service history, reason for selling...',
            ),
            onChanged: (value) =>
                notifier.update((d) => d.copyWith(description: value)),
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            'Registration Number (optional)',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Never shown publicly -- kept private for verification only.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _regNumberController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'e.g. TS09AB1234'),
            onChanged: (value) =>
                notifier.update((d) => d.copyWith(registrationNumber: value)),
          ),

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Back',
                  onPressed: () => ref.read(sellStepProvider.notifier).back(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.primary(
                  label: 'Next',
                  onPressed: draft.isStep2Complete
                      ? () => ref.read(sellStepProvider.notifier).next()
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 3 -- Photos (REPLACED: structured checklist instead of free-form
// image picker). Creates/syncs the draft `vehicles` row on entry, then
// embeds the shared ListingCaptureBody. Next is gated on real checklist
// completeness (listingCaptureProvider), not on local image count.
// ============================================================================
class _PhotosStep extends ConsumerStatefulWidget {
  const _PhotosStep({super.key});

  @override
  ConsumerState<_PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<_PhotosStep> {
  bool _isPreparing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareDraftAndLoad();
  }

  Future<void> _prepareDraftAndLoad() async {
    setState(() {
      _isPreparing = true;
      _error = null;
    });

    final draft = ref.read(vehicleDraftProvider);
    final account = ref.read(currentAccountProvider).value;
    if (account == null) {
      if (mounted) {
        setState(() {
          _error = 'You need to be signed in to list a vehicle.';
          _isPreparing = false;
        });
      }
      return;
    }

    final repository = ref.read(sellRepositoryProvider);
    try {
      int vehicleId;
      if (draft.vehicleId == null) {
        vehicleId = await repository.createDraft(account.id, draft);
        ref
            .read(vehicleDraftProvider.notifier)
            .update((d) => d.copyWith(vehicleId: vehicleId));
      } else {
        vehicleId = draft.vehicleId!;
        // Sync any edits made if the user went Back and changed
        // Details/Price after the draft row was first created.
        await repository.updateDraftFields(vehicleId, draft);
      }
      await ref.read(listingCaptureProvider.notifier).loadVehicle(vehicleId);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not prepare listing: $e');
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreparing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: 'Try again',
              onPressed: _prepareDraftAndLoad,
            ),
          ],
        ),
      );
    }

    final captureAsync = ref.watch(listingCaptureProvider);
    final ready = captureAsync.maybeWhen(
      data: (s) => s.remainingMandatoryCount == 0,
      orElse: () => false,
    );

    return Column(
      children: [
        const Expanded(child: ListingCaptureBody()),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Back',
                  onPressed: () => ref.read(sellStepProvider.notifier).back(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.primary(
                  label: 'Next',
                  onPressed: ready
                      ? () => ref.read(sellStepProvider.notifier).next()
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STEP 4 -- Preview & Publish
// ============================================================================
class _PreviewStep extends ConsumerStatefulWidget {
  const _PreviewStep({super.key});

  @override
  ConsumerState<_PreviewStep> createState() => _PreviewStepState();
}

class _PreviewStepState extends ConsumerState<_PreviewStep> {
  bool _isPublishing = false;
  String? _error;

  Future<void> _publish() async {
    final draft = ref.read(vehicleDraftProvider);
    final vehicleId = draft.vehicleId;
    if (vehicleId == null) {
      setState(() => _error = 'Listing is not ready to publish yet.');
      return;
    }

    setState(() {
      _isPublishing = true;
      _error = null;
    });

    try {
      // Friendly in-app check before hitting the DB trigger's raw
      // Postgres exception as the only signal.
      final completeness =
          await ref.read(listingCaptureProvider.notifier).checkCompleteness();
      if (!completeness.complete) {
        setState(() {
          _error =
              '${completeness.missingCount} required photo(s) still missing. '
              'Go back to the Photos step to finish them.';
        });
        return;
      }

      await ref.read(sellRepositoryProvider).publishDraft(vehicleId);

      ref.read(vehicleDraftProvider.notifier).reset();
      ref.read(sellStepProvider.notifier).reset();
      ref.invalidate(featuredVehiclesProvider);
      ref.invalidate(recentVehiclesProvider);

      if (mounted) context.go('/vehicle/$vehicleId');
    } catch (e) {
      setState(() => _error = 'Could not publish listing: $e');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.kdmcTokens;
    final draft = ref.watch(vehicleDraftProvider);
    final captureAsync = ref.watch(listingCaptureProvider);
    final captureState = captureAsync.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review your listing', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          if (captureState?.coverPhotoUrl != null)
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  captureState!.coverPhotoUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(draft.title, style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(draft.cityName ?? '', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '₹${draft.price?.toStringAsFixed(0) ?? '0'}',
            style: tokens.priceStyleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _PreviewChip(label: '${draft.year}'),
              _PreviewChip(label: '${draft.kmDriven ?? 0} km'),
              _PreviewChip(label: draft.fuelType?.name ?? ''),
              _PreviewChip(label: draft.transmission?.name ?? ''),
              _PreviewChip(
                  label: '${captureState?.totalPhotoCount ?? 0} photos'),
            ],
          ),
          if (draft.description != null && draft.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(draft.description!, style: theme.textTheme.bodyMedium),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Back',
                  onPressed: _isPublishing
                      ? null
                      : () => ref.read(sellStepProvider.notifier).back(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.primary(
                  label: _isPublishing ? 'Publishing...' : 'Publish Listing',
                  onPressed: _isPublishing ? null : _publish,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
