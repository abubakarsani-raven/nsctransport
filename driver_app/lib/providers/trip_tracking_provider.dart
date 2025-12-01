import 'package:flutter/foundation.dart';
import '../services/trip_tracking_service.dart';
import '../utils/distance_calculator.dart';

class TripTrackingProvider with ChangeNotifier {
  final TripTrackingService _trackingService = TripTrackingService();

  String? _activeTripId;
  bool _isTracking = false;
  double _distance = 0.0;
  double? _currentSpeed;
  double _averageSpeed = 0.0;
  double _maxSpeed = 0.0;
  Duration _duration = Duration.zero;
  bool _isOnline = true;

  String? get activeTripId => _activeTripId;
  bool get isTracking => _isTracking;
  double get distance => _distance;
  double? get currentSpeed => _currentSpeed;
  double get averageSpeed => _averageSpeed;
  double get maxSpeed => _maxSpeed;
  Duration get duration => _duration;
  bool get isOnline => _isOnline;
  List<LocationPoint> get route => _trackingService.route;

  TripTrackingProvider() {
    _trackingService.onDistanceUpdate = (distance) {
      _distance = distance;
      notifyListeners();
    };

    _trackingService.onSpeedUpdate = (speed) {
      _currentSpeed = speed;
      if (speed != null && speed > _maxSpeed) {
        _maxSpeed = speed;
      }
      notifyListeners();
    };

    _trackingService.onDurationUpdate = (duration) {
      _duration = duration;
      notifyListeners();
    };

    _trackingService.onConnectionStatusChanged = (isOnline) {
      _isOnline = isOnline;
      notifyListeners();
    };
  }

  Future<bool> startTrip(String tripId, {double? startLat, double? startLng}) async {
    final started = await _trackingService.startTrip(tripId, startLat: startLat, startLng: startLng);
    if (started) {
      _activeTripId = tripId;
      _isTracking = true;
      _distance = 0.0;
      _currentSpeed = null;
      _averageSpeed = 0.0;
      _maxSpeed = 0.0;
      _duration = Duration.zero;
      notifyListeners();
    }
    return started;
  }

  Future<void> stopTrip() async {
    await _trackingService.stopTrip();
    _isTracking = false;
    _distance = 0.0; // Explicitly reset distance when stopping
    _currentSpeed = null;
    _averageSpeed = _trackingService.averageSpeed;
    _maxSpeed = _trackingService.maxSpeed;
    _duration = Duration.zero;
    _activeTripId = null; // Clear active trip ID
    notifyListeners();
  }

  bool checkReturnedToOrigin(double originLat, double originLng, {double radiusMeters = 50}) {
    return _trackingService.checkReturnedToOrigin(originLat, originLng, radiusMeters: radiusMeters);
  }

  Map<String, dynamic> getTripMetrics() {
    return _trackingService.getTripMetrics();
  }

  Future<void> syncOfflineLocations() async {
    await _trackingService.syncOfflineLocations();
  }

  void dispose() {
    _trackingService.dispose();
    super.dispose();
  }
}

