import 'dart:math';
import '../utils/distance_calculator.dart';

class SpeedCalculator {
  /// Calculate speed between two points
  /// Returns speed in km/h
  static double calculateSpeed(
    LocationPoint point1,
    LocationPoint point2,
  ) {
    final distance = DistanceCalculator.calculateDistanceBetweenPoints(
      point1,
      point2,
    ); // in kilometers
    final timeDiff = point2.timestamp.difference(point1.timestamp);
    final hours = timeDiff.inSeconds / 3600.0;

    if (hours <= 0) return 0.0;

    return distance / hours; // km/h
  }

  /// Calculate average speed from a list of points
  static double calculateAverageSpeed(List<LocationPoint> points) {
    if (points.length < 2) return 0.0;

    final totalDistance = DistanceCalculator.calculateRouteDistance(points);
    final totalTime = points.last.timestamp.difference(points.first.timestamp);
    final hours = totalTime.inSeconds / 3600.0;

    if (hours <= 0) return 0.0;

    return totalDistance / hours; // km/h
  }

  /// Calculate instantaneous speed (using last 2-3 points for smoothing)
  static double calculateInstantaneousSpeed(List<LocationPoint> recentPoints) {
    if (recentPoints.length < 2) return 0.0;

    // Use last 2-3 points for more accurate instantaneous speed
    final points = recentPoints.length > 3
        ? recentPoints.sublist(recentPoints.length - 3)
        : recentPoints;

    return calculateAverageSpeed(points);
  }

  /// Smooth speed using moving average
  static double smoothSpeed(double currentSpeed, List<double> recentSpeeds) {
    recentSpeeds.add(currentSpeed);
    if (recentSpeeds.length > 5) {
      recentSpeeds.removeAt(0);
    }

    if (recentSpeeds.isEmpty) return 0.0;

    return recentSpeeds.reduce((a, b) => a + b) / recentSpeeds.length;
  }

  /// Calculate max speed from a list of points
  static double calculateMaxSpeed(List<LocationPoint> points) {
    if (points.length < 2) return 0.0;

    double maxSpeed = 0.0;
    for (int i = 1; i < points.length; i++) {
      final speed = calculateSpeed(points[i - 1], points[i]);
      if (speed > maxSpeed) {
        maxSpeed = speed;
      }
    }

    return maxSpeed;
  }

  /// Filter out unrealistic speeds (e.g., when stationary)
  static double? filterSpeed(double? speed, {double minSpeed = 1.0}) {
    if (speed == null) return null;
    if (speed < minSpeed) return 0.0;
    // Filter out speeds over 200 km/h (likely GPS error)
    if (speed > 200.0) return null;
    return speed;
  }

  /// Format speed for display
  static String formatSpeed(double speedKmh, {bool showUnit = true}) {
    final speed = speedKmh.round();
    return showUnit ? '$speed km/h' : speed.toString();
  }

  /// Convert km/h to m/s
  static double kmhToMs(double kmh) {
    return kmh / 3.6;
  }

  /// Convert m/s to km/h
  static double msToKmh(double ms) {
    return ms * 3.6;
  }
}

