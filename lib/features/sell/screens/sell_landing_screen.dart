import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../marketplace/models/vehicle.dart';
import '../../marketplace/widgets/category_chip.dart';
import '../../search/providers/lookup_providers.dart';
import '../models/vehicle_draft.dart';
import '../providers/sell_providers.dart';

/// Entry point for the Sell flow -- shown before the Details wizard.
/// Matches the reference flow's landing page (hero + quick brand picks)
/// minus the registration-number instant-lookup (we don't have a vehicle
/// registry API integration) and minus any Spinny-specific branding.
///
/// Tapping a brand pre-fills VehicleDraft and jumps straight to the
/// Model question (skipping the redundant re-confirmation the reference
/// flow has); the generic CTA starts the wizard fresh at the Brand
/// question.
class SellLandingScreen extends ConsumerStatefulWidget {
  const SellLandingScreen({super.key});

  @override
  ConsumerState<SellLandingScreen> createState() => _SellLandingScreenState();
}

class _SellLandingScreenState extends ConsumerState<SellLandingScreen> {
  VehicleCategory _category = VehicleCategory.car;

  void _startWizard({int? brandId, String? brandName}) {
    ref.read(vehicleDraftProvider.notifier).reset();
    ref.read(sellStepProvider.notifier).reset();
    ref.read(vehicleDraftProvider.notifier).update(
          (d) => VehicleDraft(
            category: _category,
            brandId: brandId,
            brandName: brandName,
          ),
        );
    context.push('/sell/details');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandsAsync = ref.watch(brandsForCategoryProvider(_category));

    return Scaffold(
      appBar: AppBar(title: const Text('Sell Your Vehicle')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Hero ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.directions_car_filled,
                      size: 56, color: theme.colorScheme.onPrimary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sell your vehicle at the best price',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'List in minutes. Reach thousands of verified buyers.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                ],
              ),
            ),

            // ---- Category toggle + quick brand picks ----
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryChip(
                        label: 'Car',
                        icon: Icons.directions_car_outlined,
                        isSelected: _category == VehicleCategory.car,
                        onTap: () =>
                            setState(() => _category = VehicleCategory.car),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      CategoryChip(
                        label: 'Bike',
                        icon: Icons.two_wheeler_outlined,
                        isSelected: _category == VehicleCategory.bike,
                        onTap: () =>
                            setState(() => _category = VehicleCategory.bike),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Select your brand', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  brandsAsync.when(
                    data: (brands) {
                      final quickPicks = brands.take(8).toList();
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: quickPicks.length,
                        itemBuilder: (context, i) {
                          final b = quickPicks[i];
                          return _BrandTile(
                            label: b.name,
                            onTap: () => _startWizard(
                                brandId: b.id, brandName: b.name),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Could not load brands: $e'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.secondary(
                    label: "Don't see your brand? Browse all",
                    onPressed: () => _startWizard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}
