import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class TransportOfficerProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoadingAssets = false;
  bool _isFleetLoading = false;
  bool _isOfficesLoading = false;
  String? _errorMessage;

  List<dynamic> _availableDrivers = [];
  List<dynamic> _availableVehicles = [];
  List<dynamic> _fleetVehicles = [];
  List<dynamic> _drivers = [];
  List<dynamic> _offices = [];
  final Map<String, List<dynamic>> _maintenanceRecords = {};
  final Map<String, List<dynamic>> _maintenanceReminders = {};

  String _vehicleFilter = 'all';
  String _driverFilter = 'all';
  String _vehicleSearch = '';
  String _driverSearch = '';

  DateTime? _lastUpdated;

  bool get isLoadingAssets => _isLoadingAssets;
  bool get isFleetLoading => _isFleetLoading;
  bool get isOfficesLoading => _isOfficesLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;

  List<dynamic> get availableDrivers => _availableDrivers;
  List<dynamic> get availableVehicles => _availableVehicles;
  List<dynamic> get offices => _offices;
  List<dynamic> maintenanceRecordsFor(String vehicleId) =>
      _maintenanceRecords[vehicleId] ?? const [];
  List<dynamic> maintenanceRemindersFor(String vehicleId) =>
      _maintenanceReminders[vehicleId] ?? const [];
  int get totalVehicles => _fleetVehicles.length;
  int get totalDrivers => _drivers.length;
  int get availableVehicleCount =>
      _fleetVehicles.where((vehicle) => (vehicle['status'] ?? '').toString().toLowerCase() == 'available').length;
  int get onAssignmentVehicleCount =>
      _fleetVehicles.where((vehicle) => (vehicle['status'] ?? '').toString().toLowerCase() == 'assigned').length;
  int get permanentVehicleCount =>
      _fleetVehicles.where((vehicle) => (vehicle['status'] ?? '').toString().toLowerCase() == 'permanently_assigned').length;
  int get availableDriverCount =>
      _drivers.where((driver) {
        if (driver is! Map<String, dynamic>) return false;
        final hasCurrentTrip = driver['currentTripId'] != null;
        final hasPermanentVehicle = driver['permanentVehicle'] != null;
        return !hasCurrentTrip && !hasPermanentVehicle;
      }).length;

  String get vehicleFilter => _vehicleFilter;
  String get driverFilter => _driverFilter;
  String get vehicleSearch => _vehicleSearch;
  String get driverSearch => _driverSearch;

  List<dynamic> get filteredFleetVehicles {
    return _fleetVehicles.where((vehicle) {
      if (!_matchesVehicleFilter(vehicle)) return false;
      if (_vehicleSearch.isEmpty) return true;
      final query = _vehicleSearch.toLowerCase();
      final plate = (vehicle['plateNumber'] ?? '').toString().toLowerCase();
      final make = (vehicle['make'] ?? '').toString().toLowerCase();
      final model = (vehicle['model'] ?? '').toString().toLowerCase();
      return plate.contains(query) || make.contains(query) || model.contains(query);
    }).toList();
  }

  List<dynamic> get filteredDrivers {
    return _drivers.where((driver) {
      if (!_matchesDriverFilter(driver)) return false;
      if (_driverSearch.isEmpty) return true;
      final query = _driverSearch.toLowerCase();
      final name = (driver['name'] ?? '').toString().toLowerCase();
      final email = (driver['email'] ?? '').toString().toLowerCase();
      final employeeId = (driver['employeeId'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || employeeId.contains(query);
    }).toList();
  }

  Future<void> loadAssets({bool silent = false}) async {
    if (!silent) {
      _isLoadingAssets = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait<List<dynamic>>([
        _apiService.getAvailableDrivers(),
        _apiService.getAvailableVehicles(),
      ]);

      _availableDrivers = results[0];
      _availableVehicles = results[1];
    } catch (e) {
      _errorMessage = 'Failed to load assignments: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoadingAssets = false;
      notifyListeners();
    }
  }

  Future<void> loadFleet({bool silent = false}) async {
    if (!silent) {
      _isFleetLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait<List<dynamic>>([
        _apiService.getVehicles(),
        _apiService.getDrivers(),
      ]);

      final vehicles = List<dynamic>.from(results[0]);
      final drivers = List<dynamic>.from(results[1]);
      final Map<String, dynamic> driverLookup = {};

      final Map<String, dynamic> permanentAssignments = {};
      final Map<String, dynamic> currentAssignments = {};
      for (final vehicle in vehicles) {
        final status = (vehicle['status'] ?? '').toString().toLowerCase();
        if (status == 'permanently_assigned') {
          final driverId = _normalizeId(vehicle['permanentlyAssignedDriverId']);
          if (driverId != null) {
            permanentAssignments[driverId] = vehicle;
          }
        }
      }

      for (final driver in drivers) {
        final driverId = _normalizeId(driver);
        if (driverId != null) {
          driverLookup[driverId] = driver;
        }
        if (driver is Map<String, dynamic>) {
          driver['permanentVehicle'] = permanentAssignments[driverId];
          final currentVehicle = driver['currentVehicle'];
          final vehicleId = _normalizeId(currentVehicle);
          if (vehicleId != null) {
            currentAssignments[vehicleId] = driver;
          }
        }
      }

      for (final vehicle in vehicles) {
        final vehicleId = _normalizeId(vehicle);
        if (vehicle is Map<String, dynamic>) {
          final status = (vehicle['status'] ?? '').toString().toLowerCase();
          if (status == 'permanently_assigned') {
            final driverId = _normalizeId(vehicle['permanentlyAssignedDriverId']);
            vehicle['currentDriver'] = driverLookup[driverId];
          } else {
            vehicle['currentDriver'] = currentAssignments[vehicleId];
          }
        }
      }

      _fleetVehicles = vehicles;
      _drivers = drivers;
      _lastUpdated = DateTime.now();
    } catch (e) {
      _errorMessage = 'Failed to load fleet data: $e';
      debugPrint(_errorMessage);
    } finally {
      _isFleetLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadAssets(silent: true),
      loadFleet(silent: true),
      loadOffices(silent: true),
    ]);
  }

  Future<void> loadOffices({bool silent = false}) async {
    if (!silent) {
      _isOfficesLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _offices = await _apiService.getOffices();
    } catch (e) {
      _errorMessage = 'Failed to load offices: $e';
      debugPrint(_errorMessage);
    } finally {
      _isOfficesLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMaintenance(String vehicleId) async {
    try {
      final results = await Future.wait<List<dynamic>>([
        _apiService.getMaintenanceRecords(vehicleId),
        _apiService.getMaintenanceReminders(vehicleId),
      ]);
      _maintenanceRecords[vehicleId] = results[0];
      _maintenanceReminders[vehicleId] = results[1];
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load maintenance data: $e';
      debugPrint(_errorMessage);
    }
  }

  Future<void> addMaintenanceRecord(String vehicleId, Map<String, dynamic> payload) async {
    await _apiService.createMaintenanceRecord(vehicleId, payload);
    await loadMaintenance(vehicleId);
  }

  Future<void> addMaintenanceReminder(String vehicleId, Map<String, dynamic> payload) async {
    await _apiService.createMaintenanceReminder(vehicleId, payload);
    await loadMaintenance(vehicleId);
  }

  Future<void> deleteMaintenanceRecord(String vehicleId, String recordId) async {
    await _apiService.deleteMaintenanceRecord(recordId);
    await loadMaintenance(vehicleId);
  }

  Future<void> deleteMaintenanceReminder(String vehicleId, String reminderId) async {
    await _apiService.deleteMaintenanceReminder(reminderId);
    await loadMaintenance(vehicleId);
  }

  void setVehicleFilter(String filter) {
    if (_vehicleFilter == filter) return;
    _vehicleFilter = filter;
    notifyListeners();
  }

  void setDriverFilter(String filter) {
    if (_driverFilter == filter) return;
    _driverFilter = filter;
    notifyListeners();
  }

  void setVehicleSearch(String query) {
    if (_vehicleSearch == query) return;
    _vehicleSearch = query;
    notifyListeners();
  }

  void setDriverSearch(String query) {
    if (_driverSearch == query) return;
    _driverSearch = query;
    notifyListeners();
  }

  bool _matchesVehicleFilter(dynamic vehicle) {
    final status = (vehicle['status'] ?? '').toString().toLowerCase();
    switch (_vehicleFilter) {
      case 'available':
        return status == 'available';
      case 'assigned':
        return status == 'assigned';
      case 'maintenance':
        return status == 'maintenance';
      case 'permanent':
        return status == 'permanently_assigned';
      default:
        return true;
    }
  }

  bool _matchesDriverFilter(dynamic driver) {
    final hasCurrentTrip = driver is Map<String, dynamic> && driver['currentTripId'] != null;
    final hasPermanentVehicle = driver is Map<String, dynamic> && driver['permanentVehicle'] != null;

    switch (_driverFilter) {
      case 'available':
        return !hasCurrentTrip && !hasPermanentVehicle;
      case 'on_assignment':
        return hasCurrentTrip;
      case 'permanent':
        return hasPermanentVehicle;
      default:
        return true;
    }
  }

  String? _normalizeId(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    if (value is Map<String, dynamic>) {
      final id = value['_id'] ?? value['id'];
      if (id == null) return null;
      return id.toString();
    }
    return value.toString();
  }
}

