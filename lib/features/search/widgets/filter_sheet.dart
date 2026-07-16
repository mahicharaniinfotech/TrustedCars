import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../marketplace/models/vehicle.dart';
import '../providers/lookup_providers.dart';
import '../providers/search_providers.dart';
import '../models/vehicle_filter.dart';

/// Opens the filter sheet. Changes are staged locally and only committed
/// to searchFilterProvider when the user taps Apply -- so backing out
/// (swipe down / tap outside) doesn't leave a half-edited filter active.
Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _FilterSheetContent(),
  );
}

class _FilterSheetContent extends ConsumerStatefulWidget {
  const _FilterSheetContent();

  @override
  ConsumerState<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends ConsumerState<_FilterSheetContent> {
  late VehicleFilter _draft;

  static const double _priceMax = 5000000;
  static const int _yearMin = 2005;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(searchFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandsAsync = ref.watch(brandsForCategoryProvider(_draft.category));
    final citiesAsync = ref.watch(citiesProvider);
    final currentYear = DateTime.now().year;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: theme.textTheme.displayMedium),
                  TextButton(
                    onPressed: () => setState(() => _draft = _draft.clearAllFilters()),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text('Brand', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    brandsAsync.when(
                      data: (brands) => DropdownButtonFormField<int?>(
                        initialValue: _draft.brandId,
                        hint: const Text('Any brand'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Any brand')),
                          ...brands.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                        ],
                        onChanged: (value) => setState(
                          () => _draft = value == null
                              ? _draft.copyWith(clearBrandId: true)
                              : _draft.copyWith(brandId: value),
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Could not load brands', style: theme.textTheme.bodySmall),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    Text('City', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    citiesAsync.when(
                      data: (cities) => DropdownButtonFormField<int?>(
                        initialValue: _draft.cityId,
                        hint: const Text('Any city'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Any city')),
                          ...cities.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (value) => setState(
                          () => _draft = value == null
                              ? _draft.copyWith(clearCityId: true)
                              : _draft.copyWith(cityId: value),
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Could not load cities', style: theme.textTheme.bodySmall),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    Text('Fuel Type', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: FuelType.values.map((fuel) {
                        final selected = _draft.fuelType == fuel;
                        return ChoiceChip(
                          label: Text(fuel.name[0].toUpperCase() + fuel.name.substring(1)),
                          selected: selected,
                          onSelected: (isSelected) => setState(
                            () => _draft = isSelected
                                ? _draft.copyWith(fuelType: fuel)
                                : _draft.copyWith(clearFuelType: true),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    Text('Transmission', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: TransmissionType.values.map((t) {
                        final selected = _draft.transmission == t;
                        return ChoiceChip(
                          label: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                          selected: selected,
                          onSelected: (isSelected) => setState(
                            () => _draft = isSelected
                                ? _draft.copyWith(transmission: t)
                                : _draft.copyWith(clearTransmission: true),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Price range: ₹${((_draft.minPrice ?? 0) / 100000).toStringAsFixed(1)}L '
                      '– ₹${((_draft.maxPrice ?? _priceMax) / 100000).toStringAsFixed(1)}L',
                      style: theme.textTheme.labelLarge,
                    ),
                    RangeSlider(
                      min: 0,
                      max: _priceMax,
                      divisions: 50,
                      values: RangeValues(_draft.minPrice ?? 0, _draft.maxPrice ?? _priceMax),
                      onChanged: (values) => setState(
                        () => _draft = _draft.copyWith(minPrice: values.start, maxPrice: values.end),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Year: ${_draft.minYear ?? _yearMin} – ${_draft.maxYear ?? currentYear}',
                      style: theme.textTheme.labelLarge,
                    ),
                    RangeSlider(
                      min: _yearMin.toDouble(),
                      max: currentYear.toDouble(),
                      divisions: currentYear - _yearMin,
                      values: RangeValues(
                        (_draft.minYear ?? _yearMin).toDouble(),
                        (_draft.maxYear ?? currentYear).toDouble(),
                      ),
                      onChanged: (values) => setState(
                        () => _draft = _draft.copyWith(
                          minYear: values.start.round(),
                          maxYear: values.end.round(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
              AppButton.primary(
                label: 'Apply Filters',
                onPressed: () {
                  ref.read(searchFilterProvider.notifier).update((_) => _draft);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
