import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_helper.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator (maps to host's localhost)
  // Use localhost for iOS simulator and web
  // For physical devices, use your computer's IP: 'http://192.168.x.x:3000'
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (PlatformHelper.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

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
      return jsonDecode(response.body);
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
    await http.post(
      Uri.parse('$baseUrl/trips/start'),
      headers: await _getHeaders(),
      body: jsonEncode({'tripId': tripId}),
    );
  }

  Future<void> completeTrip(String tripId) async {
    await http.post(
      Uri.parse('$baseUrl/trips/$tripId/complete'),
      headers: await _getHeaders(),
    );
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
}

