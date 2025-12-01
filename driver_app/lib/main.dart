import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'firebase_options.dart';
import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/trips_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/location_provider.dart';
import 'providers/trip_tracking_provider.dart';
import 'providers/notifications_provider.dart';
import 'modules/vehicle/providers/vehicle_provider.dart';
import 'modules/faults/providers/faults_provider.dart';
import 'screens/login_screen.dart';
import 'widgets/navigation/driver_drawer_shell.dart';
import 'services/fcm_service.dart';
import 'services/offline_queue_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_breakpoints.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    if (kReleaseMode) {
      await dotenv.load(fileName: '.env.production');
      debugPrint('Loaded production environment variables');
    } else {
      await dotenv.load(fileName: '.env');
      debugPrint('Loaded development environment variables');
    }
    debugPrint('Env API_BASE_URL: ${dotenv.env['API_BASE_URL'] ?? 'Not set'}');
    debugPrint('Resolved API base URL: ${ApiConfig.baseUrl}');
  } catch (e) {
    debugPrint('Error loading environment variables: $e');
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // App continues without Firebase - notifications won't work but core features will
  }
  
  // Initialize FCM Service
  try {
    final fcmService = FcmService();
    await fcmService.initialize();
  } catch (e) {
    debugPrint('FCM Service initialization error: $e');
  }
  
  // Initialize offline queue service
  try {
    final offlineService = OfflineQueueService();
    await offlineService.initialize();
  } catch (e) {
    debugPrint('Offline queue service initialization error: $e');
  }
  
  Animate.restartOnHotReload = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripsProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => TripTrackingProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => FaultsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
        title: 'Transport Management - Driver',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) => ResponsiveBreakpoints.builder(
            breakpoints: AppBreakpoints.responsiveBreakpoints,
            child: child ?? const SizedBox(),
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
            '/dashboard': (context) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              return DriverDrawerShell(
                key: ValueKey(authProvider.user?['_id'] ?? authProvider.user?['id'] ?? 'guest'),
              );
            },
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated) {
          // Double-check that user has driver role before allowing access
          if (!authProvider.isDriver()) {
            // User doesn't have driver role - show login screen
            return const LoginScreen();
          }
          return DriverDrawerShell(
            key: ValueKey(authProvider.user?['_id'] ?? authProvider.user?['id'] ?? 'guest'),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
