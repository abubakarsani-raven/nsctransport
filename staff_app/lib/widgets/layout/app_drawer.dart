import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop();
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final userName = user?['name'] ?? 'User';
    final userEmail = user?['email'] ?? '';
    final userRoles = authProvider.getRoles();

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + AppTheme.spacingL,
              left: AppTheme.spacingL,
              right: AppTheme.spacingL,
              bottom: AppTheme.spacingL,
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: palette.drawerAvatarBackground,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  userName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: palette.drawerForeground,
                  ),
                ),
                if (userEmail.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    userEmail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.drawerSecondary,
                    ),
                  ),
                ],
                if (userRoles.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Wrap(
                    spacing: AppTheme.spacingS,
                    runSpacing: AppTheme.spacingXS,
                    children: userRoles
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
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.drawerBadgeForeground,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.dashboard_rounded, color: theme.iconTheme.color),
                  title: Text('Dashboard', style: theme.textTheme.bodyLarge),
                  onTap: () => _navigate(context, '/dashboard'),
                ),
                if (authProvider.hasRole('transport_officer'))
                  ListTile(
                    leading: Icon(Icons.directions_car_rounded, color: theme.iconTheme.color),
                    title: Text('Transport Officer Hub', style: theme.textTheme.bodyLarge),
                    onTap: () => _navigate(context, '/transport-officer'),
                  ),
                if (authProvider.canCreateRequest())
                  ListTile(
                    leading: Icon(Icons.add_circle_outline_rounded, color: theme.iconTheme.color),
                    title: Text('Create Request', style: theme.textTheme.bodyLarge),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/create-request');
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.notifications_outlined, color: theme.iconTheme.color),
                  title: Text('Notifications', style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: navigate to notifications screen
                  },
                ),
                const Divider(),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) => SwitchListTile(
                    title: Text('Dark Mode', style: theme.textTheme.bodyLarge),
                    secondary: Icon(
                      themeProvider.isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: theme.iconTheme.color,
                    ),
                    value: themeProvider.isDark,
                    onChanged: (value) {
                      themeProvider.setTheme(value ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text(
                'Logout',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

