import 'package:flutter/foundation.dart';
import 'directions_service.dart';
import '../utils/location_utils.dart';

/// Service for calculating Estimated Time of Arrival (ETA)
/// Uses Google Directions API and current speed for accurate estimates
class EtaService {
  final DirectionsService _directionsService = DirectionsService();

  /// Calculate ETA from current location to destination
  /// 
  /// Returns ETA result with:
  /// - Estimated duration (minutes)
  /// - Estimated arrival time
  /// - Remaining distance (km)
  /// - Average speed (km/h)
  Future<EtaResult?> calculateETA({
    required double currentLat,
    required double currentLng,
    required double destinationLat,
    required double destinationLng,
    double? currentSpeed,
  }) async {
    try {
      final route = await _directionsService.getRoute(
        originLat: currentLat,
        originLng: currentLng,
        destLat: destinationLat,
        destLng: destinationLng,
      );

      if (route == null) {
        debugPrint('EtaService: No route found for ETA calculation');
        return null;
      }

      // Calculate ETA based on route duration and current speed
      final baseDuration = route.duration; // in minutes
      final distance = route.distance; // in km

      // Adjust ETA based on current speed if available
      double estimatedDuration = baseDuration;
      if (currentSpeed != null && currentSpeed > 0) {
        // Use current speed if significantly different from route average
        final routeAverageSpeed = distance / (baseDuration / 60); // km/h
        if ((currentSpeed - routeAverageSpeed).abs() > 10) {
          // Recalculate with current speed (but don't go below route minimum)
          final speedBasedDuration = (distance / currentSpeed) * 60; // minutes
          // Use the higher duration (more conservative estimate)
          estimatedDuration = speedBasedDuration > baseDuration 
              ? speedBasedDuration 
              : baseDuration * 0.9; // Slight adjustment for current conditions
        }
      }

      // Calculate estimated time of arrival
      final estimatedArrival = DateTime.now().add(Duration(minutes: estimatedDuration.round()));

      return EtaResult(
        estimatedDuration: estimatedDuration,
        estimatedArrival: estimatedArrival,
        distance: distance,
        averageSpeed: distance / (estimatedDuration / 60),
      );
    } catch (e) {
      debugPrint('EtaService: Error calculating ETA: $e');
      return null;
    }
  }

  /// Calculate route progress (0.0 to 1.0)
  /// 
  /// Returns progress percentage based on traveled distance vs total distance
  double calculateProgress({
    required double totalDistance,
    required double traveledDistance,
  }) {
    if (totalDistance <= 0) return 0.0;
    final progress = (traveledDistance / totalDistance).clamp(0.0, 1.0);
    return progress;
  }

  /// Format ETA duration for display
  /// 
  /// Returns formatted string like "15m", "1h 30m", etc.
  static String formatETA(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Format estimated arrival time for display
  /// 
  /// Returns formatted string like "10:30 AM", "2:15 PM", etc.
  static String formatArrivalTime(DateTime arrivalTime) {
    final hour = arrivalTime.hour;
    final minute = arrivalTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}

/// Result of ETA calculation
class EtaResult {
  final double estimatedDuration; // minutes
  final DateTime estimatedArrival;
  final double distance; // km
  final double averageSpeed; // km/h

  EtaResult({
    required this.estimatedDuration,
    required this.estimatedArrival,
    required this.distance,
    required this.averageSpeed,
  });

  /// Get formatted duration string
  String get formattedDuration => EtaService.formatETA(Duration(minutes: estimatedDuration.round()));

  /// Get formatted arrival time string
  String get formattedArrivalTime => EtaService.formatArrivalTime(estimatedArrival);

  /// Get formatted distance string
  String get formattedDistance => LocationUtils.formatDistance(distance);

  @override
  String toString() {
    return 'EtaResult(duration: ${estimatedDuration.toStringAsFixed(1)} min, '
        'arrival: $formattedArrivalTime, '
        'distance: ${distance.toStringAsFixed(2)} km, '
        'speed: ${averageSpeed.toStringAsFixed(1)} km/h)';
  }
}


