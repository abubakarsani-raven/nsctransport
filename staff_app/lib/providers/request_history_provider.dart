import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class RequestHistoryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  final List<dynamic> _history = [];
  bool _isLoading = false;
  DateTime? _lastLoadedAt;

  List<dynamic> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  DateTime? get lastLoadedAt => _lastLoadedAt;

  Future<void> loadHistory({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _lastLoadedAt != null) {
      final elapsed = DateTime.now().difference(_lastLoadedAt!);
      if (elapsed.inSeconds < 10) {
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.getRequestHistory();
      _history
        ..clear()
        ..addAll(result);
      _lastLoadedAt = DateTime.now();
    } catch (error) {
      debugPrint('RequestHistoryProvider.loadHistory error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void handleRealtimeUpdate(dynamic payload) {
    // Regardless of payload shape, trigger a refresh to keep data in sync
    loadHistory(force: true);
  }
}

