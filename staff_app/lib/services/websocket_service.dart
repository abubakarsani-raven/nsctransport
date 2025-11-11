import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class WebSocketService {
  static WebSocketService? _instance;
  IO.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // Stream controllers for different data types
  final _requestsController = StreamController<dynamic>.broadcast();
  final _usersController = StreamController<dynamic>.broadcast();
  final _notificationsController = StreamController<dynamic>.broadcast();
  final _historyController = StreamController<dynamic>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Getters for streams
  Stream<dynamic> get requestsStream => _requestsController.stream;
  Stream<dynamic> get usersStream => _usersController.stream;
  Stream<dynamic> get notificationsStream => _notificationsController.stream;
  Stream<dynamic> get historyStream => _historyController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;

  WebSocketService._();

  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  // Get WebSocket URL from ApiConfig
  // Socket.IO handles both http:// and https:// automatically
  String get _baseUrl => ApiConfig.baseUrl;

  Future<void> connect() async {
    if (_isConnecting || _isConnected) {
      debugPrint('WebSocket already connecting or connected');
      return;
    }

    _isConnecting = true;
    _reconnectAttempts = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        debugPrint('No token found, cannot connect WebSocket');
        _isConnecting = false;
        return;
      }

      debugPrint('Connecting to WebSocket at $_baseUrl');

      _socket = IO.io(
        _baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(_maxReconnectAttempts)
            .build(),
      );

      _setupEventListeners();
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      debugPrint('WebSocket connected');
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionController.add(true);
      _subscribeToChannels();
    });

    _socket!.onDisconnect((_) {
      debugPrint('WebSocket disconnected');
      _isConnected = false;
      _isConnecting = false;
      _connectionController.add(false);
      _scheduleReconnect();
    });

    _socket!.onConnectError((error) {
      debugPrint('WebSocket connection error: $error');
      _isConnected = false;
      _isConnecting = false;
      _connectionController.add(false);
      _scheduleReconnect();
    });

    _socket!.onError((error) {
      debugPrint('WebSocket error: $error');
    });

    // Listen for data updates
    _socket!.on('requests:updated', (data) {
      debugPrint('Received requests:updated event');
      _requestsController.add(data);
    });

    _socket!.on('users:updated', (data) {
      debugPrint('Received users:updated event');
      _usersController.add(data);
    });

    _socket!.on('notifications:new', (data) {
      debugPrint('Received notifications:new event');
      _notificationsController.add(data);
    });

    _socket!.on('history:updated', (data) {
      debugPrint('Received history:updated event');
      _historyController.add(data);
    });
  }

  void _subscribeToChannels() {
    if (_socket == null || !_isConnected) return;

    debugPrint('Subscribing to WebSocket channels');
    _socket!.emit('subscribe:requests');
    _socket!.emit('subscribe:users');
    _socket!.emit('subscribe:notifications');
    _socket!.emit('subscribe:history');
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    debugPrint('Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts');

    _reconnectTimer = Timer(_reconnectDelay * _reconnectAttempts, () {
      if (!_isConnected && !_isConnecting) {
        connect();
      }
    });
  }

  void disconnect() {
    debugPrint('Disconnecting WebSocket');
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _reconnectAttempts = 0;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _requestsController.close();
    _usersController.close();
    _notificationsController.close();
    _historyController.close();
    _connectionController.close();
  }
}


