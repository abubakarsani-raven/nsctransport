import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../modules/vehicle/providers/vehicle_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/navigation/drawer_menu_button.dart';

class MaintenanceRemindersScreen extends StatefulWidget {
  const MaintenanceRemindersScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<MaintenanceRemindersScreen> createState() => _MaintenanceRemindersScreenState();
}

class _MaintenanceRemindersScreenState extends State<MaintenanceRemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      if (vehicleProvider.assignedVehicle != null) {
        vehicleProvider.loadMaintenanceReminders(vehicleProvider.assignedVehicle!['_id']);
      } else {
        vehicleProvider.loadAssignedVehicle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: DrawerMenuButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Maintenance Reminders'),
      ),
      body: Consumer<VehicleProvider>(
        builder: (context, vehicleProvider, _) {
          if (vehicleProvider.isLoading && vehicleProvider.assignedVehicle == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!vehicleProvider.isLoading && vehicleProvider.assignedVehicle == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_filled_outlined, size: 64, color: AppTheme.neutral40),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'No assigned vehicle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'You do not currently have a vehicle assignment, so there are no maintenance reminders.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.neutral60,
                        ),
                  ),
                ],
              ),
            );
          }

          if (vehicleProvider.maintenanceReminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_outlined, size: 64, color: AppTheme.neutral40),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'No maintenance reminders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () {
              final vehicleId = vehicleProvider.assignedVehicle!['_id'];
              return vehicleProvider.loadMaintenanceReminders(vehicleId);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: vehicleProvider.maintenanceReminders.length,
              itemBuilder: (context, index) {
                final reminder = vehicleProvider.maintenanceReminders[index];
                final nextDate = reminder['nextReminderDate'] != null
                    ? DateTime.parse(reminder['nextReminderDate'])
                    : null;
                final isDue = nextDate != null && nextDate.isBefore(DateTime.now());

                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  color: isDue ? AppTheme.warningColor.withOpacity(0.1) : null,
                  child: ListTile(
                    leading: Icon(
                      Icons.build,
                      color: isDue ? AppTheme.warningColor : AppTheme.primaryColor,
                    ),
                    title: Text(reminder['maintenanceType'] ?? 'Maintenance'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nextDate != null)
                          Text(
                            'Due: ${DateFormat('MMM dd, yyyy').format(nextDate)}',
                            style: TextStyle(
                              color: isDue ? AppTheme.warningColor : null,
                              fontWeight: isDue ? FontWeight.bold : null,
                            ),
                          ),
                        if (reminder['notes'] != null) Text(reminder['notes']),
                      ],
                    ),
                    trailing: isDue
                        ? Chip(
                            label: const Text('Due'),
                            backgroundColor: AppTheme.warningColor.withOpacity(0.2),
                            labelStyle: const TextStyle(color: AppTheme.warningColor),
                          )
                        : null,
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

