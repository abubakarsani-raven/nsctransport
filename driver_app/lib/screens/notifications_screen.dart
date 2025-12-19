import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notifications_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation/drawer_menu_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationsProvider>(context, listen: false).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: DrawerMenuButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Notifications'),
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, notificationsProvider, _) {
          if (notificationsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notificationsProvider.notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => notificationsProvider.loadNotifications(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: AppTheme.neutral40),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          'No notifications',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'Pull down to refresh',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.neutral60,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => notificationsProvider.loadNotifications(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: notificationsProvider.notifications.length,
              itemBuilder: (context, index) {
                final notification = notificationsProvider.notifications[index];
                final isRead = notification['read'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  color: isRead ? null : AppTheme.primaryColor.withOpacity(0.05),
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications,
                      color: isRead ? AppTheme.neutral40 : AppTheme.primaryColor,
                    ),
                    title: Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification['message'] ?? ''),
                        if (notification['createdAt'] != null)
                          Text(
                            DateFormat('MMM dd, yyyy HH:mm').format(
                              DateTime.parse(notification['createdAt']),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

