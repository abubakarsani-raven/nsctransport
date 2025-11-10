import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation/drawer_controller_scope.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _readFilter; // null = all, 'unread', 'read'
  String? _typeFilter; // null = all, or specific notification type
  String? _requestTypeFilter; // null = all, 'vehicle', 'ict', 'store'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _apiService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    await _apiService.markNotificationAsRead(id);
    _loadNotifications();
  }

  void _showNotificationDetails(BuildContext context, dynamic notification) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRead = notification['read'] ?? false;
    final requestType = _getRequestTypeFromNotification(notification);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: BoxDecoration(
                            color: isRead
                                ? colorScheme.surfaceContainerHighest
                                : colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_rounded,
                            color: isRead
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onPrimaryContainer,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['title'] ?? 'Notification',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (requestType != null) ...[
                                const SizedBox(height: AppTheme.spacingXS),
                                Row(
                                  children: [
                                    Icon(
                                      requestType == 'vehicle'
                                          ? Icons.directions_car_rounded
                                          : requestType == 'ict'
                                              ? Icons.computer_rounded
                                              : Icons.inventory_2_rounded,
                                      size: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppTheme.spacingXS),
                                    Text(
                                      requestType.toUpperCase(),
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isRead)
                          IconButton(
                            icon: Icon(
                              Icons.check_circle_outline_rounded,
                              color: colorScheme.primary,
                            ),
                            onPressed: () {
                              _markAsRead(notification['_id']);
                              Navigator.pop(context);
                            },
                            tooltip: 'Mark as read',
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Message
                          Text(
                            'Message',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            notification['message'] ?? '',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppTheme.spacingL),
                          // Details
                          Text(
                            'Details',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildDetailRow(
                            context,
                            Icons.notifications_outlined,
                            'Type',
                            _getNotificationTypeLabel(notification['type']),
                          ),
                          if (notification['createdAt'] != null) ...[
                            const SizedBox(height: AppTheme.spacingS),
                            _buildDetailRow(
                              context,
                              Icons.access_time_rounded,
                              'Date',
                              DateFormat('MMM dd, yyyy HH:mm').format(
                                DateTime.parse(notification['createdAt']),
                              ),
                            ),
                          ],
                          _buildDetailRow(
                            context,
                            Icons.mark_email_read_rounded,
                            'Status',
                            isRead ? 'Read' : 'Unread',
                          ),
                          if (notification['relatedRequestId'] != null) ...[
                            const SizedBox(height: AppTheme.spacingL),
                            Text(
                              'Related Request',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: AppTheme.bradiusM,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.link_rounded,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: Text(
                                      notification['relatedRequestId'],
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppTheme.spacingL),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getRequestTypeFromNotification(dynamic notification) {
    final title = (notification['title'] as String? ?? '').toLowerCase();
    final message = (notification['message'] as String? ?? '').toLowerCase();
    
    if (title.contains('vehicle') || message.contains('vehicle')) {
      return 'vehicle';
    } else if (title.contains('ict') || message.contains('ict')) {
      return 'ict';
    } else if (title.contains('store') || message.contains('store')) {
      return 'store';
    }
    
    // Check if relatedRequestId exists and try to infer from notification type
    // For trip-related notifications, they're likely vehicle requests
    final notificationType = notification['type'] as String?;
    if (notificationType == 'driver_assigned' || 
        notificationType == 'trip_started' || 
        notificationType == 'trip_completed' ||
        notificationType == 'trip_returned') {
      return 'vehicle';
    }
    
    return null; // Unknown request type
  }

  List<dynamic> _getFilteredNotifications() {
    var filtered = List<dynamic>.from(_notifications);
    
    // Filter by read status
    if (_readFilter == 'unread') {
      filtered = filtered.where((n) => !(n['read'] as bool? ?? false)).toList();
    } else if (_readFilter == 'read') {
      filtered = filtered.where((n) => (n['read'] as bool? ?? false)).toList();
    }
    
    // Filter by notification type
    if (_typeFilter != null) {
      filtered = filtered.where((n) => n['type'] == _typeFilter).toList();
    }
    
    // Filter by request type
    if (_requestTypeFilter != null) {
      filtered = filtered.where((n) {
        final requestType = _getRequestTypeFromNotification(n);
        return requestType == _requestTypeFilter;
      }).toList();
    }
    
    return filtered;
  }

  String _getNotificationTypeLabel(String? type) {
    if (type == null) return 'All';
    switch (type) {
      case 'request_created':
        return 'Request Created';
      case 'request_approved':
        return 'Request Approved';
      case 'request_rejected':
        return 'Request Rejected';
      case 'request_resubmitted':
        return 'Request Resubmitted';
      case 'request_needs_correction':
        return 'Needs Correction';
      case 'driver_assigned':
        return 'Driver Assigned';
      case 'trip_started':
        return 'Trip Started';
      case 'trip_completed':
        return 'Trip Completed';
      case 'trip_returned':
        return 'Trip Returned';
      case 'maintenance_reminder':
        return 'Maintenance Reminder';
      default:
        return type;
    }
  }

  Widget _buildFilterChips(BuildContext context) {
    // Get unique notification types
    final types = _notifications
        .map((n) => n['type'] as String?)
        .where((t) => t != null)
        .toSet()
        .toList();
    types.sort();
    
    // Count notifications by filter
    final allCount = _notifications.length;
    final unreadCount = _notifications.where((n) => !(n['read'] as bool? ?? false)).length;
    final readCount = _notifications.where((n) => (n['read'] as bool? ?? false)).length;
    
    final typeCounts = <String, int>{};
    for (final type in types) {
      if (type != null) {
        typeCounts[type] = _notifications.where((n) => n['type'] == type).length;
      }
    }
    
    // Count by request type
    final vehicleCount = _notifications.where((n) => _getRequestTypeFromNotification(n) == 'vehicle').length;
    final ictCount = _notifications.where((n) => _getRequestTypeFromNotification(n) == 'ict').length;
    final storeCount = _notifications.where((n) => _getRequestTypeFromNotification(n) == 'store').length;
    
    return Column(
      children: [
        // First row: Read status and notification type filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Row(
            children: [
              // Read status filters
              _buildFilterChip(
                context,
                label: 'All',
                count: allCount,
                isActive: _readFilter == null && _typeFilter == null && _requestTypeFilter == null,
                onTap: () {
                  setState(() {
                    _readFilter = null;
                    _typeFilter = null;
                    _requestTypeFilter = null;
                  });
                },
                tint: AppTheme.primaryColor,
                icon: Icons.notifications_rounded,
              ),
              const SizedBox(width: AppTheme.spacingS),
              _buildFilterChip(
                context,
                label: 'Unread',
                count: unreadCount,
                isActive: _readFilter == 'unread',
                onTap: () {
                  setState(() {
                    if (_readFilter == 'unread') {
                      _readFilter = null;
                    } else {
                      _readFilter = 'unread';
                    }
                  });
                },
                tint: AppTheme.secondaryColor,
                icon: Icons.mark_email_unread_rounded,
              ),
              const SizedBox(width: AppTheme.spacingS),
              _buildFilterChip(
                context,
                label: 'Read',
                count: readCount,
                isActive: _readFilter == 'read',
                onTap: () {
                  setState(() {
                    if (_readFilter == 'read') {
                      _readFilter = null;
                    } else {
                      _readFilter = 'read';
                    }
                  });
                },
                tint: Colors.grey,
                icon: Icons.mark_email_read_rounded,
              ),
              // Notification type filters
              if (types.isNotEmpty) ...[
                const SizedBox(width: AppTheme.spacingM),
                const VerticalDivider(width: 1, thickness: 1),
                const SizedBox(width: AppTheme.spacingM),
                ...types.map((type) {
                  if (type == null) return const SizedBox.shrink();
                  final count = typeCounts[type] ?? 0;
                  final isActive = _typeFilter == type;
                  Color tint;
                  IconData icon;
                  
                  switch (type) {
                    case 'request_created':
                      tint = Colors.blue;
                      icon = Icons.add_circle_outline_rounded;
                      break;
                    case 'request_approved':
                      tint = Colors.green;
                      icon = Icons.check_circle_outline_rounded;
                      break;
                    case 'request_rejected':
                      tint = Colors.red;
                      icon = Icons.cancel_outlined;
                      break;
                    case 'request_resubmitted':
                      tint = Colors.orange;
                      icon = Icons.refresh_rounded;
                      break;
                    case 'request_needs_correction':
                      tint = Colors.amber;
                      icon = Icons.edit_outlined;
                      break;
                    case 'driver_assigned':
                      tint = Colors.purple;
                      icon = Icons.person_add_outlined;
                      break;
                    case 'trip_started':
                    case 'trip_completed':
                    case 'trip_returned':
                      tint = Colors.teal;
                      icon = Icons.directions_car_rounded;
                      break;
                    case 'maintenance_reminder':
                      tint = Colors.deepOrange;
                      icon = Icons.build_outlined;
                      break;
                    default:
                      tint = AppTheme.primaryColor;
                      icon = Icons.notifications_outlined;
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: AppTheme.spacingS),
                    child: _buildFilterChip(
                      context,
                      label: _getNotificationTypeLabel(type),
                      count: count,
                      isActive: isActive,
                      onTap: () {
                        setState(() {
                          if (_typeFilter == type) {
                            _typeFilter = null;
                          } else {
                            _typeFilter = type;
                          }
                        });
                      },
                      tint: tint,
                      icon: icon,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        // Second row: Request type filters
        if (vehicleCount > 0 || ictCount > 0 || storeCount > 0)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            child: Row(
              children: [
                if (vehicleCount > 0)
                  _buildFilterChip(
                    context,
                    label: 'Vehicle',
                    count: vehicleCount,
                    isActive: _requestTypeFilter == 'vehicle',
                    onTap: () {
                      setState(() {
                        if (_requestTypeFilter == 'vehicle') {
                          _requestTypeFilter = null;
                        } else {
                          _requestTypeFilter = 'vehicle';
                        }
                      });
                    },
                    tint: AppTheme.primaryColor,
                    icon: Icons.directions_car_rounded,
                  ),
                if (vehicleCount > 0) const SizedBox(width: AppTheme.spacingS),
                if (ictCount > 0)
                  _buildFilterChip(
                    context,
                    label: 'ICT',
                    count: ictCount,
                    isActive: _requestTypeFilter == 'ict',
                    onTap: () {
                      setState(() {
                        if (_requestTypeFilter == 'ict') {
                          _requestTypeFilter = null;
                        } else {
                          _requestTypeFilter = 'ict';
                        }
                      });
                    },
                    tint: Colors.blue,
                    icon: Icons.computer_rounded,
                  ),
                if (ictCount > 0) const SizedBox(width: AppTheme.spacingS),
                if (storeCount > 0)
                  _buildFilterChip(
                    context,
                    label: 'Store',
                    count: storeCount,
                    isActive: _requestTypeFilter == 'store',
                    onTap: () {
                      setState(() {
                        if (_requestTypeFilter == 'store') {
                          _requestTypeFilter = null;
                        } else {
                          _requestTypeFilter = 'store';
                        }
                      });
                    },
                    tint: Colors.green,
                    icon: Icons.inventory_2_rounded,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
    required Color tint,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? tint.withOpacity(0.15)
                : theme.colorScheme.surfaceVariant.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? tint.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.15),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: tint.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? tint : tint,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  color: isActive
                      ? tint
                      : AppPalette.of(context).textSecondary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppTheme.spacingXS),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingXS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? tint.withOpacity(0.2)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: isActive
                          ? tint
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        leading: _DrawerLeadingButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: AppTheme.spacingM),
                      Text(
                        'No notifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildFilterChips(context),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: colorScheme.primary,
                        child: Builder(
                          builder: (context) {
                            final filteredNotifications = _getFilteredNotifications();
                            if (filteredNotifications.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_off_rounded,
                                      size: 64,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(height: AppTheme.spacingM),
                                    Text(
                                      'No notifications match the filter',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    SizedBox(height: AppTheme.spacingS),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _readFilter = null;
                                          _typeFilter = null;
                                          _requestTypeFilter = null;
                                        });
                                      },
                                      child: const Text('Clear filters'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
                              itemCount: filteredNotifications.length,
                              itemBuilder: (context, index) {
                                final notification = filteredNotifications[index];
                      final isRead = notification['read'] ?? false;
                      return Dismissible(
                        key: Key(notification['_id'] ?? index.toString()),
                        onDismissed: (direction) {
                          if (!isRead) {
                            _markAsRead(notification['_id']);
                          }
                        },
                        background: Container(
                          color: colorScheme.primaryContainer,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                          child: Icon(
                            Icons.check_rounded,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        child: Card(
                          elevation: AppTheme.elevation1,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.bradiusL,
                          ),
                          color: isRead
                              ? null
                              : colorScheme.primaryContainer.withOpacity(0.3),
                          margin: EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingS,
                          ),
                          child: InkWell(
                            onTap: () => _showNotificationDetails(context, notification),
                            borderRadius: AppTheme.bradiusL,
                            child: ListTile(
                              contentPadding: EdgeInsets.all(AppTheme.spacingM),
                              leading: Container(
                                padding: EdgeInsets.all(AppTheme.spacingS),
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? colorScheme.surfaceContainerHighest
                                      : colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_rounded,
                                  color: isRead
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onPrimaryContainer,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                notification['title'] ?? '',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: AppTheme.spacingXS),
                                  Text(
                                    notification['message'] ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (notification['createdAt'] != null) ...[
                                    SizedBox(height: AppTheme.spacingS),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        SizedBox(width: AppTheme.spacingXS),
                                        Text(
                                          DateFormat('MMM dd, yyyy HH:mm').format(
                                            DateTime.parse(notification['createdAt']),
                                          ),
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isRead
                                  ? null
                                  : IconButton(
                                      icon: Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: colorScheme.primary,
                                      ),
                                      onPressed: () => _markAsRead(notification['_id']),
                                      tooltip: 'Mark as read',
                                    ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppTheme.bradiusL,
                              ),
                            ),
                          ),
                        ),
                      );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _DrawerLeadingButton extends StatelessWidget {
  const _DrawerLeadingButton({this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    debugPrint('[NotificationsScreen] Building drawer leading button');
    debugPrint('[NotificationsScreen] onMenuPressed is null: ${onMenuPressed == null}');
    
    final controllerFromScope = DrawerControllerScope.maybeOf(context);
    debugPrint('[NotificationsScreen] Controller from scope: ${controllerFromScope != null}');
    
    AdvancedDrawerController? controllerFromWatch;
    try {
      controllerFromWatch = context.watch<AdvancedDrawerController?>();
      debugPrint('[NotificationsScreen] Controller from watch: ${controllerFromWatch != null}');
    } catch (e) {
      debugPrint('[NotificationsScreen] Error watching AdvancedDrawerController: $e');
    }
    
    final controller = controllerFromScope ?? controllerFromWatch;
    debugPrint('[NotificationsScreen] Final controller: ${controller != null}');

    if (controller == null) {
      debugPrint('[NotificationsScreen] No controller found, using fallback IconButton');
      return IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () {
          debugPrint('[NotificationsScreen] Fallback menu button pressed');
          if (onMenuPressed != null) {
            debugPrint('[NotificationsScreen] Calling onMenuPressed callback');
            onMenuPressed!();
          } else {
            debugPrint('[NotificationsScreen] WARNING: onMenuPressed is null, menu button will not work!');
          }
        },
      );
    }

    debugPrint('[NotificationsScreen] Using ValueListenableBuilder with controller');
    return ValueListenableBuilder<AdvancedDrawerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        debugPrint('[NotificationsScreen] Drawer visible: ${value.visible}');
        return IconButton(
          onPressed: () {
            debugPrint('[NotificationsScreen] Menu button pressed, drawer visible: ${value.visible}');
            if (value.visible) {
              debugPrint('[NotificationsScreen] Hiding drawer');
              controller.hideDrawer();
              return;
            }
            if (onMenuPressed != null) {
              debugPrint('[NotificationsScreen] Calling onMenuPressed before showing drawer');
              onMenuPressed!();
              return;
            }
            debugPrint('[NotificationsScreen] Showing drawer directly');
            controller.showDrawer();
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              value.visible ? Icons.clear : Icons.menu_rounded,
              key: ValueKey<bool>(value.visible),
            ),
          ),
        );
      },
    );
  }
}

