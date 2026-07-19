import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
// ASSUMPTION: citiesProvider and the City model live here, per usage seen
// in the Sell flow's city question. Adjust the import/type name if they
// actually live elsewhere.
import '../../search/providers/lookup_providers.dart';

const _kSelectedCityPrefsKey = 'selected_city_id';

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

enum LocationResolutionStatus {
  resolved,
  alreadySet,
  needsManualPick,
  permissionDenied,
}

/// The user's active city for filtering the home feed. Null means "not
/// yet resolved — show all / prompt for manual pick." Persisted across
/// launches via shared_preferences.
class SelectedCityNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSelectedCityPrefsKey);
  }

  Future<void> setCity(int? cityId) async {
    final prefs = await SharedPreferences.getInstance();
    if (cityId == null) {
      await prefs.remove(_kSelectedCityPrefsKey);
    } else {
      await prefs.setInt(_kSelectedCityPrefsKey, cityId);
    }
    state = AsyncData(cityId);
  }

  /// Attempts automatic city resolution via GPS + reverse geocoding, but
  /// only if no city has been selected/persisted yet — call this once,
  /// e.g. from the home screen's initState. Safe to call repeatedly; it's
  /// a no-op once a city is set (manually or automatically).
  Future<LocationResolutionStatus> resolveFromDeviceLocation() async {
    // Make sure build() has settled before checking the current value.
    final existing = await future;
    if (existing != null) return LocationResolutionStatus.alreadySet;

    final service = ref.read(locationServiceProvider);
    final permission = await service.requestPermission();
    if (permission != LocationPermissionOutcome.granted) {
      return LocationResolutionStatus.permissionDenied;
    }

    final position = await service.getCurrentPosition();
    if (position == null) return LocationResolutionStatus.needsManualPick;

    final localityName = await service.reverseGeocodeCity(position);
    if (localityName == null) return LocationResolutionStatus.needsManualPick;

    final cities = await ref.read(citiesProvider.future);
    final normalized = localityName.toLowerCase();

    // Exact match first, then fall back to a loose substring match (e.g.
    // reverse geocoder returns "Greater Hyderabad" but our table has
    // "Hyderabad").
    final resolved = _findCityMatch(cities, normalized);

    if (resolved == null) return LocationResolutionStatus.needsManualPick;

    await setCity(resolved);
    return LocationResolutionStatus.resolved;
  }
}

/// Returns the matching city's id, or null. Kept generic over the actual
/// city list type (whatever citiesProvider returns) via duck-typed access
/// to .name/.id, avoiding a dependency on the exact model class name.
int? _findCityMatch(List cities, String normalizedLocality) {
  for (final c in cities) {
    if ((c.name as String).toLowerCase() == normalizedLocality) {
      return c.id as int;
    }
  }
  for (final c in cities) {
    final cName = (c.name as String).toLowerCase();
    if (cName.contains(normalizedLocality) ||
        normalizedLocality.contains(cName)) {
      return c.id as int;
    }
  }
  return null;
}

final selectedCityIdProvider =
    AsyncNotifierProvider<SelectedCityNotifier, int?>(SelectedCityNotifier.new);

/// Display name for the header's city selector -- "All India" when no
/// city is set (location not yet resolved, or user hasn't picked one).
final selectedCityNameProvider = FutureProvider<String>((ref) async {
  final cityId = await ref.watch(selectedCityIdProvider.future);
  if (cityId == null) return 'All India';

  final cities = await ref.watch(citiesProvider.future);
  for (final c in cities) {
    if (c.id == cityId) return c.name;
  }
  return 'All India';
});
