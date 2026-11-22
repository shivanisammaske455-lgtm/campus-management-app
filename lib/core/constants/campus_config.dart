import 'package:geolocator/geolocator.dart';

/// Campus landmark point with nominal GPS coordinates.
class CampusLandmark {
  final String name;
  final double latitude;
  final double longitude;

  const CampusLandmark({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

/// Central configuration for college areas, landmarks, and location detection.
class CampusConfig {
  /// Default college domain.
  static const String collegeDomain = '@college.edu';

  /// Predefined campus areas shown as selection chips.
  static const List<String> defaultCampusAreas = [
    'Garden',
    'Library',
    'Hostel',
    'Block A',
    'Canteen',
    'Sports Complex',
    'Auditorium',
    'Admin Block',
    'Block B',
    'Parking Area',
  ];

  /// Nominal campus landmark GPS coordinates used to detect nearest area.
  /// (Sample campus coordinates - can be adjusted to specific campus boundary).
  static const List<CampusLandmark> campusLandmarks = [
    CampusLandmark(name: 'Garden', latitude: 12.9716, longitude: 77.5946),
    CampusLandmark(name: 'Library', latitude: 12.9720, longitude: 77.5950),
    CampusLandmark(name: 'Hostel', latitude: 12.9728, longitude: 77.5940),
    CampusLandmark(name: 'Block A', latitude: 12.9712, longitude: 77.5955),
    CampusLandmark(name: 'Canteen', latitude: 12.9718, longitude: 77.5938),
    CampusLandmark(name: 'Sports Complex', latitude: 12.9732, longitude: 77.5960),
    CampusLandmark(name: 'Auditorium', latitude: 12.9710, longitude: 77.5942),
    CampusLandmark(name: 'Admin Block', latitude: 12.9715, longitude: 77.5952),
  ];

  /// Calculates the nearest campus landmark to given GPS coordinates.
  static String findNearestArea(double latitude, double longitude) {
    if (campusLandmarks.isEmpty) return defaultCampusAreas.first;

    String nearest = campusLandmarks.first.name;
    double minDistance = double.infinity;

    for (final landmark in campusLandmarks) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        landmark.latitude,
        landmark.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = landmark.name;
      }
    }

    return nearest;
  }
}
