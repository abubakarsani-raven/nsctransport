import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';

class FaultsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _myFaults = [];
  List<dynamic> _vehicleFaults = [];
  bool _isLoading = false;

  List<dynamic> get myFaults => _myFaults;
  List<dynamic> get vehicleFaults => _vehicleFaults;
  bool get isLoading => _isLoading;

  Future<void> loadMyFaults() async {
    _isLoading = true;
    notifyListeners();

    try {
      _myFaults = await _apiService.getMyFaultReports();
    } catch (e) {
      debugPrint('Error loading my faults: $e');
      _myFaults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVehicleFaults(String vehicleId) async {
    try {
      _vehicleFaults = await _apiService.getVehicleFaults(vehicleId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading vehicle faults: $e');
      _vehicleFaults = [];
    }
  }

  Future<bool> reportFault({
    required String vehicleId,
    required String category,
    required String description,
    List<String>? photos,
    String priority = 'medium',
  }) async {
    try {
      await _apiService.reportFault(
        vehicleId: vehicleId,
        category: category,
        description: description,
        photos: photos,
        priority: priority,
      );
      await loadMyFaults();
      return true;
    } catch (e) {
      debugPrint('Error reporting fault: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getFaultDetails(String faultId) async {
    try {
      return await _apiService.getFaultDetails(faultId);
    } catch (e) {
      debugPrint('Error getting fault details: $e');
      return null;
    }
  }
}

