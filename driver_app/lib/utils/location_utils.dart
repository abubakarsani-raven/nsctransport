import 'dart:math';
import 'distance_calculator.dart';

class LocationUtils {
  /// Check if two locations are within a certain distance (in kilometers)
  static bool isWithinDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double distanceKm,
  ) {
    final distance = DistanceCalculator.calculateDistance(
      lat1,
      lng1,
      lat2,
      lng2,
    );
    return distance <= distanceKm;
  }

  /// Check if location is within radius of target (in meters)
  static bool isWithinRadius(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double radiusMeters,
  ) {
    final distanceKm = radiusMeters / 1000.0;
    return isWithinDistance(lat1, lng1, lat2, lng2, distanceKm);
  }

  /// Format distance for display
  static String formatDistance(double distanceKm, {bool showUnit = true}) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return showUnit ? '$meters m' : meters.toString();
    } else if (distanceKm < 10.0) {
      return showUnit ? '${distanceKm.toStringAsFixed(2)} km' : distanceKm.toStringAsFixed(2);
    } else {
      return showUnit ? '${distanceKm.toStringAsFixed(1)} km' : distanceKm.toStringAsFixed(1);
    }
  }

  /// Calculate bearing between two points (in degrees)
  static double calculateBearing(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLon = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final y = sin(dLon) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  /// Validate latitude
  static bool isValidLatitude(double lat) {
    return lat >= -90 && lat <= 90;
  }

  /// Validate longitude
  static bool isValidLongitude(double lng) {
    return lng >= -180 && lng <= 180;
  }

  /// Validate coordinates
  static bool isValidCoordinates(double lat, double lng) {
    return isValidLatitude(lat) && isValidLongitude(lng);
  }

  static double _toRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  static double _toDegrees(double radians) {
    return radians * (180.0 / pi);
  }
}

