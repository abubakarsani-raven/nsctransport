import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class TripsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _trips = [];
  Map<String, dynamic>? _activeTrip;
  bool _isLoading = false;
  bool _isTracking = false;

  List<dynamic> get trips => _trips;
  Map<String, dynamic>? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;

  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      _trips = await _apiService.getActiveTrips();
      if (_trips.isNotEmpty) {
        _activeTrip = _trips.first;
      }
    } catch (e) {
      debugPrint('Error loading trips: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTrip(String id) async {
    try {
      _activeTrip = await _apiService.getTrip(id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading trip: $e');
    }
  }

  Future<void> startTrip(String tripId) async {
    try {
      await _apiService.startTrip(tripId);
      _isTracking = true;
      await loadTrips();
    } catch (e) {
      debugPrint('Error starting trip: $e');
    }
  }

  Future<void> updateLocation(String tripId, double lat, double lng) async {
    try {
      await _apiService.updateLocation(tripId, lat, lng);
      await loadTrip(tripId);
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  Future<void> completeTrip(String tripId) async {
    try {
      await _apiService.completeTrip(tripId);
      _isTracking = false;
      _activeTrip = null;
      await loadTrips();
    } catch (e) {
      debugPrint('Error completing trip: $e');
    }
  }

  void setTracking(bool value) {
    _isTracking = value;
    notifyListeners();
  }
}

