import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../modules/faults/providers/faults_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/navigation/drawer_menu_button.dart';
import 'report_fault_screen.dart';
import '../../../modules/vehicle/providers/vehicle_provider.dart';

class FaultHistoryScreen extends StatefulWidget {
  const FaultHistoryScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<FaultHistoryScreen> createState() => _FaultHistoryScreenState();
}

class _FaultHistoryScreenState extends State<FaultHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FaultsProvider>(context, listen: false).loadMyFaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: DrawerMenuButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Fault Reports'),
        actions: [
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, _) {
              if (vehicleProvider.assignedVehicle == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportFaultScreen(
                        vehicleId: vehicleProvider.assignedVehicle!['_id'],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<FaultsProvider>(
        builder: (context, faultsProvider, _) {
          if (faultsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (faultsProvider.myFaults.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => faultsProvider.loadMyFaults(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_problem_outlined, size: 64, color: AppTheme.neutral40),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          'No fault reports',
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
            onRefresh: () => faultsProvider.loadMyFaults(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: faultsProvider.myFaults.length,
              itemBuilder: (context, index) {
                final fault = faultsProvider.myFaults[index];
                final status = fault['status'] ?? 'reported';
                final statusColor = _getStatusColor(status);

                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: ListTile(
                    leading: Icon(Icons.report_problem, color: statusColor),
                    title: Text(fault['category'] ?? 'Fault'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fault['description'] ?? ''),
                        if (fault['createdAt'] != null)
                          Text(
                            DateFormat('MMM dd, yyyy').format(DateTime.parse(fault['createdAt'])),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(status.toUpperCase()),
                      backgroundColor: statusColor.withOpacity(0.2),
                      labelStyle: TextStyle(color: statusColor, fontSize: 10),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reported':
        return AppTheme.warningColor;
      case 'in_progress':
        return AppTheme.infoColor;
      case 'resolved':
      case 'closed':
        return AppTheme.successColor;
      default:
        return AppTheme.neutral60;
    }
  }
}

