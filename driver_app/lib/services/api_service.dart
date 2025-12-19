import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
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

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        if (data.containsKey('access_token')) {
          await prefs.setString('token', data['access_token'] as String);
        }
        return data;
      } catch (e) {
        throw Exception('Failed to parse login response: $e');
      }
    } else {
      String errorMessage = 'Login failed';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('message')) {
          errorMessage = errorBody['message'] as String;
        } else {
          errorMessage = response.body;
        }
      } catch (_) {
        errorMessage = response.body;
      }
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

  Future<List<dynamic>> getActiveTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/active'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final body = response.body.trim();
      if (body.isEmpty) {
        // Backend may return 200 with no content – treat as no active trips
        return const [];
      }
      return jsonDecode(body);
    } else {
      throw Exception('Failed to get trips');
    }
  }

  Future<Map<String, dynamic>> getTrip(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/$id/tracking'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get trip');
    }
  }

  Future<void> updateLocation(String tripId, double lat, double lng) async {
    await http.post(
      Uri.parse('$baseUrl/trips/$tripId/location'),
      headers: await _getHeaders(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
  }

  Future<void> startTrip(String tripId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/start'),
      headers: await _getHeaders(),
      body: jsonEncode({'tripId': tripId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage = 'Failed to start trip';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          errorMessage = body['message'].toString();
        } else {
          errorMessage = response.body;
        }
      } catch (_) {
        errorMessage = response.body;
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> completeTrip(String tripId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/complete'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage = 'Failed to complete trip';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          errorMessage = body['message'].toString();
        } else {
          errorMessage = response.body;
        }
      } catch (_) {
        errorMessage = response.body;
      }
      throw Exception(errorMessage);
    }
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

  // Vehicle endpoints
  Future<Map<String, dynamic>?> getMyAssignedVehicle() async {
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/my-assigned'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      // Handle empty response or null
      final body = response.body.trim();
      if (body.isEmpty || body == 'null') {
        return null;
      }
      try {
        final decoded = jsonDecode(body);
        // If backend returns null, handle it
        if (decoded == null) {
          return null;
        }
        return decoded as Map<String, dynamic>;
      } catch (e) {
        // If JSON decode fails, return null instead of throwing
        debugPrint('Error decoding assigned vehicle response: $e');
        return null;
      }
    } else if (response.statusCode == 404) {
      // 404 means no vehicle assigned
      return null;
    } else {
      throw Exception('Failed to get assigned vehicle: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getMaintenanceReminders(String vehicleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maintenance/vehicles/$vehicleId/reminders'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get maintenance reminders');
    }
  }

  Future<Map<String, dynamic>> getVehicleDistance(String vehicleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/$vehicleId/distance'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get vehicle distance');
    }
  }

  Future<List<dynamic>> getVehicleDistanceHistory(String vehicleId, {DateTime? startDate, DateTime? endDate}) async {
    final uri = Uri.parse('$baseUrl/vehicles/$vehicleId/distance/history').replace(
      queryParameters: {
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get distance history');
    }
  }

  // Trip endpoints
  Future<List<dynamic>> getUpcomingTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/driver/upcoming'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final body = response.body.trim();
      if (body.isEmpty) {
        return const [];
      }
      return jsonDecode(body);
    } else {
      throw Exception('Failed to get upcoming trips');
    }
  }

  Future<Map<String, dynamic>?> getActiveTrip() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/driver/active'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final body = response.body.trim();
      if (body.isEmpty || body == 'null') {
        return null;
      }
      final data = jsonDecode(body);
      return data is List && data.isNotEmpty ? data[0] as Map<String, dynamic> : null;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to get active trip');
    }
  }

  Future<List<dynamic>> getCompletedTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/driver/completed'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final body = response.body.trim();
      if (body.isEmpty) {
        return const [];
      }
      return jsonDecode(body);
    } else {
      throw Exception('Failed to get completed trips');
    }
  }

  Future<void> batchUpdateLocation(String tripId, List<Map<String, dynamic>> locations) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/location/batch'),
      headers: await _getHeaders(),
      body: jsonEncode({'locations': locations}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to batch update location: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getTripMetrics(String tripId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/$tripId/metrics'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get trip metrics');
    }
  }

  // Fault endpoints
  Future<Map<String, dynamic>> reportFault({
    required String vehicleId,
    required String category,
    required String description,
    List<String>? photos,
    String priority = 'medium',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/faults'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'vehicleId': vehicleId,
        'category': category,
        'description': description,
        if (photos != null) 'photos': photos,
        'priority': priority,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to report fault: ${response.body}');
    }
  }

  Future<List<dynamic>> getMyFaultReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/faults/my-reports'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get fault reports');
    }
  }

  Future<List<dynamic>> getVehicleFaults(String vehicleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/faults/vehicle/$vehicleId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get vehicle faults');
    }
  }

  Future<Map<String, dynamic>> getFaultDetails(String faultId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/faults/$faultId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get fault details');
    }
  }

  Future<Map<String, dynamic>> updateFaultStatus(String faultId, String status, {String? notes}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/faults/$faultId'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'status': status,
        if (notes != null) 'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update fault status: ${response.body}');
    }
  }
}

