import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
}

class FcmService {
  final ApiService _apiService = ApiService();
  FirebaseMessaging? _messaging;
  String? _currentToken;
  StreamSubscription<String>? _tokenSubscription;

  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _messaging = FirebaseMessaging.instance;

      // Request permission for notifications
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Configure foreground notification presentation
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token
      _currentToken = await _messaging!.getToken();
      if (_currentToken != null) {
        debugPrint('FCM Token: $_currentToken');
        await _saveToken(_currentToken!);
      }

      // Listen for token refresh
      _tokenSubscription = _messaging!.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _currentToken = newToken;
        _saveToken(newToken);
        _registerTokenIfAuthenticated(newToken);
      });

      // Set up message handlers
      _setupMessageHandlers();

      _initialized = true;
      debugPrint('FCM Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FCM Service: $e');
    }
  }

  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
      debugPrint('Message data: ${message.data}');
      debugPrint('Message notification: ${message.notification?.title}');

      // You can show a local notification here or update UI
      // For now, we'll just log it
    });

    // Handle notification taps when app is in background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped: ${message.messageId}');
      debugPrint('Message data: ${message.data}');
      _handleNotificationTap(message);
    });

    // Check if app was opened from a terminated state via notification
    _messaging!.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state via notification');
        _handleNotificationTap(message);
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on notification data
    final data = message.data;
    if (data.containsKey('requestId') && data['requestId'] != null) {
      // Navigate to trip details
      debugPrint('Navigate to trip: ${data['requestId']}');
      // You can use a navigator key or event bus here to navigate
    }
  }

  String? get currentToken => _currentToken;

  String _getPlatform() {
    if (kIsWeb) {
      return 'web';
    } else {
      // For mobile platforms
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'android';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ios';
      }
    }
    return 'unknown';
  }

  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<String?> _getSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      debugPrint('Error getting saved FCM token: $e');
      return null;
    }
  }

  Future<void> registerTokenIfAuthenticated() async {
    if (_currentToken != null) {
      await _registerTokenIfAuthenticated(_currentToken!);
    } else {
      // Try to get saved token
      final savedToken = await _getSavedToken();
      if (savedToken != null) {
        _currentToken = savedToken;
        await _registerTokenIfAuthenticated(savedToken);
      }
    }
  }

  Future<void> _registerTokenIfAuthenticated(String token) async {
    try {
      // Check if user is authenticated
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');
      
      if (authToken == null) {
        debugPrint('User not authenticated, skipping token registration');
        return;
      }

      final platform = _getPlatform();
      final deviceName = await _getDeviceName();

      await _apiService.registerDeviceToken(token, platform, deviceName: deviceName);
      debugPrint('FCM token registered successfully');
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      if (_currentToken != null) {
        await _apiService.unregisterDeviceToken(_currentToken!);
        debugPrint('FCM token unregistered successfully');
      }
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }

  Future<String?> _getDeviceName() async {
    try {
      if (kIsWeb) {
        return 'Web Browser';
      } else {
        if (defaultTargetPlatform == TargetPlatform.android) {
          return 'Android Device';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          return 'iOS Device';
        }
      }
      return 'Unknown Device';
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
  }
}

