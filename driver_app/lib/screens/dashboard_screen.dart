import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trips_provider.dart';
import '../modules/vehicle/providers/vehicle_provider.dart';
import '../providers/notifications_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation/drawer_menu_button.dart';
import '../modules/trips/screens/active_trip_screen.dart';
import '../modules/trips/screens/upcoming_trips_screen.dart';
import '../modules/vehicle/screens/vehicle_info_screen.dart';
import '../modules/vehicle/screens/maintenance_reminders_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripsProvider>(context, listen: false).loadTrips();
      Provider.of<TripsProvider>(context, listen: false).loadUpcomingTrips();
      Provider.of<VehicleProvider>(context, listen: false).loadAssignedVehicle();
      Provider.of<NotificationsProvider>(context, listen: false).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: DrawerMenuButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Dashboard'),
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, notificationsProvider, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (notificationsProvider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          notificationsProvider.unreadCount > 9
                              ? '9+'
                              : notificationsProvider.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<TripsProvider>(context, listen: false).loadTrips();
          await Provider.of<TripsProvider>(context, listen: false).loadUpcomingTrips();
          await Provider.of<VehicleProvider>(context, listen: false).loadAssignedVehicle();
          await Provider.of<NotificationsProvider>(context, listen: false).loadNotifications();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          children: [
            Consumer<VehicleProvider>(
              builder: (context, vehicleProvider, _) {
                if (vehicleProvider.assignedVehicle != null) {
                  return _buildVehicleCard(context, vehicleProvider);
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            Consumer<TripsProvider>(
              builder: (context, tripsProvider, _) {
                final activeTrip = tripsProvider.activeTrip;
                // Only show if trip exists and status is in_progress
                if (activeTrip != null && 
                    (activeTrip['status'] == 'in_progress' || activeTrip['status'] == 'IN_PROGRESS')) {
                  return _buildActiveTripCard(context, tripsProvider);
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            Consumer<TripsProvider>(
              builder: (context, tripsProvider, _) {
                if (tripsProvider.upcomingTrips.isNotEmpty) {
                  return _buildUpcomingTripsCard(context, tripsProvider);
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            Consumer<VehicleProvider>(
              builder: (context, vehicleProvider, _) {
                if (vehicleProvider.maintenanceReminders.isNotEmpty) {
                  final dueReminders = vehicleProvider.maintenanceReminders
                      .where((r) {
                        final nextDate = r['nextReminderDate'] != null
                            ? DateTime.parse(r['nextReminderDate'])
                            : null;
                        return nextDate != null && nextDate.isBefore(DateTime.now());
                      })
                      .toList();
                  if (dueReminders.isNotEmpty) {
                    return _buildMaintenanceAlert(context, dueReminders.length);
                  }
                }
                return const SizedBox.shrink();
              },
                  ),
                ],
        ),
              ),
            );
          }

  Widget _buildVehicleCard(BuildContext context, VehicleProvider vehicleProvider) {
    final vehicle = vehicleProvider.assignedVehicle!;
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VehicleInfoScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: AppTheme.bradiusM,
                ),
                child: const Icon(Icons.directions_car, color: AppTheme.primaryColor, size: 32),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      '${vehicle['make']} ${vehicle['model']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      vehicle['plateNumber'] ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (vehicleProvider.distanceInfo != null &&
                        vehicleProvider.distanceInfo!['totalDistance'] != null)
                      Text(
                        '${vehicleProvider.distanceInfo!['totalDistance'].toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                      ),
                ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
              ),
            );
          }

  Widget _buildActiveTripCard(BuildContext context, TripsProvider tripsProvider) {
    final trip = tripsProvider.activeTrip!;
                return Card(
      color: AppTheme.successColor.withOpacity(0.1),
      child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveTripScreen(tripId: trip['_id']),
                        ),
                      );
                    },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  borderRadius: AppTheme.bradiusM,
                ),
                child: const Icon(Icons.directions_car, color: AppTheme.successColor, size: 32),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Trip',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      trip['endLocation']?['address'] ?? 'Unknown destination',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingTripsCard(BuildContext context, TripsProvider tripsProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Trips',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UpcomingTripsScreen(),
                  ),
                );
              },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            ...tripsProvider.upcomingTrips.take(3).map((trip) {
              final request = trip['requestId'];
              return ListTile(
                leading: const Icon(Icons.schedule, color: AppTheme.primaryColor),
                title: Text(request?['destination'] ?? 'Unknown'),
                subtitle: request?['startDate'] != null
                    ? Text(
                        DateFormat('MMM dd, yyyy HH:mm')
                            .format(DateTime.parse(request['startDate'])),
                      )
                    : null,
                dense: true,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceAlert(BuildContext context, int count) {
    return Card(
      color: AppTheme.warningColor.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MaintenanceRemindersScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Row(
            children: [
              Icon(Icons.warning, color: AppTheme.warningColor),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  '$count maintenance reminder${count > 1 ? 's' : ''} due',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

