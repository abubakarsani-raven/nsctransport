import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../modules/vehicle/providers/vehicle_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/navigation/drawer_menu_button.dart';
import '../../faults/screens/report_fault_screen.dart';
import 'maintenance_reminders_screen.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<VehicleProvider>(context, listen: false).loadAssignedVehicle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: DrawerMenuButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Vehicle Info'),
      ),
      body: Consumer<VehicleProvider>(
        builder: (context, vehicleProvider, _) {
          if (vehicleProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vehicleProvider.assignedVehicle == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined, size: 64, color: AppTheme.neutral40),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'No vehicle assigned',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          final vehicle = vehicleProvider.assignedVehicle!;
          final distanceInfo = vehicleProvider.distanceInfo;

          return RefreshIndicator(
            onRefresh: () => vehicleProvider.loadAssignedVehicle(),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle['make']} ${vehicle['model']}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text('Plate: ${vehicle['plateNumber']}'),
                        Text('Year: ${vehicle['year']}'),
                        Text('Capacity: ${vehicle['capacity']}'),
                        if (distanceInfo != null && distanceInfo['totalDistance'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppTheme.spacingM),
                            child: Text(
                              'Total Distance: ${distanceInfo['totalDistance'].toStringAsFixed(2)} km',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportFaultScreen(vehicleId: vehicle['_id']),
                            ),
                          );
                        },
                        icon: const Icon(Icons.report_problem),
                        label: const Text('Report Fault'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MaintenanceRemindersScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.build),
                        label: const Text('Maintenance'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

