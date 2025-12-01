import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../modules/trips/screens/upcoming_trips_screen.dart';
import '../../modules/trips/screens/trip_history_screen.dart';
import '../../modules/vehicle/screens/vehicle_info_screen.dart';
import '../../modules/vehicle/screens/maintenance_reminders_screen.dart';
import '../../modules/faults/screens/fault_history_screen.dart';

class DriverDrawerShell extends StatefulWidget {
  const DriverDrawerShell({super.key, this.initialItemAlias});

  final String? initialItemAlias;

  @override
  State<DriverDrawerShell> createState() => _DriverDrawerShellState();
}

class _DriverDrawerShellState extends State<DriverDrawerShell> {
  late final AdvancedDrawerController _drawerController;
  late String _currentAlias;

  @override
  void initState() {
    super.initState();
    _drawerController = AdvancedDrawerController();
    _currentAlias = widget.initialItemAlias ?? 'dashboard';
  }

  void _handleMenuButtonPressed() {
    _drawerController.toggleDrawer();
  }

  void _handleSelectAlias(String alias) {
    if (_currentAlias == alias) {
      _drawerController.hideDrawer();
      return;
    }
    setState(() {
      _currentAlias = alias;
    });
    _drawerController.hideDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final items = _buildDrawerItems(authProvider);

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    var resolvedAlias = _currentAlias;
    if (!items.any((item) => item.alias == resolvedAlias)) {
      resolvedAlias = items.first.alias;
      if (_currentAlias != resolvedAlias) {
        _currentAlias = resolvedAlias;
      }
    }

    final currentItem = items.firstWhere(
      (item) => item.alias == resolvedAlias,
      orElse: () => items.first,
    );

    final currentPage = currentItem.buildPage(_handleMenuButtonPressed);

    return ListenableProvider<AdvancedDrawerController>.value(
      value: _drawerController,
      child: AdvancedDrawer(
        controller: _drawerController,
        backdrop: Container(color: Theme.of(context).scaffoldBackgroundColor),
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        animateChildDecoration: true,
        childDecoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
        openScale: 0.9,
        openRatio: 0.72,
        disabledGestures: false,
        drawer: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.85),
                  AppTheme.primaryColor.withOpacity(0.72),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: ListTileTheme(
              iconColor: palette.drawerIconColor,
              textColor: palette.drawerForeground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, authProvider, theme, palette),
                  const SizedBox(height: AppTheme.spacingXL),
                  ...items.map(
                    (item) => _DrawerTile(
                      icon: item.icon,
                      label: item.label,
                      isActive: item.alias == _currentAlias,
                      onTap: () => _handleSelectAlias(item.alias),
                    ),
                  ),
                  const Spacer(),
                  _buildFooter(context, themeProvider),
                ],
              ),
            ),
          ),
        ),
        child: currentPage,
      ),
    );
  }

  List<_DrawerItem> _buildDrawerItems(AuthProvider authProvider) {
    return [
      _DrawerItem(
        alias: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_customize_rounded,
        buildPage: (openDrawer) => DashboardScreen(onMenuPressed: openDrawer),
      ),
      _DrawerItem(
        alias: 'upcoming_trips',
        label: 'Upcoming Trips',
        icon: Icons.schedule_rounded,
        buildPage: (openDrawer) => UpcomingTripsScreen(onMenuPressed: openDrawer),
      ),
      _DrawerItem(
        alias: 'trip_history',
        label: 'Trip History',
        icon: Icons.history_rounded,
        buildPage: (openDrawer) => TripHistoryScreen(onMenuPressed: openDrawer),
      ),
      _DrawerItem(
        alias: 'vehicle_info',
        label: 'Vehicle Info',
        icon: Icons.directions_car_rounded,
        buildPage: (openDrawer) => VehicleInfoScreen(onMenuPressed: openDrawer),
      ),
      _DrawerItem(
        alias: 'maintenance',
        label: 'Maintenance',
        icon: Icons.build_rounded,
        buildPage: (openDrawer) => MaintenanceRemindersScreen(onMenuPressed: openDrawer),
      ),
      _DrawerItem(
        alias: 'faults',
        label: 'Fault Reports',
        icon: Icons.report_problem_rounded,
        buildPage: (openDrawer) => FaultHistoryScreen(onMenuPressed: openDrawer),
      ),
      _DrawerItem(
        alias: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        buildPage: (openDrawer) => NotificationsScreen(onMenuPressed: openDrawer),
      ),
    ];
  }

  Widget _buildHeader(
    BuildContext context,
    AuthProvider authProvider,
    ThemeData theme,
    AppPalette palette,
  ) {
    final user = authProvider.user;
    final userName = user?['name'] ?? 'Driver';
    final userEmail = user?['email'] ?? '';

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL, vertical: AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: palette.drawerAvatarBackground,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'D',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            userName,
            style: theme.textTheme.titleLarge?.copyWith(
              color: palette.drawerForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (userEmail.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              userEmail,
              style: TextStyle(color: palette.drawerSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeProvider themeProvider) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.brightness_6_rounded, color: palette.drawerSecondary),
            title: Text(
              'Dark Mode',
              style: theme.textTheme.bodyLarge?.copyWith(color: palette.drawerForeground),
            ),
            value: themeProvider.isDark,
            onChanged: (value) {
              themeProvider.setTheme(value ? ThemeMode.dark : ThemeMode.light);
            },
            activeColor: palette.drawerForeground,
            inactiveThumbColor: palette.drawerForeground,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, color: palette.drawerIconColor),
            title: Text(
              'Logout',
              style: theme.textTheme.bodyLarge?.copyWith(color: palette.drawerForeground),
            ),
            onTap: () async {
              final authProvider = context.read<AuthProvider>();
              await authProvider.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
        ],
      ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem({
    required this.alias,
    required this.label,
    required this.icon,
    required this.buildPage,
  });

  final String alias;
  final String label;
  final IconData icon;
  final Widget Function(VoidCallback openDrawer) buildPage;
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: palette.drawerIconColor),
      title: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.drawerForeground,
        ),
      ),
      selected: isActive,
      selectedTileColor: palette.drawerBadgeBackground,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusM),
      onTap: onTap,
    );
  }
}

