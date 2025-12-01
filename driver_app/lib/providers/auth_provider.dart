import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  // Role helper methods
  List<String> getRoles() {
    if (_user == null) return [];
    
    // Handle both roles array and single role (backward compatibility)
    if (_user!['roles'] != null && _user!['roles'] is List) {
      return List<String>.from(_user!['roles']);
    } else if (_user!['role'] != null) {
      return [_user!['role']];
    }
    return [];
  }

  bool hasRole(String role) {
    return getRoles().contains(role);
  }

  bool isDriver() {
    return hasRole('driver');
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      
      // Use user data from login response if available
      Map<String, dynamic> userData;
      if (response.containsKey('user') && response['user'] != null) {
        userData = response['user'] as Map<String, dynamic>;
      } else {
        // If no user in response, try to load profile
        try {
          userData = await _apiService.getProfile();
        } catch (e) {
          throw Exception('Login succeeded but user data not available');
        }
      }

      // Check roles - support both array and single role
      List<String> roles = [];
      if (userData['roles'] != null && userData['roles'] is List) {
        roles = List<String>.from(userData['roles']);
      } else if (userData['role'] != null) {
        roles = [userData['role'] as String];
      }

      if (!roles.contains('driver')) {
        _isLoading = false;
        _errorMessage = 'Access denied. Only drivers can use this app.';
        _user = null;
        notifyListeners();
        return false;
      }

      // User has driver role - proceed with login
      _user = userData;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
      // Optionally refresh profile data in the background (non-blocking)
      _apiService.getProfile().then((profile) {
        // Validate driver role again on profile refresh
        List<String> profileRoles = [];
        if (profile['roles'] != null && profile['roles'] is List) {
          profileRoles = List<String>.from(profile['roles']);
        } else if (profile['role'] != null) {
          profileRoles = [profile['role'] as String];
        }
        
        if (profileRoles.contains('driver')) {
          _user = profile;
          notifyListeners();
        } else {
          // User lost driver role - logout
          logout();
        }
      }).catchError((e) {
        debugPrint('Profile refresh failed (non-critical): $e');
      });
      
      // Register FCM token after successful login
      try {
        final fcmService = FcmService();
        await fcmService.registerTokenIfAuthenticated();
      } catch (e) {
        debugPrint('FCM token registration failed (non-critical): $e');
      }
      
      return true;
    } catch (e) {
      _isLoading = false;
      final errorStr = e.toString();
      // Clean up error message - remove "Exception: " prefix and truncate if too long
      _errorMessage = errorStr.replaceAll('Exception: ', '');
      if (_errorMessage != null && _errorMessage!.length > 200) {
        _errorMessage = '${_errorMessage!.substring(0, 200)}...';
      }
      _user = null;
      notifyListeners();
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    // Unregister FCM token before logout
    try {
      final fcmService = FcmService();
      await fcmService.unregisterToken();
    } catch (e) {
      debugPrint('FCM token unregistration failed (non-critical): $e');
    }
    
    await _apiService.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    try {
      final profile = await _apiService.getProfile();
      
      // Validate that user has driver role
      List<String> roles = [];
      if (profile['roles'] != null && profile['roles'] is List) {
        roles = List<String>.from(profile['roles']);
      } else if (profile['role'] != null) {
        roles = [profile['role'] as String];
      }

      if (!roles.contains('driver')) {
        // User doesn't have driver role - clear user data
        _user = null;
        notifyListeners();
        return;
      }

      _user = profile;
      notifyListeners();
      
      // Register FCM token if user is authenticated
      if (_user != null) {
        try {
          final fcmService = FcmService();
          await fcmService.registerTokenIfAuthenticated();
        } catch (e) {
          debugPrint('FCM token registration failed (non-critical): $e');
        }
      }
    } catch (e) {
      _user = null;
      notifyListeners();
    }
  }
}

