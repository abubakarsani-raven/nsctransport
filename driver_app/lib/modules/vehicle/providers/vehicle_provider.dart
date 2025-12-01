import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';

class VehicleProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _assignedVehicle;
  List<dynamic> _maintenanceReminders = [];
  Map<String, dynamic>? _distanceInfo;
  List<dynamic> _distanceHistory = [];
  bool _isLoading = false;

  Map<String, dynamic>? get assignedVehicle => _assignedVehicle;
  List<dynamic> get maintenanceReminders => _maintenanceReminders;
  Map<String, dynamic>? get distanceInfo => _distanceInfo;
  List<dynamic> get distanceHistory => _distanceHistory;
  bool get isLoading => _isLoading;

  Future<void> loadAssignedVehicle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final vehicle = await _apiService.getMyAssignedVehicle();
      if (vehicle != null) {
        _assignedVehicle = vehicle;
        
        // Load related data if vehicle has an ID
        if (_assignedVehicle!['_id'] != null) {
          await loadMaintenanceReminders(_assignedVehicle!['_id']);
          await loadVehicleDistance(_assignedVehicle!['_id']);
        }
      } else {
        // No vehicle assigned
        _assignedVehicle = null;
        _maintenanceReminders = [];
        _distanceInfo = null;
      }
    } catch (e) {
      debugPrint('Error loading assigned vehicle: $e');
      _assignedVehicle = null;
      _maintenanceReminders = [];
      _distanceInfo = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMaintenanceReminders(String vehicleId) async {
    try {
      _maintenanceReminders = await _apiService.getMaintenanceReminders(vehicleId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading maintenance reminders: $e');
      _maintenanceReminders = [];
    }
  }

  Future<void> loadVehicleDistance(String vehicleId) async {
    try {
      _distanceInfo = await _apiService.getVehicleDistance(vehicleId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading vehicle distance: $e');
    }
  }

  Future<void> loadDistanceHistory(String vehicleId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      _distanceHistory = await _apiService.getVehicleDistanceHistory(
        vehicleId,
        startDate: startDate,
        endDate: endDate,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading distance history: $e');
      _distanceHistory = [];
    }
  }
}

