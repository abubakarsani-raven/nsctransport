import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../firebase_options.dart';
import '../utils/custom_toast.dart';
import '../screens/request_details_screen.dart';

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized (should be initialized in main.dart)
  // This is a safety check for background message handling
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Background message title: ${message.notification?.title}');
  debugPrint('Background message body: ${message.notification?.body}');
  debugPrint('Background message data: ${message.data}');
  
  // Note: In background handler, we can't update UI directly
  // The notification will be shown by the system
  // When user taps the notification, onMessageOpenedApp will be called
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
  
  // Callbacks for UI updates
  VoidCallback? _onNotificationReceived;
  VoidCallback? _onNotificationRefresh;
  
  // Set callback for notification updates
  void setNotificationCallbacks({
    VoidCallback? onNotificationReceived,
    VoidCallback? onNotificationRefresh,
  }) {
    _onNotificationReceived = onNotificationReceived;
    _onNotificationRefresh = onNotificationRefresh;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      // Initialize Firebase if not already initialized (should be initialized in main.dart)
      // This is a safety check in case FCM service is initialized before main.dart
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
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

      // Show notification toast when app is in foreground
      _showForegroundNotification(message);
      
      // Refresh notifications list and unread count
      _refreshNotifications();
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
        // Add a small delay to ensure app is fully initialized before navigating
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationTap(message);
        });
      }
    });
  }
  
  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    
    final title = notification.title ?? 'New Notification';
    final body = notification.body ?? '';
    final data = message.data;
    final requestId = data['requestId'];
    
    // Show toast notification
    try {
      CustomToast.showSimpleNotification(
        GestureDetector(
          onTap: () {
            // Navigate when toast is tapped
            if (requestId != null && requestId.toString().isNotEmpty) {
              _navigateToRequest(requestId.toString());
            }
          },
          child: Row(
            children: [
              const Icon(Icons.notifications, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 4),
        position: NotificationPosition.top,
      );
    } catch (e) {
      debugPrint('Error showing foreground notification: $e');
    }
  }
  
  void _refreshNotifications() {
    // Trigger notification refresh callback if set
    _onNotificationReceived?.call();
    _onNotificationRefresh?.call();
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on notification data
    final data = message.data;
    final requestId = data['requestId'];
    final notificationId = data['notificationId'];
    
    if (requestId != null && requestId.toString().isNotEmpty) {
      // Navigate to request details screen
      _navigateToRequest(requestId.toString());
    } else if (notificationId != null) {
      // Navigate to notifications screen if no requestId
      _navigateToNotifications();
    }
    
    // Refresh notifications after navigation
    _refreshNotifications();
  }
  
  void _navigateToRequest(String requestId) {
    try {
      // Helper function to perform navigation
      void performNavigation() {
        final navigator = CustomToast.navigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => RequestDetailsScreen(
                requestId: requestId,
              ),
            ),
          );
        }
      }
      
      // Try immediate navigation
      final navigator = CustomToast.navigatorKey.currentState;
      if (navigator != null && navigator.mounted) {
        performNavigation();
      } else {
        debugPrint('Navigator not available, scheduling navigation...');
        // Schedule navigation for when navigator is available
        // Try multiple times with increasing delays
        Future.delayed(const Duration(milliseconds: 100), () {
          performNavigation();
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          performNavigation();
        });
        Future.delayed(const Duration(milliseconds: 1000), () {
          performNavigation();
        });
      }
    } catch (e) {
      debugPrint('Error navigating to request: $e');
    }
  }
  
  void _navigateToNotifications() {
    try {
      final navigator = CustomToast.navigatorKey.currentState;
      if (navigator == null) {
        debugPrint('Navigator not available for notification navigation');
        return;
      }
      
      // Navigate to notifications screen (you may need to adjust this based on your routing)
      // For now, we'll just refresh notifications
      _refreshNotifications();
    } catch (e) {
      debugPrint('Error navigating to notifications: $e');
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

