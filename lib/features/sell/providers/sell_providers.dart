import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sell_repository.dart';
import '../models/vehicle_draft.dart';

final sellRepositoryProvider = Provider<SellRepository>((ref) => SellRepository());

class VehicleDraftNotifier extends Notifier<VehicleDraft> {
  @override
  VehicleDraft build() => const VehicleDraft();

  void update(VehicleDraft Function(VehicleDraft) updater) => state = updater(state);

  void reset() => state = const VehicleDraft();
}

final vehicleDraftProvider = NotifierProvider<VehicleDraftNotifier, VehicleDraft>(VehicleDraftNotifier.new);

/// Which of the 4 steps (0-3) is currently shown.
class SellStepNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void next() => state = (state + 1).clamp(0, 3);
  void back() => state = (state - 1).clamp(0, 3);
  void reset() => state = 0;
}

final sellStepProvider = NotifierProvider<SellStepNotifier, int>(SellStepNotifier.new);
