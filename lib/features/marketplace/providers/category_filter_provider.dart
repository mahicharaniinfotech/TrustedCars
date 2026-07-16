import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';

/// Which category tab is selected on the home screen. Cars by default --
/// bikes/commercial are schema-ready (see migration 004's vehicle_category
/// enum) but have no listings yet since Sell Vehicle (Sprint 5) isn't built.
///
/// Uses Riverpod 3's Notifier API rather than the legacy StateProvider
/// (moved to package:flutter_riverpod/legacy.dart in 3.0 and discouraged
/// going forward).
class SelectedCategoryNotifier extends Notifier<VehicleCategory> {
  @override
  VehicleCategory build() => VehicleCategory.car;

  void select(VehicleCategory category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, VehicleCategory>(SelectedCategoryNotifier.new);
