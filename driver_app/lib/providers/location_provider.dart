import 'package:flutter/foundation.dart';
import '../services/location_service.dart';
import '../utils/distance_calculator.dart';
import '../utils/location_utils.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();

  bool _hasPermission = false;
  bool _isTracking = false;
  LocationPoint? _currentLocation;
  double? _currentSpeed;
  double? _currentBearing;

  bool get hasPermission => _hasPermission;
  bool get isTracking => _isTracking;
  LocationPoint? get currentLocation => _currentLocation;
  double? get currentSpeed => _currentSpeed;
  double? get currentBearing => _currentBearing;

  LocationProvider() {
    _locationService.onLocationUpdate = (point) {
      // Calculate bearing if we have previous location
      if (_currentLocation != null) {
        _currentBearing = LocationUtils.calculateBearing(
          _currentLocation!.lat,
          _currentLocation!.lng,
          point.lat,
          point.lng,
        );
      }
      _currentLocation = point;
      notifyListeners();
    };

    _locationService.onSpeedUpdate = (speed) {
      _currentSpeed = speed;
      notifyListeners();
    };

    _locationService.onPermissionChanged = (hasPermission) {
      _hasPermission = hasPermission;
      notifyListeners();
    };
  }

  Future<bool> checkAndRequestPermissions() async {
    _hasPermission = await _locationService.checkAndRequestPermissions();
    notifyListeners();
    return _hasPermission;
  }

  Future<LocationPoint?> getCurrentLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      _currentLocation = location;
      notifyListeners();
    }
    return location;
  }

  Future<bool> startTracking({String? tripId}) async {
    final started = await _locationService.startTracking(tripId: tripId);
    if (started) {
      _isTracking = true;
      notifyListeners();
    }
    return started;
  }

  void stopTracking() {
    _locationService.stopTracking();
    _isTracking = false;
    notifyListeners();
  }

  double? getCurrentSpeed() {
    return _locationService.getCurrentSpeed();
  }

  double getAverageSpeed() {
    return _locationService.getAverageSpeed();
  }

  double getMaxSpeed() {
    return _locationService.getMaxSpeed();
  }

  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}

