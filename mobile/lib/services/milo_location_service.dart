import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MiloLocationService {
  MiloLocationService._();
  static final MiloLocationService instance = MiloLocationService._();

  /// Requests permission and returns the detected city name or null if failed/denied.
  Future<String?> detectCurrentCity() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('MiloLocation: Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('MiloLocation: Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('MiloLocation: Location permission permanently denied.');
        return null;
      }

      // Fetch current GPS position (with a timeout of 10 seconds)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Reverse geocode to find the city / locality
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Priority: locality (City) -> subAdministrativeArea -> administrativeArea (State)
        final city = place.locality?.trim().isNotEmpty == true
            ? place.locality!
            : place.subAdministrativeArea?.trim().isNotEmpty == true
                ? place.subAdministrativeArea!
                : place.administrativeArea;

        debugPrint('MiloLocation: Detected city = $city (${position.latitude}, ${position.longitude})');
        return city;
      }
    } catch (e) {
      debugPrint('MiloLocation error during detection: $e');
    }
    return null;
  }
}
