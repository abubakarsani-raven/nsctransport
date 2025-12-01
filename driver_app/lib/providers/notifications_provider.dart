import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class NotificationsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<dynamic> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _apiService.getNotifications();
      _unreadCount = _notifications.where((n) => n['read'] == false).length;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notifications = [];
      _unreadCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    await loadNotifications();
  }

  void handleRealtimeUpdate(dynamic payload) {
    // Handle real-time notification updates
    loadNotifications();
  }
}

