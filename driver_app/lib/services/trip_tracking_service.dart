import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/distance_calculator.dart';
import '../utils/location_utils.dart';
import '../utils/offline_storage.dart';
import 'location_service.dart';
import 'api_service.dart';

class TripTrackingService {
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();

  String? _currentTripId;
  bool _isTracking = false;
  LocationPoint? _startLocation;
  DateTime? _startTime;
  double _totalDistance = 0.0;
  final List<LocationPoint> _route = [];
  LocationPoint? _lastValidLocation; // Last location that was used for distance calculation
  double? _currentSpeed; // Current speed for filtering

  // Metrics
  double _maxSpeed = 0.0;
  double _averageSpeed = 0.0;
  Duration _duration = Duration.zero;
  
  // Constants for distance filtering
  static const double _minMovementDistance = 20.0; // meters - minimum distance to count as movement
  static const double _minSpeedForDistance = 2.0; // km/h - minimum speed to count distance (filters stationary noise)

  // Location batching for efficient API calls
  final List<LocationPoint> _pendingLocations = [];
  Timer? _batchUploadTimer;
  static const Duration _batchUploadInterval = Duration(seconds: 30); // Upload every 30 seconds
  static const int _maxBatchSize = 50; // Max locations per batch
  bool _isUploadingBatch = false;

  // Callbacks
  Function(double distance)? onDistanceUpdate;
  Function(double? speed)? onSpeedUpdate;
  Function(Duration duration)? onDurationUpdate;
  Function(bool isOnline)? onConnectionStatusChanged;

  bool get isTracking => _isTracking;
  String? get currentTripId => _currentTripId;
  double get totalDistance => _totalDistance;
  double get maxSpeed => _maxSpeed;
  double get averageSpeed => _averageSpeed;
  Duration get duration => _duration;
  List<LocationPoint> get route => List.unmodifiable(_route);

  /// Start tracking a trip
  Future<bool> startTrip(String tripId, {double? startLat, double? startLng}) async {
    if (_isTracking) {
      await stopTrip();
    }

    _currentTripId = tripId;
    _isTracking = true;
    _totalDistance = 0.0;
    _maxSpeed = 0.0;
    _averageSpeed = 0.0;
    _duration = Duration.zero;
    _route.clear();
    _lastValidLocation = null;
    _currentSpeed = null;

    // Get start location
    if (startLat != null && startLng != null) {
      _startLocation = LocationPoint(
        lat: startLat,
        lng: startLng,
        timestamp: DateTime.now(),
      );
    } else {
      final currentLoc = await _locationService.getCurrentLocation();
      if (currentLoc == null) {
        _isTracking = false;
        return false;
      }
      _startLocation = currentLoc;
    }

    _startTime = DateTime.now();
    _route.add(_startLocation!);
    _lastValidLocation = _startLocation; // Initialize last valid location
    _currentSpeed = null; // Reset speed

    // Clear pending locations and start batch upload timer
    _pendingLocations.clear();
    _startBatchUploadTimer();

    // Setup location tracking callbacks
    _locationService.onLocationUpdate = _handleLocationUpdate;
    _locationService.onSpeedUpdate = _handleSpeedUpdate;

    // Start location tracking
    final started = await _locationService.startTracking(tripId: tripId);
    if (!started) {
      _isTracking = false;
      _batchUploadTimer?.cancel();
      return false;
    }

    // Start duration timer
    _startDurationTimer();

    // Upload initial location immediately
    _pendingLocations.add(_startLocation!);
    _uploadLocationBatch();

    return true;
  }

  /// Stop tracking
  Future<void> stopTrip() async {
    if (!_isTracking) {
      // Even if not tracking, ensure distance is reset
      _totalDistance = 0.0;
      _route.clear();
      _lastValidLocation = null;
      _currentSpeed = null;
      return;
    }

    _locationService.stopTracking();
    _stopDurationTimer();

    // Stop batch upload timer
    _batchUploadTimer?.cancel();
    _batchUploadTimer = null;

    // Upload any pending locations before stopping
    if (_pendingLocations.isNotEmpty) {
      await _uploadLocationBatch();
    }

    // Calculate final metrics using the full route
    // Recalculate distance from route to ensure accuracy (this handles any filtering issues)
    if (_route.length >= 2) {
      // Use the accumulated distance (which was filtered) as primary
      // But also recalculate from route for validation
      final recalculatedDistance = DistanceCalculator.calculateRouteDistance(_route);
      
      debugPrint('TripTrackingService: Stopping trip - Filtered distance: $_totalDistance km, Recalculated: $recalculatedDistance km');
      
      // Use the filtered distance (which should be more accurate) if available
      // Otherwise use recalculated distance
      if (_totalDistance > 0) {
        // Filtered distance is primary, but validate it's reasonable
        // If recalculated is significantly larger, it means we may have filtered too aggressively
        // BUT: If recalculated is suspiciously high (> 100 km), it's likely GPS noise, so keep filtered
        if (recalculatedDistance > _totalDistance * 1.5 && recalculatedDistance < 100) {
          // Recalculated is much larger but reasonable - might have filtered too much, use recalculated
          debugPrint('TripTrackingService: Using recalculated distance (filtered too aggressively)');
          _totalDistance = recalculatedDistance;
        } else if (recalculatedDistance > 100) {
          // Recalculated is suspiciously high - likely GPS noise, keep filtered distance
          debugPrint('TripTrackingService: Recalculated distance ($recalculatedDistance km) is suspiciously high. Keeping filtered distance ($_totalDistance km).');
        }
        // Otherwise keep filtered distance (it's more accurate for filtering noise)
      } else {
        // No filtered distance, use recalculated (but validate it's reasonable)
        if (recalculatedDistance < 1000) {
          _totalDistance = recalculatedDistance;
        } else {
          debugPrint('TripTrackingService: WARNING - Recalculated distance ($recalculatedDistance km) is suspiciously high. Setting to 0.');
          _totalDistance = 0.0;
        }
      }
      
      if (_startTime != null) {
        _duration = DateTime.now().difference(_startTime!);
        if (_duration.inHours > 0 || _totalDistance > 0) {
          final hours = _duration.inSeconds / 3600.0;
          _averageSpeed = hours > 0 ? _totalDistance / hours : 0.0;
        }
      }
    } else {
      // No route points, ensure distance is 0
      _totalDistance = 0.0;
    }

    _isTracking = false;
    _lastValidLocation = null;
    _currentSpeed = null;
    _route.clear(); // Clear route when stopping
    _totalDistance = 0.0; // Explicitly reset distance
    _pendingLocations.clear(); // Clear pending locations
    debugPrint('TripTrackingService: Trip stopped - Distance reset to 0.0');
  }

  /// Start batch upload timer
  void _startBatchUploadTimer() {
    _batchUploadTimer?.cancel();
    _batchUploadTimer = Timer.periodic(_batchUploadInterval, (_) {
      if (_pendingLocations.isNotEmpty && !_isUploadingBatch) {
        _uploadLocationBatch();
      }
    });
  }

  /// Upload location batch to backend
  Future<void> _uploadLocationBatch() async {
    if (_pendingLocations.isEmpty || _currentTripId == null || _isUploadingBatch) {
      return;
    }

    final locationsToUpload = List<LocationPoint>.from(_pendingLocations);
    _pendingLocations.clear();
    _isUploadingBatch = true;

    try {
      // Convert to API format
      final locations = locationsToUpload.map((loc) => {
        'lat': loc.lat,
        'lng': loc.lng,
        'timestamp': loc.timestamp.toIso8601String(),
      }).toList();

      // Upload batch to backend
      await _apiService.batchUpdateLocation(_currentTripId!, locations);

      debugPrint('TripTrackingService: Uploaded ${locations.length} locations to backend');
    } catch (e) {
      debugPrint('TripTrackingService: Error uploading location batch: $e');
      // Re-add to pending if upload fails (but limit size to prevent memory issues)
      _pendingLocations.insertAll(0, locationsToUpload);
      if (_pendingLocations.length > 200) {
        // Keep only last 200 locations
        _pendingLocations.removeRange(0, _pendingLocations.length - 200);
        debugPrint('TripTrackingService: Limited pending locations to 200 to prevent memory issues');
      }
    } finally {
      _isUploadingBatch = false;
    }
  }

  /// Update location (called by LocationService)
  void _handleLocationUpdate(LocationPoint point) {
    if (!_isTracking) return;

    // Always add to route for tracking purposes
    _route.add(point);

    // Calculate distance increment with filtering to prevent GPS noise accumulation
    if (_lastValidLocation != null) {
      // Calculate distance in kilometers
      final segmentDistanceKm = DistanceCalculator.calculateDistanceBetweenPoints(
        _lastValidLocation!,
        point,
      );
      
      // Convert to meters
      final segmentDistanceM = DistanceCalculator.kmToMeters(segmentDistanceKm);
      
      // Filter conditions:
      // 1. Movement must be >= minimum distance threshold (filters small GPS drift)
      // 2. Speed must be >= minimum speed OR we're definitely moving (filters stationary noise)
      // 3. If speed is unknown but distance is significant, count it (handles initial movement)
      final shouldCountDistance = segmentDistanceM >= _minMovementDistance &&
          (_currentSpeed == null || 
           _currentSpeed! >= _minSpeedForDistance || 
           segmentDistanceM >= (_minMovementDistance * 2)); // Allow larger movements even if speed is low
      
      if (shouldCountDistance) {
        // Only count this distance and update last valid location
        // Add sanity check: if segment distance is suspiciously large (> 10 km), it's likely GPS error
        if (segmentDistanceKm > 10.0) {
          debugPrint('TripTrackingService: WARNING - Segment distance ($segmentDistanceKm km) is suspiciously large. Likely GPS error. Ignoring.');
          // Don't count this segment, but update last valid location to current point
          _lastValidLocation = point;
        } else {
          _totalDistance += segmentDistanceKm;
          _lastValidLocation = point;
          
          // Sanity check: if total distance becomes suspiciously high, log warning
          if (_totalDistance > 100) {
            debugPrint('TripTrackingService: WARNING - Total distance ($_totalDistance km) is very high. This may indicate GPS noise accumulation.');
          }
          
          onDistanceUpdate?.call(_totalDistance);
          
          // Add to pending locations for batch upload (only if distance is counted)
          _pendingLocations.add(point);
          
          // Upload batch if it reaches max size
          if (_pendingLocations.length >= _maxBatchSize && !_isUploadingBatch) {
            _uploadLocationBatch();
          }
        }
      } else {
        // Even if distance is not counted, add to pending locations for route tracking
        // This ensures the route is complete even if some segments are filtered
        _pendingLocations.add(point);
      }
      // If distance is too small or speed is too low, don't count it but keep the point in route
      // This prevents GPS noise from accumulating false distance
    } else {
      // First location after start - use it as last valid location
      _lastValidLocation = point;
      // Add to pending locations
      _pendingLocations.add(point);
    }

    // Periodically recalculate distance from route to avoid accumulation errors
    // This ensures accuracy over time by recalculating from the smoothed route
    // BUT: Only do this if distance is reasonable, otherwise it might be GPS noise
    if (_route.length % 50 == 0 && _route.length > 10) {
      // Recalculate total distance from route every 50 points
      // This helps correct for any accumulated errors
      final recalculatedDistance = DistanceCalculator.calculateRouteDistance(_route);
      final difference = (recalculatedDistance - _totalDistance).abs();
      
      // Only use recalculated distance if:
      // 1. There's a significant difference (> 100m)
      // 2. The recalculated distance is reasonable (not suspiciously high)
      // 3. The recalculated distance is not much larger than current (might be GPS noise)
      if (difference > 0.1 && // 0.1 km = 100 meters
          recalculatedDistance < 1000 && // Sanity check: not more than 1000 km
          recalculatedDistance <= _totalDistance * 2) { // Not more than 2x current (likely noise)
        _totalDistance = recalculatedDistance;
        onDistanceUpdate?.call(_totalDistance);
      } else if (recalculatedDistance > 100) {
        // If recalculated distance is suspiciously high, log warning but don't use it
        debugPrint('TripTrackingService: WARNING - Recalculated distance ($recalculatedDistance km) is suspiciously high. Current filtered distance: $_totalDistance km');
        debugPrint('TripTrackingService: This suggests GPS noise. Keeping filtered distance.');
      }
    }

    // Update duration
    if (_startTime != null) {
      _duration = DateTime.now().difference(_startTime!);
      onDurationUpdate?.call(_duration);
    }
  }

  /// Update speed (called by LocationService)
  void _handleSpeedUpdate(double? speed) {
    // Store current speed for distance filtering
    _currentSpeed = speed;
    
    if (speed != null && speed > _maxSpeed) {
      _maxSpeed = speed;
    }
    onSpeedUpdate?.call(speed);
  }

  /// Check if returned to origin
  bool checkReturnedToOrigin(double originLat, double originLng, {double radiusMeters = 50}) {
    if (_route.isEmpty) return false;

    final lastPoint = _route.last;
    return LocationUtils.isWithinRadius(
      lastPoint.lat,
      lastPoint.lng,
      originLat,
      originLng,
      radiusMeters,
    );
  }

  /// Get trip metrics
  Map<String, dynamic> getTripMetrics() {
    return {
      'distance': _totalDistance,
      'duration': _duration.inMinutes,
      'averageSpeed': _averageSpeed,
      'maxSpeed': _maxSpeed,
      'routePoints': _route.length,
      'startTime': _startTime?.toIso8601String(),
      'endTime': DateTime.now().toIso8601String(),
    };
  }

  /// Sync offline locations to server
  Future<void> syncOfflineLocations() async {
    if (_currentTripId == null) return;

    final unsynced = await OfflineStorage.getUnsyncedLocations(tripId: _currentTripId);
    if (unsynced.isEmpty) return;

    try {
      // Prepare batch data
      final locations = unsynced.map((loc) => {
        'lat': loc['lat'] as double,
        'lng': loc['lng'] as double,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(loc['timestamp'] as int).toIso8601String(),
      }).toList();

      // Upload batch
      await _apiService.batchUpdateLocation(_currentTripId!, locations);

      // Mark as synced
      final ids = unsynced.map((loc) => loc['id'] as int).toList();
      await OfflineStorage.markLocationsAsSynced(ids);
    } catch (e) {
      // Will retry on next sync
    }
  }

  Timer? _durationTimer;

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        _duration = DateTime.now().difference(_startTime!);
        onDurationUpdate?.call(_duration);
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Dispose resources
  void dispose() {
    stopTrip();
    _locationService.dispose();
    _durationTimer?.cancel();
  }
}

