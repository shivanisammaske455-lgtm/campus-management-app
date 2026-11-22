import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants/campus_config.dart';

/// Riverpod provider for LocationService.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Result wrapper for GPS detection with friendly permission diagnostics.
class CampusLocationResult {
  final bool isSuccess;
  final Position? position;
  final String? nearestArea;
  final String? userMessage;

  const CampusLocationResult({
    required this.isSuccess,
    this.position,
    this.nearestArea,
    this.userMessage,
  });
}

class LocationService {
  /// Checks permissions, requests if needed, gets GPS position,
  /// and resolves the nearest campus area name.
  Future<CampusLocationResult> detectNearestCampusArea() async {
    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const CampusLocationResult(
        isSuccess: false,
        userMessage:
            'Location services are turned off. Please turn on GPS or select your campus area from the chips below.',
      );
    }

    // 2. Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const CampusLocationResult(
          isSuccess: false,
          userMessage:
              'Location permission was not granted. No worries, you can tap a campus area chip below to set your location.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const CampusLocationResult(
        isSuccess: false,
        userMessage:
            'Location permission is permanently disabled in device settings. Please pick your campus area from the chips below.',
      );
    }

    // 3. Acquire current location
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final nearestArea = CampusConfig.findNearestArea(
        position.latitude,
        position.longitude,
      );

      return CampusLocationResult(
        isSuccess: true,
        position: position,
        nearestArea: nearestArea,
        userMessage: 'Nearest area detected: $nearestArea',
      );
    } catch (e) {
      return const CampusLocationResult(
        isSuccess: false,
        userMessage:
            'Could not determine GPS coordinates right now. Please select your area manually below.',
      );
    }
  }
}
