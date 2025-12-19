import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  // Get base URL from ApiConfig which handles environment variables
  // - Development: Uses localhost (or .env file)
  // - Production: Uses Railway URL (https://nsctransport-production.up.railway.app)
  static String get baseUrl => ApiConfig.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    // Debug logging
    debugPrint('Login response status: ${response.statusCode}');
    debugPrint('Login response body length: ${response.body.length}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        if (data.containsKey('access_token')) {
          await prefs.setString('token', data['access_token'] as String);
        }
        debugPrint('Login successful, user: ${data['user']?['email']}');
        return data;
      } catch (e) {
        debugPrint('JSON parsing error: $e');
        debugPrint('Response body: ${response.body}');
        throw Exception('Failed to parse login response: $e');
      }
    } else {
      String errorMessage = 'Login failed';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('message')) {
          errorMessage = errorBody['message'] as String;
        } else {
          errorMessage = response.body.length > 200 
              ? '${response.body.substring(0, 200)}...' 
              : response.body;
        }
      } catch (_) {
        errorMessage = response.body.length > 200 
            ? '${response.body.substring(0, 200)}...' 
            : response.body;
      }
      debugPrint('Login failed with status ${response.statusCode}: $errorMessage');
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get profile');
    }
  }

  Future<List<dynamic>> getOffices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/offices'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get offices');
    }
  }

  Future<List<dynamic>> getSupervisorsByDepartment(String department) async {
    final encodedDepartment = Uri.encodeComponent(department);
    final response = await http.get(
      Uri.parse('$baseUrl/users/supervisors/$encodedDepartment'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get supervisors: ${response.body}');
    }
  }

  // Legacy methods (kept for backward compatibility - redirect to vehicle)
  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> requestData) async {
    return createVehicleRequest(requestData);
  }

  Future<List<dynamic>> getRequests() async {
    return getVehicleRequests();
  }

  Future<Map<String, dynamic>> getRequest(String id) async {
    return getVehicleRequest(id);
  }

  Future<Map<String, dynamic>> updateRequest(String id, Map<String, dynamic> requestData) async {
    return updateVehicleRequest(id, requestData);
  }

  Future<Map<String, dynamic>> resubmitRequest(String id) async {
    return resubmitVehicleRequest(id);
  }

  Future<Map<String, dynamic>> approveRequest(String id, {String? comments}) async {
    return approveVehicleRequest(id, comments: comments);
  }

  Future<List<dynamic>> getAvailableDrivers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assignments/available-drivers'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get available drivers');
    }
  }

  Future<List<dynamic>> getAvailableVehicles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assignments/available-vehicles'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get available vehicles');
    }
  }

  Future<List<dynamic>> getAvailableDriversForRequest(String requestId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/assignments/available-drivers/$requestId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get available drivers for request');
    }
  }

  Future<List<dynamic>> getAvailableVehiclesForRequest(String requestId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/assignments/available-vehicles/$requestId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get available vehicles for request');
    }
  }

  Future<List<dynamic>> getVehicles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch vehicles');
    }
  }

  Future<List<dynamic>> getDrivers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/drivers'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch drivers');
    }
  }

  Future<List<dynamic>> getMaintenanceRecords(String vehicleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maintenance/vehicles/$vehicleId/records'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to fetch maintenance records');
    }
  }

  Future<List<dynamic>> getMaintenanceReminders(String vehicleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maintenance/vehicles/$vehicleId/reminders'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to fetch maintenance reminders');
    }
  }

  Future<Map<String, dynamic>> createMaintenanceRecord(
    String vehicleId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/maintenance/vehicles/$vehicleId/records'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create maintenance record: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateMaintenanceRecord(
    String recordId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/maintenance/records/$recordId'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update maintenance record: ${response.body}');
    }
  }

  Future<void> deleteMaintenanceRecord(String recordId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/maintenance/records/$recordId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete maintenance record: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createMaintenanceReminder(
    String vehicleId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/maintenance/vehicles/$vehicleId/reminders'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create maintenance reminder: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateMaintenanceReminder(
    String reminderId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/maintenance/reminders/$reminderId'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update maintenance reminder: ${response.body}');
    }
  }

  Future<void> deleteMaintenanceReminder(String reminderId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/maintenance/reminders/$reminderId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete maintenance reminder: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> assignDriverAndVehicle({
    required String requestId,
    required String driverId,
    required String vehicleId,
    required String pickupOfficeId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assignments/assign'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'requestId': requestId,
        'driverId': driverId,
        'vehicleId': vehicleId,
        'pickupOfficeId': pickupOfficeId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to assign driver and vehicle';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage = errorBody['message'] ?? errorBody['error'] ?? response.body;
      } catch (e) {
        errorMessage = response.body;
      }
      throw Exception(errorMessage);
    }
  }

  // Vehicle Request Methods
  Future<Map<String, dynamic>> createVehicleRequest(Map<String, dynamic> requestData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests/vehicle'),
      headers: await _getHeaders(),
      body: jsonEncode(requestData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create vehicle request: ${response.body}');
    }
  }

  Future<List<dynamic>> getVehicleRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/vehicle'),
      headers: await _getHeaders(),
    );

    // Treat 200 as success, 204/404 as "no requests", and log other errors
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 204 || response.statusCode == 404) {
      debugPrint(
        'getVehicleRequests: no requests found '
        '(status ${response.statusCode})',
      );
      return [];
    }

    // Log details to help with debugging (e.g. 401/500)
    debugPrint(
      'getVehicleRequests error: '
      'status=${response.statusCode}, '
      'body=${response.body}',
    );

    throw Exception('Failed to get vehicle requests');
  }

  Future<Map<String, dynamic>> getVehicleRequest(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/vehicle/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get vehicle request');
    }
  }

  Future<Map<String, dynamic>> updateVehicleRequest(String id, Map<String, dynamic> requestData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/vehicle/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(requestData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update vehicle request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> resubmitVehicleRequest(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/vehicle/$id/resubmit'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to resubmit vehicle request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> approveVehicleRequest(String id, {String? comments}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/vehicle/$id/approve'),
      headers: await _getHeaders(),
      body: jsonEncode({'comments': comments}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to approve vehicle request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> rejectVehicleRequest(String id, String rejectionReason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/vehicle/$id/reject'),
      headers: await _getHeaders(),
      body: jsonEncode({'rejectionReason': rejectionReason}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to reject vehicle request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> sendBackVehicleRequestForCorrection(String id, String correctionNote) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/vehicle/$id/send-back-for-correction'),
      headers: await _getHeaders(),
      body: jsonEncode({'correctionNote': correctionNote}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send back vehicle request for correction: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> cancelVehicleRequest(String id, String cancellationReason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/vehicle/$id/cancel'),
      headers: await _getHeaders(),
      body: jsonEncode({'cancellationReason': cancellationReason}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to cancel vehicle request: ${response.body}');
    }
  }

  // ICT Request Methods
  Future<Map<String, dynamic>> createIctRequest(Map<String, dynamic> requestData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests/ict'),
      headers: await _getHeaders(),
      body: jsonEncode(requestData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create ICT request: ${response.body}');
    }
  }

  Future<List<dynamic>> getIctRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/ict'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get ICT requests');
    }
  }

  Future<Map<String, dynamic>> getIctRequest(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/ict/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get ICT request');
    }
  }

  Future<Map<String, dynamic>> updateIctRequest(String id, Map<String, dynamic> requestData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/ict/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(requestData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update ICT request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> approveIctRequest(String id, {String? comments}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/ict/$id/approve'),
      headers: await _getHeaders(),
      body: jsonEncode({'comments': comments}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to approve ICT request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> rejectIctRequest(String id, String rejectionReason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/ict/$id/reject'),
      headers: await _getHeaders(),
      body: jsonEncode({'rejectionReason': rejectionReason}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to reject ICT request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> resubmitIctRequest(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/ict/$id/resubmit'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to resubmit ICT request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> sendBackIctRequestForCorrection(String id, String correctionNote) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/ict/$id/send-back-for-correction'),
      headers: await _getHeaders(),
      body: jsonEncode({'correctionNote': correctionNote}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send back ICT request for correction: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> cancelIctRequest(String id, String cancellationReason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/ict/$id/cancel'),
      headers: await _getHeaders(),
      body: jsonEncode({'cancellationReason': cancellationReason}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to cancel ICT request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fulfillIctRequest(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/ict/$id/fulfill'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fulfill ICT request: ${response.body}');
    }
  }

  // Store Request Methods
  Future<Map<String, dynamic>> createStoreRequest(Map<String, dynamic> requestData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests/store'),
      headers: await _getHeaders(),
      body: jsonEncode(requestData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create store request: ${response.body}');
    }
  }

  Future<List<dynamic>> getStoreRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/store'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get store requests');
    }
  }

  Future<Map<String, dynamic>> getStoreRequest(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/store/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get store request');
    }
  }

  Future<Map<String, dynamic>> updateStoreRequest(String id, Map<String, dynamic> requestData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/store/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(requestData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update store request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> approveStoreRequest(String id, {String? comments}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/store/$id/approve'),
      headers: await _getHeaders(),
      body: jsonEncode({'comments': comments}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to approve store request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> rejectStoreRequest(String id, String rejectionReason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/store/$id/reject'),
      headers: await _getHeaders(),
      body: jsonEncode({'rejectionReason': rejectionReason}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to reject store request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> resubmitStoreRequest(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/store/$id/resubmit'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to resubmit store request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> sendBackStoreRequestForCorrection(String id, String correctionNote) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/store/$id/send-back-for-correction'),
      headers: await _getHeaders(),
      body: jsonEncode({'correctionNote': correctionNote}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send back store request for correction: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> cancelStoreRequest(String id, String cancellationReason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/store/$id/cancel'),
      headers: await _getHeaders(),
      body: jsonEncode({'cancellationReason': cancellationReason}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to cancel store request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fulfillStoreRequest(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/store/$id/fulfill'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fulfill store request: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> rejectRequest(String id, String rejectionReason) async {
    return rejectVehicleRequest(id, rejectionReason);
  }

  Future<Map<String, dynamic>> sendBackForCorrection(String id, String correctionNote) async {
    return sendBackVehicleRequestForCorrection(id, correctionNote);
  }

  Future<Map<String, dynamic>> cancelRequest(String id, String cancellationReason) async {
    return cancelVehicleRequest(id, cancellationReason);
  }

  Future<List<dynamic>> getNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get notifications');
    }
  }

  Future<Map<String, dynamic>> markNotificationAsRead(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to mark notification as read');
  }

  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    final response = await http.put(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to mark notifications as read');
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final unread = data['unread'];
      if (unread is int) {
        return unread;
      }
      if (unread is String) {
        return int.tryParse(unread) ?? 0;
      }
      return 0;
    }

    throw Exception('Failed to get unread notifications count');
  }

  Future<List<dynamic>> getRequestHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/history'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      }
      return [];
    }

    throw Exception('Failed to get request history');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<Map<String, dynamic>> registerDeviceToken(String token, String platform, {String? deviceName}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/register-token'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'token': token,
        'platform': platform,
        if (deviceName != null) 'deviceName': deviceName,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to register device token: ${response.body}');
  }

  Future<void> unregisterDeviceToken(String token) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/notifications/unregister-token'),
      headers: await _getHeaders(),
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to unregister device token: ${response.body}');
    }
  }
}

