import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class NotificationsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  final List<dynamic> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  DateTime? _lastSyncedAt;

  List<dynamic> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  Future<void> loadNotifications({bool force = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.getNotifications();
      _notifications
        ..clear()
        ..addAll(result);

      _unreadCount = _notifications.where((n) => !(n['read'] as bool? ?? false)).length;
      _lastSyncedAt = DateTime.now();
    } catch (error) {
      debugPrint('NotificationsProvider.loadNotifications error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _apiService.getUnreadNotificationCount();
      notifyListeners();
    } catch (error) {
      debugPrint('NotificationsProvider.refreshUnreadCount error: $error');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final response = await _apiService.markNotificationAsRead(id);
      final unread = response['unread'];
      if (unread is int) {
        _unreadCount = unread;
      }

      final index = _notifications.indexWhere((notification) => notification['_id'] == id);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(_notifications[index] as Map);
        updated['read'] = true;
        _notifications[index] = updated;
      }

      notifyListeners();
    } catch (error) {
      debugPrint('NotificationsProvider.markAsRead error: $error');
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
      _unreadCount = 0;
      for (var i = 0; i < _notifications.length; i++) {
        final updated = Map<String, dynamic>.from(_notifications[i] as Map);
        updated['read'] = true;
        _notifications[i] = updated;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('NotificationsProvider.markAllAsRead error: $error');
      rethrow;
    }
  }

  void handleRealtimeUpdate(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      // Fallback to reload when payload is unknown
      loadNotifications();
      refreshUnreadCount();
      return;
    }

    final type = payload['type']?.toString();
    final notification = payload['notification'];
    final unread = payload['unread'];

    if (unread is int) {
      _unreadCount = unread;
    }

    if (notification is Map<String, dynamic>) {
      final id = notification['_id']?.toString();
      if (id != null) {
        final existingIndex = _notifications.indexWhere((item) => item['_id'] == id);
        if (type == 'created') {
          if (existingIndex != -1) {
            _notifications.removeAt(existingIndex);
          }
          _notifications.insert(0, notification);
        } else {
          if (existingIndex != -1) {
            _notifications[existingIndex] = notification;
          } else {
            _notifications.insert(0, notification);
          }
        }
      }
    } else if (type == 'created') {
      // Unknown notification payload, trigger a full refresh
      loadNotifications();
    }

    notifyListeners();
  }
}

