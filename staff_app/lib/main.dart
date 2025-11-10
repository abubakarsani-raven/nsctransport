import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/requests_provider.dart';
import 'providers/realtime_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transport_officer_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/request_history_provider.dart';
import 'modules/vehicle/providers/vehicle_requests_provider.dart';
import 'modules/ict/providers/ict_requests_provider.dart';
import 'modules/store/providers/store_requests_provider.dart';
import 'screens/login_screen.dart';
import 'screens/create_request_screen.dart';
import 'theme/app_breakpoints.dart';
import 'theme/app_theme.dart';
import 'utils/custom_toast.dart';
import 'widgets/navigation/staff_drawer_shell.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with options from firebase_options.dart
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue even if Firebase fails to initialize (for development)
  }
  
  // Initialize FCM Service
  try {
    final fcmService = FcmService();
    await fcmService.initialize();
  } catch (e) {
    debugPrint('FCM Service initialization error: $e');
    // Continue even if FCM fails to initialize
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
        ChangeNotifierProvider(create: (_) => RequestsProvider()),
        ChangeNotifierProvider(create: (_) => VehicleRequestsProvider()),
        ChangeNotifierProvider(create: (_) => IctRequestsProvider()),
        ChangeNotifierProvider(create: (_) => StoreRequestsProvider()),
        ChangeNotifierProvider(create: (_) => RealtimeProvider()),
        ChangeNotifierProvider(create: (_) => TransportOfficerProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => RequestHistoryProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
        navigatorKey: CustomToast.navigatorKey,
        title: 'Transport Management - Staff',
        theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) => ResponsiveBreakpoints.builder(
            breakpoints: AppBreakpoints.responsiveBreakpoints,
            child: BouncingScrollWrapper.builder(
              context,
              child ?? const SizedBox(),
            ),
          ),
          scrollBehavior: const _AppScrollBehavior(),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
            '/dashboard': (context) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              return StaffDrawerShell(
                key: ValueKey(authProvider.user?['_id'] ?? authProvider.user?['id'] ?? 'guest'),
              );
            },
            '/transport-officer': (context) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              return StaffDrawerShell(
                key: ValueKey(authProvider.user?['_id'] ?? authProvider.user?['id'] ?? 'guest'),
              );
            },
            '/create-request': (context) => const CreateRequestScreen(),
        },
        ),
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _didSetupRealtime = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.loadProfile().then((_) {
        // Connect WebSocket after authentication check
        if (authProvider.isAuthenticated) {
          final realtimeProvider = Provider.of<RealtimeProvider>(context, listen: false);
          realtimeProvider.connect();
        }
      });
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
          // Setup real-time callbacks when authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _didSetupRealtime) {
              return;
            }

            _didSetupRealtime = true;

            final realtimeProvider = Provider.of<RealtimeProvider>(context, listen: false);
            final requestsProvider = Provider.of<RequestsProvider>(context, listen: false);
            final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
            final historyProvider = Provider.of<RequestHistoryProvider>(context, listen: false);

            realtimeProvider.setRequestsUpdateCallback(() {
              requestsProvider.loadRequests();
            });

            realtimeProvider.setNotificationsUpdateCallback((payload) {
              notificationsProvider.handleRealtimeUpdate(payload);
            });

            realtimeProvider.setHistoryUpdateCallback((payload) {
              historyProvider.handleRealtimeUpdate(payload);
            });

            // Set up FCM service callbacks for notification updates
            final fcmService = FcmService();
            fcmService.setNotificationCallbacks(
              onNotificationReceived: () {
                // Refresh notifications list when push notification is received
                notificationsProvider.loadNotifications();
              },
              onNotificationRefresh: () {
                // Refresh unread count when notification is received
                notificationsProvider.refreshUnreadCount();
              },
            );

            // Initial data load
            requestsProvider.loadRequests();
            notificationsProvider.loadNotifications();
            notificationsProvider.refreshUnreadCount();
            historyProvider.loadHistory();

            realtimeProvider.connect();
          });

          return StaffDrawerShell(
            key: ValueKey(authProvider.user?['_id'] ?? authProvider.user?['id'] ?? 'guest'),
          );
        }

        // Disconnect WebSocket on logout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _didSetupRealtime = false;
          Provider.of<RealtimeProvider>(context, listen: false).disconnect();
        });

        return const LoginScreen();
      },
    );
  }
}
