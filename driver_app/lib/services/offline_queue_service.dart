import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/offline_storage.dart';
import 'api_service.dart';

class OfflineQueueService {
  final ApiService _apiService = ApiService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isSyncing = false;
  Timer? _syncTimer;

  // Callbacks
  Function(bool isOnline)? onConnectionStatusChanged;

  bool get isOnline => _isOnline;

  /// Initialize the service
  Future<void> initialize() async {
    // Check initial connectivity
    final ConnectivityResult result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (_isOnline != wasOnline) {
        onConnectionStatusChanged?.call(_isOnline);
        if (_isOnline) {
          // Start syncing when connection is restored
          syncPendingData();
        }
      }
    });

    // Start periodic sync timer
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline && !_isSyncing) {
        syncPendingData();
      }
    });

    // Initial sync if online
    if (_isOnline) {
      syncPendingData();
    }
  }

  /// Sync all pending data
  Future<void> syncPendingData() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;

    try {
      // Sync pending API calls
      await _syncPendingCalls();

      // Note: Location sync is handled by TripTrackingService
    } catch (e) {
      // Log error but don't throw
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync pending API calls
  Future<void> _syncPendingCalls() async {
    final pendingCalls = await OfflineStorage.getPendingCalls(limit: 20);

    for (final call in pendingCalls) {
      try {
        final endpoint = call['endpoint'] as String;
        final method = call['method'] as String;
        final bodyStr = call['body'] as String?;
        final headersStr = call['headers'] as String?;

        Map<String, dynamic>? body;
        Map<String, String>? headers;

        if (bodyStr != null) {
          body = jsonDecode(bodyStr) as Map<String, dynamic>;
        }
        if (headersStr != null) {
          headers = Map<String, String>.from(
            jsonDecode(headersStr) as Map,
          );
        }

        // Execute the API call
        await _executeApiCall(endpoint, method, body, headers);

        // Delete from queue on success
        await OfflineStorage.deletePendingCall(call['id'] as int);
      } catch (e) {
        // Increment retry count
        await OfflineStorage.incrementRetryCount(call['id'] as int);

        // Remove if retry count exceeds limit
        final retryCount = call['retry_count'] as int;
        if (retryCount >= 5) {
          await OfflineStorage.deletePendingCall(call['id'] as int);
        }
      }
    }
  }

  /// Execute API call
  Future<void> _executeApiCall(
    String endpoint,
    String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  ) async {
    // This is a simplified version - in reality, you'd need to handle
    // different HTTP methods and endpoints
    // For now, we'll just queue location updates which are handled separately
    // Other API calls would need to be implemented based on ApiService methods
  }

  /// Queue an API call for later execution
  Future<void> queueApiCall({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (_isOnline) {
      // Try to execute immediately
      try {
        await _executeApiCall(endpoint, method, body, headers);
        return;
      } catch (e) {
        // If it fails, queue it
      }
    }

    // Queue for later
    await OfflineStorage.savePendingCall(
      endpoint: endpoint,
      method: method,
      body: body,
      headers: headers,
    );
  }

  /// Get storage statistics
  Future<Map<String, int>> getStorageStats() async {
    return await OfflineStorage.getStorageStats();
  }

  /// Clear all offline data
  Future<void> clearAllData() async {
    await OfflineStorage.clearCache();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }
}

