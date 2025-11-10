import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/transport_officer_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/recent_activity_screen.dart';
import '../../modules/vehicle/screens/vehicle_requests_list_screen.dart';
import '../../modules/ict/screens/ict_requests_list_screen.dart';
import '../../modules/store/screens/store_requests_list_screen.dart';
import 'drawer_controller_scope.dart';

class StaffDrawerShell extends StatefulWidget {
  const StaffDrawerShell({super.key, this.initialItemAlias});

  final String? initialItemAlias;

  @override
  State<StaffDrawerShell> createState() => _StaffDrawerShellState();
}

class _StaffDrawerShellState extends State<StaffDrawerShell> {
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
    setState(() => _currentAlias = alias);
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
      child: DrawerControllerScope(
        controller: _drawerController,
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
      ),
    );
  }

  List<_DrawerItem> _buildDrawerItems(AuthProvider authProvider) {
    final List<_DrawerItem> items = [
      _DrawerItem(
        alias: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_customize_rounded,
        buildPage: (openDrawer) => DashboardScreen(onMenuPressed: openDrawer),
      ),
    ];

    // Allow Transport Officer, DGS, DDGS, and ADTransport to view Fleet Management
    if (authProvider.hasRole('transport_officer') || 
        authProvider.hasRole('dgs') || 
        authProvider.hasRole('ddgs') || 
        authProvider.hasRole('ad_transport')) {
      items.add(
        _DrawerItem(
          alias: 'transport_officer',
          label: 'Transport Officer Hub',
          icon: Icons.local_taxi_rounded,
          buildPage: (openDrawer) => TransportOfficerScreen(onMenuPressed: openDrawer),
        ),
      );
    }

    items.add(
      _DrawerItem(
        alias: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        buildPage: (openDrawer) => NotificationsScreen(onMenuPressed: openDrawer),
      ),
    );

    items.add(
      _DrawerItem(
        alias: 'recent_activity',
        label: 'Recent Activity',
        icon: Icons.history_rounded,
        buildPage: (openDrawer) => RecentActivityScreen(onMenuPressed: openDrawer),
      ),
    );

    items.add(
      _DrawerItem(
        alias: 'vehicle_requests',
        label: 'Transport Requests',
        icon: Icons.directions_car_rounded,
        buildPage: (openDrawer) => VehicleRequestsListScreen(onMenuPressed: openDrawer),
      ),
    );

    items.add(
      _DrawerItem(
        alias: 'ict_requests',
        label: 'ICT Requests',
        icon: Icons.computer_rounded,
        buildPage: (openDrawer) => IctRequestsListScreen(onMenuPressed: openDrawer),
      ),
    );

    items.add(
      _DrawerItem(
        alias: 'store_requests',
        label: 'Store Requests',
        icon: Icons.inventory_2_rounded,
        buildPage: (openDrawer) => StoreRequestsListScreen(onMenuPressed: openDrawer),
      ),
    );

    return items;
  }

  Widget _buildHeader(
    BuildContext context,
    AuthProvider authProvider,
    ThemeData theme,
    AppPalette palette,
  ) {
    final user = authProvider.user;
    final userName = user?['name'] ?? 'User';
    final userEmail = user?['email'] ?? '';
    final roles = authProvider.getRoles();

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
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
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
          if (roles.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingXS,
              children: roles
                  .map(
                    (role) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                      color: palette.drawerBadgeBackground,
                        borderRadius: AppTheme.bradiusS,
                      ),
                      child: Text(
                        role.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        color: palette.drawerBadgeForeground,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (authProvider.isSupervisor()) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingXS / 1.5,
                ),
                decoration: BoxDecoration(
                  color: palette.drawerBadgeBackground,
                  borderRadius: AppTheme.bradiusS,
                ),
                child: Text(
                  'Supervisor',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: palette.drawerBadgeForeground,
                    letterSpacing: .3,
                  ),
                ),
              ),
            ],
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
