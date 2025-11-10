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

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      
      // Use user data from login response if available
      if (response.containsKey('user') && response['user'] != null) {
        _user = response['user'] as Map<String, dynamic>;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        
        // Optionally refresh profile data in the background (non-blocking)
        _apiService.getProfile().then((profile) {
          _user = profile;
          notifyListeners();
        }).catchError((e) {
          debugPrint('Profile refresh failed (non-critical): $e');
          // Continue with user data from login response
        });
        
        // Register FCM token after successful login
        try {
          final fcmService = FcmService();
          await fcmService.registerTokenIfAuthenticated();
        } catch (e) {
          debugPrint('FCM token registration failed (non-critical): $e');
        }
        
        return true;
      } else {
        // If no user in response, try to load profile
        try {
          _user = await _apiService.getProfile();
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
          
          // Register FCM token after successful login
          try {
            final fcmService = FcmService();
            await fcmService.registerTokenIfAuthenticated();
          } catch (e) {
            debugPrint('FCM token registration failed (non-critical): $e');
          }
          
          return true;
        } catch (e) {
          throw Exception('Login succeeded but user data not available');
        }
      }
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

  Future<void> loadProfile() async {
    try {
      _user = await _apiService.getProfile();
      notifyListeners();
    } catch (e) {
      _user = null;
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
      _user = await _apiService.getProfile();
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
    }
  }
}

