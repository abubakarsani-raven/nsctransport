import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class TripsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _trips = [];
  List<dynamic> _upcomingTrips = [];
  List<dynamic> _completedTrips = [];
  Map<String, dynamic>? _activeTrip;
  bool _isLoading = false;
  bool _isTracking = false;

  List<dynamic> get trips => _trips;
  List<dynamic> get upcomingTrips => _upcomingTrips;
  List<dynamic> get completedTrips => _completedTrips;
  Map<String, dynamic>? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;

  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[TripsProvider] Loading trips...');
      _trips = await _apiService.getActiveTrips();
      debugPrint('[TripsProvider] Active trips from API: ${_trips.length}');

      _activeTrip = await _apiService.getActiveTrip();
      if (_activeTrip != null) {
        debugPrint('[TripsProvider] Active trip from /driver/active: ${_activeTrip!['_id']} status=${_activeTrip!['status']}');
      } else {
        debugPrint('[TripsProvider] No active trip from /driver/active');
      }

      if (_trips.isNotEmpty && _activeTrip == null) {
        _activeTrip = _trips.first as Map<String, dynamic>?;
        debugPrint('[TripsProvider] Fallback active trip from /active list: ${_activeTrip!['_id']} status=${_activeTrip!['status']}');
      }
    } catch (e) {
      debugPrint('Error loading trips: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUpcomingTrips() async {
    try {
      debugPrint('[TripsProvider] Loading upcoming trips...');
      _upcomingTrips = await _apiService.getUpcomingTrips();
      debugPrint('[TripsProvider] Upcoming trips from API: ${_upcomingTrips.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading upcoming trips: $e');
      _upcomingTrips = [];
    }
  }

  Future<void> loadCompletedTrips() async {
    try {
      debugPrint('[TripsProvider] Loading completed trips...');
      _completedTrips = await _apiService.getCompletedTrips();
      debugPrint('[TripsProvider] Completed trips from API: ${_completedTrips.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading completed trips: $e');
      _completedTrips = [];
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
      // Reload all trip-related lists so UI reflects completion immediately
      await loadTrips();            // refresh activeTrip and active trips
      await loadUpcomingTrips();    // ensure completed trip is removed from upcoming
      await loadCompletedTrips();   // update history
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing trip: $e');
      rethrow; // Re-throw to allow UI to handle error
    }
  }

  void setTracking(bool value) {
    _isTracking = value;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getTripMetrics(String tripId) async {
    try {
      return await _apiService.getTripMetrics(tripId);
    } catch (e) {
      debugPrint('Error getting trip metrics: $e');
      return null;
    }
  }
}

