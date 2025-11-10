import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';

class StoreRequestsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _requests = [];
  bool _isLoading = false;

  List<dynamic> get requests => _requests;
  bool get isLoading => _isLoading;

  Future<void> loadRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _requests = await _apiService.getStoreRequests();
    } catch (e) {
      debugPrint('Error loading store requests: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRequest(Map<String, dynamic> requestData) async {
    try {
      await _apiService.createStoreRequest(requestData);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error creating store request: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getRequest(String id) async {
    return await _apiService.getStoreRequest(id);
  }

  Future<bool> updateRequest(String id, Map<String, dynamic> requestData) async {
    try {
      await _apiService.updateStoreRequest(id, requestData);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error updating store request: $e');
      return false;
    }
  }

  Future<bool> approveRequest(String id, {String? comments}) async {
    try {
      await _apiService.approveStoreRequest(id, comments: comments);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error approving store request: $e');
      return false;
    }
  }

  Future<bool> rejectRequest(String id, String rejectionReason) async {
    try {
      await _apiService.rejectStoreRequest(id, rejectionReason);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error rejecting store request: $e');
      return false;
    }
  }

  Future<bool> resubmitRequest(String id) async {
    try {
      await _apiService.resubmitStoreRequest(id);
      await loadRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendBackForCorrection(String id, String correctionNote) async {
    try {
      await _apiService.sendBackStoreRequestForCorrection(id, correctionNote);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error sending back store request for correction: $e');
      return false;
    }
  }

  Future<bool> cancelRequest(String id, String cancellationReason) async {
    try {
      await _apiService.cancelStoreRequest(id, cancellationReason);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error cancelling store request: $e');
      return false;
    }
  }

  Future<bool> fulfillRequest(String id) async {
    try {
      await _apiService.fulfillStoreRequest(id);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error fulfilling store request: $e');
      return false;
    }
  }
}

