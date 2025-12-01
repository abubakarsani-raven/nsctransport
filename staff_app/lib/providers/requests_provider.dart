import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class RequestsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _requests = [];
  bool _isLoading = false;

  List<dynamic> get requests => _requests;
  bool get isLoading => _isLoading;

  Future<void> loadRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _requests = await _apiService.getRequests();
    } catch (e) {
      debugPrint('Error loading requests: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRequest(Map<String, dynamic> requestData) async {
    try {
      await _apiService.createRequest(requestData);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error creating request: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getRequest(String id) async {
    return await _apiService.getRequest(id);
  }

  Future<bool> updateRequest(String id, Map<String, dynamic> requestData) async {
    try {
      await _apiService.updateRequest(id, requestData);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error updating request: $e');
      return false;
    }
  }

  Future<bool> resubmitRequest(String id) async {
    try {
      await _apiService.resubmitRequest(id);
      await loadRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveRequest(String id, {String? comments}) async {
    try {
      await _apiService.approveRequest(id, comments: comments);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error approving request: $e');
      return false;
    }
  }

  Future<bool> rejectRequest(String id, String rejectionReason) async {
    try {
      await _apiService.rejectRequest(id, rejectionReason);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      return false;
    }
  }

  Future<bool> sendBackForCorrection(String id, String correctionNote) async {
    try {
      await _apiService.sendBackForCorrection(id, correctionNote);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error sending back for correction: $e');
      return false;
    }
  }

  Future<bool> cancelRequest(String id, String cancellationReason) async {
    try {
      await _apiService.cancelRequest(id, cancellationReason);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error cancelling request: $e');
      return false;
    }
  }

  Future<List<dynamic>> getAvailableDrivers() async {
    try {
      return await _apiService.getAvailableDrivers();
    } catch (e) {
      debugPrint('Error fetching available drivers: $e');
      return [];
    }
  }

  Future<List<dynamic>> getAvailableVehicles() async {
    try {
      return await _apiService.getAvailableVehicles();
    } catch (e) {
      debugPrint('Error fetching available vehicles: $e');
      return [];
    }
  }

  Future<List<dynamic>> getAvailableDriversForRequest(String requestId) async {
    try {
      return await _apiService.getAvailableDriversForRequest(requestId);
    } catch (e) {
      debugPrint('Error fetching available drivers for request: $e');
      return [];
    }
  }

  Future<List<dynamic>> getAvailableVehiclesForRequest(String requestId) async {
    try {
      return await _apiService.getAvailableVehiclesForRequest(requestId);
    } catch (e) {
      debugPrint('Error fetching available vehicles for request: $e');
      return [];
    }
  }

  /// Assign driver & vehicle.
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> assignDriverAndVehicle({
    required String requestId,
    required String driverId,
    required String vehicleId,
    required String pickupOfficeId,
  }) async {
    try {
      await _apiService.assignDriverAndVehicle(
        requestId: requestId,
        driverId: driverId,
        vehicleId: vehicleId,
        pickupOfficeId: pickupOfficeId,
      );
      await loadRequests();
      return null;
    } catch (e) {
      debugPrint('Error assigning driver/vehicle: $e');
      return e.toString();
    }
  }
}

