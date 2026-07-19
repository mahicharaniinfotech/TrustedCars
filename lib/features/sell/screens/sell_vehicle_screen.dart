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
// STEP 1 -- Vehicle Details (REDESIGNED: one question per screen, matching
// the reference flow. Breadcrumb chips accumulate at the top; each answer
// auto-advances to the next question except the combined Fuel/Transmission
// screen, which needs a Continue button since it takes two selections.
// Order: Brand -> Model -> Year -> Fuel/Transmission/Variant -> Ownership
// -> KM range -> City. City is asked here (not in Step 2) so Step 2 is
// just price/description/registration number.
// ============================================================================
class _VehicleInfoStep extends ConsumerStatefulWidget {
  const _VehicleInfoStep({super.key});

  @override
  ConsumerState<_VehicleInfoStep> createState() => _VehicleInfoStepState();
}

class _VehicleInfoStepState extends ConsumerState<_VehicleInfoStep> {
  late int _question;
  static const _questionCount = 7;

  final _searchController = TextEditingController();
  final _variantController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If a brand was already picked on the landing page, skip straight to
    // the Model question instead of re-asking Brand.
    final draft = ref.read(vehicleDraftProvider);
    _question = draft.brandId != null ? 1 : 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _variantController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_question == 0) return;
    setState(() {
      _question -= 1;
      _searchController.clear();
    });
  }

  void _advance() {
    _searchController.clear();
    if (_question < _questionCount - 1) {
      setState(() => _question += 1);
    } else {
      ref.read(sellStepProvider.notifier).next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(vehicleDraftProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChipsHeader(theme, draft),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_question > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _goBack,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const Spacer(),
                    Text(
                      '${_question + 1}/$_questionCount',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: _buildQuestion(theme, draft)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipsHeader(ThemeData theme, VehicleDraft draft) {
    final chips = <String>[
      if (draft.brandName != null) draft.brandName!,
      if (draft.modelName != null) draft.modelName!,
      if (draft.year != null) '${draft.year}',
      if (draft.fuelType != null)
        draft.fuelType!.name[0].toUpperCase() + draft.fuelType!.name.substring(1),
      if (draft.ownerNumber != null)
        OwnershipOption.all
            .firstWhere((o) => o.ownerNumber == draft.ownerNumber)
            .label,
      if (draft.kmDriven != null)
        KmRangeBucket.all
            .firstWhere((b) => b.representativeKm == draft.kmDriven,
                orElse: () => KmRangeBucket.all.last)
            .label,
      if (draft.cityName != null) draft.cityName!,
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: chips
            .map((c) => Chip(
                  label: Text(c, style: theme.textTheme.bodySmall),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildQuestion(ThemeData theme, VehicleDraft draft) {
    switch (_question) {
      case 0:
        return _BrandQuestion(
          searchController: _searchController,
          category: draft.category,
          onCategoryChanged: (category) {
            ref.read(vehicleDraftProvider.notifier).update(
                  (d) => VehicleDraft(category: category),
                );
          },
          onSelected: (id, name) {
            ref.read(vehicleDraftProvider.notifier).update(
                  (d) => VehicleDraft(
                    category: d.category,
                    brandId: id,
                    brandName: name,
                  ),
                );
            _advance();
          },
        );
      case 1:
        return _ModelQuestion(
          searchController: _searchController,
          brandId: draft.brandId!,
          onSelected: (id, name) {
            ref
                .read(vehicleDraftProvider.notifier)
                .update((d) => d.copyWith(modelId: id, modelName: name));
            _advance();
          },
        );
      case 2:
        return _YearQuestion(
          onSelected: (year) {
            ref
                .read(vehicleDraftProvider.notifier)
                .update((d) => d.copyWith(year: year));
            _advance();
          },
        );
      case 3:
        return _FuelTransmissionQuestion(
          variantController: _variantController,
          draft: draft,
          onFuelSelected: (fuel) => setState(() => ref
              .read(vehicleDraftProvider.notifier)
              .update((d) => d.copyWith(fuelType: fuel))),
          onTransmissionSelected: (t) => setState(() => ref
              .read(vehicleDraftProvider.notifier)
              .update((d) => d.copyWith(transmission: t))),
          onContinue: () {
            ref.read(vehicleDraftProvider.notifier).update(
                (d) => d.copyWith(variant: _variantController.text));
            _advance();
          },
        );
      case 4:
        return _OwnershipQuestion(
          onSelected: (ownerNumber) {
            ref
                .read(vehicleDraftProvider.notifier)
                .update((d) => d.copyWith(ownerNumber: ownerNumber));
            _advance();
          },
        );
      case 5:
        return _KmRangeQuestion(
          onSelected: (km) {
            ref
                .read(vehicleDraftProvider.notifier)
                .update((d) => d.copyWith(kmDriven: km));
            _advance();
          },
        );
      case 6:
        return _CityQuestion(
          searchController: _searchController,
          onSelected: (id, name) {
            ref
                .read(vehicleDraftProvider.notifier)
                .update((d) => d.copyWith(cityId: id, cityName: name));
            _advance();
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _BrandQuestion extends ConsumerStatefulWidget {
  const _BrandQuestion({
    required this.searchController,
    required this.category,
    required this.onSelected,
    required this.onCategoryChanged,
  });

  final TextEditingController searchController;
  final VehicleCategory category;
  final void Function(int id, String name) onSelected;
  final ValueChanged<VehicleCategory> onCategoryChanged;

  @override
  ConsumerState<_BrandQuestion> createState() => _BrandQuestionState();
}

class _BrandQuestionState extends ConsumerState<_BrandQuestion> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandsAsync = ref.watch(brandsForCategoryProvider(widget.category));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CategoryChip(
              label: 'Car',
              icon: Icons.directions_car_outlined,
              isSelected: widget.category == VehicleCategory.car,
              onTap: () => widget.onCategoryChanged(VehicleCategory.car),
            ),
            const SizedBox(width: AppSpacing.sm),
            CategoryChip(
              label: 'Bike',
              icon: Icons.two_wheeler_outlined,
              isSelected: widget.category == VehicleCategory.bike,
              onTap: () => widget.onCategoryChanged(VehicleCategory.bike),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text.rich(
          TextSpan(
            text: 'Select the ',
            style: theme.textTheme.headlineSmall,
            children: [
              TextSpan(
                text: 'brand',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' of your vehicle'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.searchController,
          decoration: const InputDecoration(
            hintText: 'Search your brand...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: brandsAsync.when(
            data: (brands) {
              final query = widget.searchController.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? brands
                  : brands
                      .where((b) => b.name.toLowerCase().contains(query))
                      .toList();
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.3,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final b = filtered[i];
                  return _OptionTile(
                    label: b.name,
                    onTap: () => widget.onSelected(b.id, b.name),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load brands: $e'),
          ),
        ),
      ],
    );
  }
}

class _ModelQuestion extends ConsumerStatefulWidget {
  const _ModelQuestion({
    required this.searchController,
    required this.brandId,
    required this.onSelected,
  });

  final TextEditingController searchController;
  final int brandId;
  final void Function(int id, String name) onSelected;

  @override
  ConsumerState<_ModelQuestion> createState() => _ModelQuestionState();
}

class _ModelQuestionState extends ConsumerState<_ModelQuestion> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelsAsync = ref.watch(modelsForBrandProvider(widget.brandId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Select the ',
            style: theme.textTheme.headlineSmall,
            children: [
              TextSpan(
                text: 'model',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' of your vehicle'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.searchController,
          decoration: const InputDecoration(
            hintText: 'Search your model...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: modelsAsync.when(
            data: (models) {
              final query = widget.searchController.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? models
                  : models
                      .where((m) => m.name.toLowerCase().contains(query))
                      .toList();
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.3,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final m = filtered[i];
                  return _OptionTile(
                    label: m.name,
                    onTap: () => widget.onSelected(m.id, m.name),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load models: $e'),
          ),
        ),
      ],
    );
  }
}

class _YearQuestion extends StatelessWidget {
  const _YearQuestion({required this.onSelected});

  final void Function(int year) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 2004, (i) => currentYear - i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Select the ',
            style: theme.textTheme.headlineSmall,
            children: [
              TextSpan(
                text: 'manufacturing year',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            itemCount: years.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _OptionTile(
              label: '${years[i]}',
              fullWidth: true,
              onTap: () => onSelected(years[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _FuelTransmissionQuestion extends StatelessWidget {
  const _FuelTransmissionQuestion({
    required this.variantController,
    required this.draft,
    required this.onFuelSelected,
    required this.onTransmissionSelected,
    required this.onContinue,
  });

  final TextEditingController variantController;
  final VehicleDraft draft;
  final ValueChanged<FuelType> onFuelSelected;
  final ValueChanged<TransmissionType> onTransmissionSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = draft.fuelType != null && draft.transmission != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Select the ',
              style: theme.textTheme.headlineSmall,
              children: [
                TextSpan(
                  text: 'variant',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' of your vehicle'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('SELECT FUEL TYPE', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: FuelType.values.map((fuel) {
              return ChoiceChip(
                label: Text(
                  fuel.name[0].toUpperCase() + fuel.name.substring(1),
                ),
                selected: draft.fuelType == fuel,
                onSelected: (_) => onFuelSelected(fuel),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('SELECT TRANSMISSION', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: TransmissionType.values.map((t) {
              return ChoiceChip(
                label: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                selected: draft.transmission == t,
                onSelected: (_) => onTransmissionSelected(t),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('VARIANT (OPTIONAL)', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: variantController,
            decoration: const InputDecoration(hintText: 'e.g. VXI, SX, ZXI'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Continue',
            onPressed: ready ? onContinue : null,
          ),
        ],
      ),
    );
  }
}

class _OwnershipQuestion extends StatelessWidget {
  const _OwnershipQuestion({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Select the ',
            style: theme.textTheme.headlineSmall,
            children: [
              TextSpan(
                text: 'ownership history',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' of your vehicle'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            itemCount: OwnershipOption.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final o = OwnershipOption.all[i];
              return _OptionTile(
                label: o.label,
                fullWidth: true,
                onTap: () => onSelected(o.ownerNumber),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KmRangeQuestion extends StatelessWidget {
  const _KmRangeQuestion({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Select the ',
            style: theme.textTheme.headlineSmall,
            children: [
              TextSpan(
                text: 'kilometers driven',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' by your vehicle'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "You'll confirm the exact reading with an odometer photo later.",
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            itemCount: KmRangeBucket.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final b = KmRangeBucket.all[i];
              return _OptionTile(
                label: b.label,
                fullWidth: true,
                onTap: () => onSelected(b.representativeKm),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CityQuestion extends ConsumerStatefulWidget {
  const _CityQuestion({
    required this.searchController,
    required this.onSelected,
  });

  final TextEditingController searchController;
  final void Function(int id, String name) onSelected;

  @override
  ConsumerState<_CityQuestion> createState() => _CityQuestionState();
}

class _CityQuestionState extends ConsumerState<_CityQuestion> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final citiesAsync = ref.watch(citiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Select ',
            style: theme.textTheme.headlineSmall,
            children: [
              TextSpan(
                text: 'registration city',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' of your vehicle'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.searchController,
          decoration: const InputDecoration(
            hintText: 'Search your city...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: citiesAsync.when(
            data: (cities) {
              final query = widget.searchController.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? cities
                  : cities
                      .where((c) => c.name.toLowerCase().contains(query))
                      .toList();
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.3,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return _OptionTile(
                    label: c.name,
                    onTap: () => widget.onSelected(c.id, c.name),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load cities: $e'),
          ),
        ),
      ],
    );
  }
}

/// A single tappable option -- used for brand/model/city grid cells and for
/// full-width list rows (year/ownership/km-range).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Container(
          alignment: fullWidth ? Alignment.centerLeft : Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: fullWidth ? AppSpacing.md : AppSpacing.sm,
          ),
          child: Text(
            label,
            textAlign: fullWidth ? TextAlign.left : TextAlign.center,
            maxLines: fullWidth ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STEP 2 -- Price & Registration (city removed -- now asked in the Step 1
// Details wizard. This step is just price, description, and the private
// registration number.)
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
