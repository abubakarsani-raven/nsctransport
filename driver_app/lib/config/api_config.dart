import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/platform_helper.dart';

class ApiConfig {
  // Get API base URL based on environment and platform
  static String get baseUrl {
    // Try to get from environment variable first
    String? envUrl;
    try {
      envUrl = dotenv.env['API_BASE_URL'];
    } catch (e) {
      // If dotenv is not loaded, envUrl will be null and we'll use fallback
    }
    
    // If in release mode (production), use Railway URL
    if (kReleaseMode) {
      // Use environment variable if set, otherwise fall back to Railway URL
      if (envUrl != null && envUrl.isNotEmpty) {
        return envUrl;
      }
      return 'https://nsctransport-production.up.railway.app';
    }
    
    // Development mode - use environment variable or localhost
    if (envUrl != null && envUrl.isNotEmpty) {
      // Handle Android emulator special case
      // Android emulator needs 10.0.2.2 to access host machine's localhost
      if (PlatformHelper.isAndroid && envUrl.contains('localhost')) {
        return envUrl.replaceAll('localhost', '10.0.2.2');
      }
      return envUrl;
    }
    
    // Fallback to localhost (development) when .env file is not found
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    
    if (PlatformHelper.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    
    return 'http://localhost:3000';
  }
  
  // Check if we're in production mode
  static bool get isProduction => kReleaseMode;
  
  // Check if we're in development mode
  static bool get isDevelopment => kDebugMode;
  
  // Get WebSocket URL (Socket.IO handles http/https automatically)
  static String get websocketUrl => baseUrl;
}

