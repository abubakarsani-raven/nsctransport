import 'dart:async';
import 'package:location/location.dart' as loc;
import '../utils/distance_calculator.dart';
import '../utils/offline_storage.dart';
import 'speed_calculator.dart';

class LocationService {
  final loc.Location _location = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;
  bool _isTracking = false;
  bool _hasPermission = false;

  LocationPoint? _lastLocation;
  final List<LocationPoint> _locationHistory = [];
  final List<double> _recentSpeeds = [];

  // Callbacks
  Function(LocationPoint)? onLocationUpdate;
  Function(double?)? onSpeedUpdate;
  Function(bool)? onPermissionChanged;

  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  LocationPoint? get lastLocation => _lastLocation;
  List<LocationPoint> get locationHistory => List.unmodifiable(_locationHistory);

  /// Check and request location permissions
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        _hasPermission = false;
        onPermissionChanged?.call(false);
        return false;
      }
    }

    loc.PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
    }

    _hasPermission = permissionGranted == loc.PermissionStatus.granted;
    onPermissionChanged?.call(_hasPermission);
    return _hasPermission;
  }

  /// Get current location once
  Future<LocationPoint?> getCurrentLocation() async {
    if (!_hasPermission) {
      final hasPerm = await checkAndRequestPermissions();
      if (!hasPerm) return null;
    }

    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) {
        return null;
      }

      return LocationPoint(
        lat: locationData.latitude!,
        lng: locationData.longitude!,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          locationData.time?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Start continuous location tracking
  Future<bool> startTracking({
    String? tripId,
    Duration interval = const Duration(seconds: 5),
    double distanceFilter = 25.0, // meters - increased to reduce GPS noise
  }) async {
    if (_isTracking) return true;

    if (!_hasPermission) {
      final hasPerm = await checkAndRequestPermissions();
      if (!hasPerm) return false;
    }

    _isTracking = true;

    // Configure location settings
    await _location.changeSettings(
      interval: interval.inMilliseconds,
      distanceFilter: distanceFilter,
    );

    _locationSubscription = _location.onLocationChanged.listen((locationData) async {
      if (locationData.latitude == null || locationData.longitude == null) {
        return;
      }

      final currentPoint = LocationPoint(
        lat: locationData.latitude!,
        lng: locationData.longitude!,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          locationData.time?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Calculate speed if we have previous location
      double? speed;
      if (_lastLocation != null) {
        speed = SpeedCalculator.calculateSpeed(_lastLocation!, currentPoint);
        speed = SpeedCalculator.filterSpeed(speed);
        if (speed != null) {
          _recentSpeeds.add(speed);
          if (_recentSpeeds.length > 10) {
            _recentSpeeds.removeAt(0);
          }
          onSpeedUpdate?.call(speed);
        }
      }

      // Save to history
      _locationHistory.add(currentPoint);
      if (_locationHistory.length > 1000) {
        _locationHistory.removeAt(0);
      }

      // Save to offline storage
      await OfflineStorage.saveLocation(
        tripId: tripId,
        lat: currentPoint.lat,
        lng: currentPoint.lng,
        timestamp: currentPoint.timestamp,
        speed: speed,
        accuracy: locationData.accuracy,
      );

      _lastLocation = currentPoint;
      onLocationUpdate?.call(currentPoint);
    });

    return true;
  }

  /// Stop location tracking
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isTracking = false;
  }

  /// Get current speed (instantaneous)
  double? getCurrentSpeed() {
    if (_locationHistory.length < 2) return null;
    final recentPoints = _locationHistory.length > 3
        ? _locationHistory.sublist(_locationHistory.length - 3)
        : _locationHistory;
    return SpeedCalculator.calculateInstantaneousSpeed(recentPoints);
  }

  /// Get average speed
  double getAverageSpeed() {
    if (_locationHistory.length < 2) return 0.0;
    return SpeedCalculator.calculateAverageSpeed(_locationHistory);
  }

  /// Get max speed
  double getMaxSpeed() {
    if (_recentSpeeds.isEmpty) return 0.0;
    return _recentSpeeds.reduce((a, b) => a > b ? a : b);
  }

  /// Clear location history
  void clearHistory() {
    _locationHistory.clear();
    _recentSpeeds.clear();
    _lastLocation = null;
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    clearHistory();
  }
}

