import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

enum LocationPermissionOutcome {
  granted,
  deniedOnce,
  deniedForever,
  serviceDisabled,
}

/// Thin wrapper around geolocator + geocoding. Uses the device's native
/// geocoder (free, no API key) to turn GPS coordinates into a locality
/// name, which the caller then matches against the `cities` table.
class LocationService {
  Future<LocationPermissionOutcome> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionOutcome.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionOutcome.deniedOnce;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionOutcome.deniedForever;
    }
    return LocationPermissionOutcome.granted;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reverse-geocodes to a city/locality name, or null if unavailable.
  /// Falls back to subAdministrativeArea if locality is empty (some rural
  /// coordinates only resolve to a district-level name).
  Future<String?> reverseGeocodeCity(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      if (place.locality != null && place.locality!.isNotEmpty) {
        return place.locality;
      }
      return place.subAdministrativeArea;
    } catch (_) {
      return null;
    }
  }
}
