import 'dart:math';

class LocationPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;

  LocationPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });
}

class DistanceCalculator {
  // Earth's radius in kilometers
  static const double earthRadius = 6371.0;

  /// Calculate distance between two points using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate distance between two LocationPoint objects
  static double calculateDistanceBetweenPoints(
    LocationPoint point1,
    LocationPoint point2,
  ) {
    return calculateDistance(
      point1.lat,
      point1.lng,
      point2.lat,
      point2.lng,
    );
  }

  /// Calculate total distance of a route
  /// Returns distance in kilometers
  static double calculateRouteDistance(List<LocationPoint> route) {
    if (route.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < route.length; i++) {
      totalDistance += calculateDistanceBetweenPoints(
        route[i - 1],
        route[i],
      );
    }

    return totalDistance;
  }

  /// Calculate cumulative distance from a list of points
  /// Returns list of cumulative distances in kilometers
  static List<double> calculateCumulativeDistances(List<LocationPoint> route) {
    if (route.isEmpty) return [];
    if (route.length == 1) return [0.0];

    final cumulativeDistances = <double>[0.0];
    double totalDistance = 0.0;

    for (int i = 1; i < route.length; i++) {
      final segmentDistance = calculateDistanceBetweenPoints(
        route[i - 1],
        route[i],
      );
      totalDistance += segmentDistance;
      cumulativeDistances.add(totalDistance);
    }

    return cumulativeDistances;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Convert kilometers to meters
  static double kmToMeters(double kilometers) {
    return kilometers * 1000;
  }

  /// Convert meters to kilometers
  static double metersToKm(double meters) {
    return meters / 1000;
  }
}

