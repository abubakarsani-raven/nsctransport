import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';

class IctRequestsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _requests = [];
  bool _isLoading = false;

  List<dynamic> get requests => _requests;
  bool get isLoading => _isLoading;

  Future<void> loadRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _requests = await _apiService.getIctRequests();
    } catch (e) {
      debugPrint('Error loading ICT requests: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRequest(Map<String, dynamic> requestData) async {
    try {
      await _apiService.createIctRequest(requestData);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error creating ICT request: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getRequest(String id) async {
    return await _apiService.getIctRequest(id);
  }

  Future<bool> updateRequest(String id, Map<String, dynamic> requestData) async {
    try {
      await _apiService.updateIctRequest(id, requestData);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error updating ICT request: $e');
      return false;
    }
  }

  Future<bool> approveRequest(String id, {String? comments}) async {
    try {
      await _apiService.approveIctRequest(id, comments: comments);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error approving ICT request: $e');
      return false;
    }
  }

  Future<bool> rejectRequest(String id, String rejectionReason) async {
    try {
      await _apiService.rejectIctRequest(id, rejectionReason);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error rejecting ICT request: $e');
      return false;
    }
  }

  Future<bool> resubmitRequest(String id) async {
    try {
      await _apiService.resubmitIctRequest(id);
      await loadRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendBackForCorrection(String id, String correctionNote) async {
    try {
      await _apiService.sendBackIctRequestForCorrection(id, correctionNote);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error sending back ICT request for correction: $e');
      return false;
    }
  }

  Future<bool> cancelRequest(String id, String cancellationReason) async {
    try {
      await _apiService.cancelIctRequest(id, cancellationReason);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error cancelling ICT request: $e');
      return false;
    }
  }

  Future<bool> fulfillRequest(String id) async {
    try {
      await _apiService.fulfillIctRequest(id);
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('Error fulfilling ICT request: $e');
      return false;
    }
  }
}

