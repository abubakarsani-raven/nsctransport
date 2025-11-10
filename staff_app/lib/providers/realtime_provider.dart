import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/websocket_service.dart';

class RealtimeProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService.instance;
  bool _isConnected = false;
  bool _usePolling = false;
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 30);

  // Callbacks for data refresh
  VoidCallback? _onRequestsUpdate;
  VoidCallback? _onUsersUpdate;
  void Function(dynamic data)? _onNotificationsUpdate;
  void Function(dynamic data)? _onHistoryUpdate;

  bool get isConnected => _isConnected;
  bool get usePolling => _usePolling;

  RealtimeProvider() {
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to connection status
    _webSocketService.connectionStream.listen((connected) {
      _isConnected = connected;
      _usePolling = !connected;
      
      if (connected) {
        _stopPolling();
        debugPrint('WebSocket connected, stopping polling');
      } else {
        _startPolling();
        debugPrint('WebSocket disconnected, starting polling');
      }
      
      notifyListeners();
    });

    // Listen to requests updates
    _webSocketService.requestsStream.listen((data) {
      debugPrint('RealtimeProvider: Requests updated via WebSocket');
      _onRequestsUpdate?.call();
    });

    // Listen to users updates
    _webSocketService.usersStream.listen((data) {
      debugPrint('RealtimeProvider: Users updated via WebSocket');
      _onUsersUpdate?.call();
    });

    // Listen to notifications updates
    _webSocketService.notificationsStream.listen((data) {
      debugPrint('RealtimeProvider: Notifications updated via WebSocket');
      _onNotificationsUpdate?.call(data);
    });

    _webSocketService.historyStream.listen((data) {
      debugPrint('RealtimeProvider: History updated via WebSocket');
      _onHistoryUpdate?.call(data);
    });
  }

  Future<void> connect() async {
    await _webSocketService.connect();
  }

  void disconnect() {
    _webSocketService.disconnect();
    _stopPolling();
  }

  void setRequestsUpdateCallback(VoidCallback callback) {
    _onRequestsUpdate = callback;
  }

  void setUsersUpdateCallback(VoidCallback callback) {
    _onUsersUpdate = callback;
  }

  void setNotificationsUpdateCallback(void Function(dynamic data) callback) {
    _onNotificationsUpdate = callback;
  }

  void setHistoryUpdateCallback(void Function(dynamic data) callback) {
    _onHistoryUpdate = callback;
  }

  void _startPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      return;
    }

    debugPrint('Starting polling with interval ${_pollingInterval.inSeconds}s');
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      if (!_isConnected) {
        debugPrint('Polling: Triggering data refresh');
        _onRequestsUpdate?.call();
        _onUsersUpdate?.call();
        _onNotificationsUpdate?.call(null);
        _onHistoryUpdate?.call(null);
      } else {
        _stopPolling();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void triggerImmediateRefresh() {
    debugPrint('Triggering immediate data refresh');
    _onRequestsUpdate?.call();
    _onUsersUpdate?.call();
    _onNotificationsUpdate?.call(null);
    _onHistoryUpdate?.call(null);
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}






