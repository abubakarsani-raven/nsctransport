import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/requests_provider.dart';
import '../providers/transport_officer_provider.dart';
import '../theme/app_theme.dart';
import '../utils/request_workflow.dart';
import '../utils/toast_helper.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/navigation/drawer_controller_scope.dart';
import 'request_details_screen.dart';

const List<MapEntry<String, String>> _maintenanceTypeOptions = [
  MapEntry('oil_change', 'Oil Change'),
  MapEntry('tire_change', 'Tire Change'),
  MapEntry('brake_lights', 'Brake Lights'),
  MapEntry('head_lights', 'Head Lights'),
  MapEntry('brake_pads', 'Brake Pads'),
  MapEntry('gear_oil_check', 'Gear Oil Check'),
  MapEntry('engine_filter', 'Engine Filter'),
  MapEntry('air_filter', 'Air Filter'),
  MapEntry('battery_replacement', 'Battery Replacement'),
  MapEntry('fluid_check', 'Fluid Check'),
  MapEntry('general_inspection', 'General Inspection'),
  MapEntry('other', 'Other'),
];

String _maintenanceTypeLabel(String value) {
  return _maintenanceTypeOptions.firstWhere(
    (entry) => entry.key == value,
    orElse: () => MapEntry(value, value.replaceAll('_', ' ').toUpperCase()),
  ).value;
}

class TransportOfficerScreen extends StatefulWidget {
  const TransportOfficerScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<TransportOfficerScreen> createState() => _TransportOfficerScreenState();
}

class _TransportOfficerScreenState extends State<TransportOfficerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _hasBootstrapped = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final requestsProvider = context.read<RequestsProvider>();
    final transportProvider = context.read<TransportOfficerProvider>();

    try {
      await Future.wait([
        requestsProvider.loadRequests(),
        transportProvider.loadAssets(),
        transportProvider.loadFleet(),
        transportProvider.loadOffices(),
      ]);
    } catch (e) {
      debugPrint('[TransportOfficerScreen] Bootstrap error: $e');
      if (mounted) {
        ToastHelper.showErrorToast('Failed to load transport officer data. Please refresh.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _hasBootstrapped = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RequestsProvider, TransportOfficerProvider>(
      builder: (context, requestsProvider, transportProvider, _) {
        final isLoading = !_hasBootstrapped ||
            requestsProvider.isLoading ||
            transportProvider.isLoadingAssets ||
            transportProvider.isFleetLoading ||
            transportProvider.isOfficesLoading;

        return Scaffold(
          appBar: AppBar(
            leading: DrawerMenuLeadingButton(fallbackOnPressed: widget.onMenuPressed),
            title: const Text('Transport Officer Hub'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  text: 'Assignments',
                  icon: Icon(Icons.assignment_ind_rounded),
                ),
                Tab(
                  text: 'Fleet Status',
                  icon: Icon(Icons.directions_car_rounded),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () async {
                  await _refreshAll();
                  if (!mounted) return;
                  ToastHelper.showInfoToast('Transport officer data refreshed');
                },
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _AssignmentsTab(
                      onRefresh: _refreshAssignments,
                      onAssign: _openAssignmentSheet,
                      onView: _openRequestDetails,
                    ),
                    _FleetOverviewTab(onRefresh: _refreshFleet),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _refreshAll() async {
    final requestsProvider = context.read<RequestsProvider>();
    final transportProvider = context.read<TransportOfficerProvider>();
    await Future.wait([
      requestsProvider.loadRequests(),
      transportProvider.refreshAll(),
    ]);
  }

  Future<void> _refreshAssignments() async {
    final requestsProvider = context.read<RequestsProvider>();
    final transportProvider = context.read<TransportOfficerProvider>();
    await Future.wait([
      requestsProvider.loadRequests(),
      transportProvider.loadAssets(silent: true),
    ]);
  }

  Future<void> _refreshFleet() async {
    final transportProvider = context.read<TransportOfficerProvider>();
    await transportProvider.refreshAll();
  }

  Future<void> _openAssignmentSheet(Map<String, dynamic> request) async {
    final transportProvider = context.read<TransportOfficerProvider>();
    final requestsProvider = context.read<RequestsProvider>();

    await Future.wait([
      transportProvider.loadAssets(silent: true),
      if (transportProvider.offices.isEmpty) transportProvider.loadOffices(silent: true),
    ]);

    final drivers = transportProvider.availableDrivers;
    final vehicles = transportProvider.availableVehicles;
    final offices = transportProvider.offices;

    if (drivers.isEmpty) {
      ToastHelper.showErrorToast('No drivers are currently available.');
      return;
    }

    if (vehicles.isEmpty) {
      ToastHelper.showErrorToast('No vehicles are currently available.');
      return;
    }

    if (offices.isEmpty) {
      ToastHelper.showErrorToast('No offices found. Please contact an administrator.');
      return;
    }

    String? selectedDriverId = _extractId(drivers.first);
    String? selectedVehicleId = _extractId(vehicles.first);
    final String? existingPickupId =
        _extractId(request['pickupOffice']) ?? _extractId(request['originOffice']);
    String? selectedPickupOfficeId = existingPickupId ?? _extractId(offices.first);
    bool isSubmitting = false;

    final bool? assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacingL,
                right: AppTheme.spacingL,
                top: AppTheme.spacingL,
                bottom: bottomInset + AppTheme.spacingL,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assign Driver & Vehicle',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    DropdownButtonFormField<String>(
                      value: selectedDriverId,
                      decoration: const InputDecoration(
                        labelText: 'Driver',
                        border: OutlineInputBorder(),
                      ),
                      items: drivers.map<DropdownMenuItem<String>>((driver) {
                        final id = _extractId(driver);
                        final name = (driver is Map && driver['name'] != null)
                            ? driver['name'].toString()
                            : 'Unknown Driver';
                        final phone = (driver is Map && driver['phone'] != null)
                            ? ' (${driver['phone']})'
                            : '';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text('$name$phone'),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              setModalState(() {
                                selectedDriverId = value;
                              });
                            },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    DropdownButtonFormField<String>(
                      value: selectedVehicleId,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle',
                        border: OutlineInputBorder(),
                      ),
                      items: vehicles.map<DropdownMenuItem<String>>((vehicle) {
                        final id = _extractId(vehicle);
                        String label = 'Vehicle';
                        if (vehicle is Map) {
                          final plate = vehicle['plateNumber']?.toString() ?? '';
                          final make = vehicle['make']?.toString() ?? '';
                          final model = vehicle['model']?.toString() ?? '';
                          final capacity = vehicle['capacity']?.toString() ?? '';
                          label = [
                            if (plate.isNotEmpty) plate,
                            if (make.isNotEmpty || model.isNotEmpty) '$make $model'.trim(),
                            if (capacity.isNotEmpty) 'Capacity: $capacity',
                          ].where((part) => part.isNotEmpty).join(' • ');
                        }
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              setModalState(() {
                                selectedVehicleId = value;
                              });
                            },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    DropdownButtonFormField<String>(
                      value: selectedPickupOfficeId,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Office',
                        border: OutlineInputBorder(),
                      ),
                      items: offices.map<DropdownMenuItem<String>>((office) {
                        final id = _extractId(office);
                        String label = 'Office';
                        if (office is Map) {
                          final name = office['name']?.toString();
                          final address = office['address']?.toString();
                          if (name != null && address != null) {
                            label = '$name • $address';
                          } else if (name != null) {
                            label = name;
                          }
                        }
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              setModalState(() {
                                selectedPickupOfficeId = value;
                              });
                            },
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    FilledButton.icon(
                      onPressed: isSubmitting ||
                              selectedDriverId == null ||
                              selectedVehicleId == null ||
                              selectedPickupOfficeId == null
                          ? null
                          : () async {
                              setModalState(() {
                                isSubmitting = true;
                              });

                              final success = await requestsProvider.assignDriverAndVehicle(
                                requestId: _extractId(request) ?? '',
                                driverId: selectedDriverId!,
                                vehicleId: selectedVehicleId!,
                                pickupOfficeId: selectedPickupOfficeId!,
                              );

                              if (!context.mounted) return;

                              if (success) {
                                Navigator.of(context).pop(true);
                              } else {
                                setModalState(() {
                                  isSubmitting = false;
                                });
                                ToastHelper.showErrorToast(
                                  'Failed to assign driver and vehicle. Please try again.',
                                );
                              }
                            },
                      icon: isSubmitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            )
                          : const Icon(Icons.assignment_turned_in_rounded),
                      label: Text(isSubmitting ? 'Assigning...' : 'Assign Driver & Vehicle'),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (assigned == true) {
      ToastHelper.showSuccessToast('Driver and vehicle assigned successfully.');
      await Future.wait([
        requestsProvider.loadRequests(),
        transportProvider.refreshAll(),
      ]);
    }
  }

  Future<void> _openRequestDetails(Map<String, dynamic> request) async {
    final requestId = _extractId(request);
    if (requestId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailsScreen(
          requestId: requestId,
          canApprove: true,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshAssignments();
  }

}

enum FleetMetric {
  totalVehicles,
  availableVehicles,
  permanentAssignments,
  totalDrivers,
  availableDrivers,
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({
    required this.onRefresh,
    required this.onAssign,
    required this.onView,
  });

  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic> request) onAssign;
  final void Function(Map<String, dynamic> request) onView;

  List<Map<String, dynamic>> _pendingAssignments(List<dynamic> allRequests) {
    return allRequests.whereType<Map<String, dynamic>>().where((request) {
      final stage = RequestWorkflow.getCurrentStage(request);
      final status = (request['status'] ?? '').toString().toLowerCase();
      if (stage == 'transport_officer_assignment') return true;
      return status == 'ad_transport_approved';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RequestsProvider>(
      builder: (context, requestsProvider, _) {
        final assignments = _pendingAssignments(requestsProvider.requests);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        if (assignments.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            color: AppTheme.primaryColor,
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.beach_access_rounded,
                        size: 64,
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      Text(
                        'No pending assignments',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Requests that need driver or vehicle assignments will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingM,
            ),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final request = assignments[index];
              return _AssignmentCard(
                request: request,
                onAssign: () => onAssign(request),
                onView: () => onView(request),
              );
            },
          ),
        );
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.request,
    required this.onAssign,
    required this.onView,
  });

  final Map<String, dynamic> request;
  final VoidCallback onAssign;
  final VoidCallback onView;

  String _formatDate(dynamic value) {
    if (value == null) return 'Unknown date';
    try {
      final date = value is DateTime ? value : DateTime.parse(value.toString());
      return DateFormat('MMM dd, yyyy • HH:mm').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = (request['destination'] ?? 'Unknown destination').toString();
    final purpose = (request['purpose'] ?? '').toString();
    final passengerCount = request['passengerCount'] ?? '?';
    final startDate = _formatDate(request['startDate']);
    final status = (request['status'] ?? '').toString();
    final statusColor = AppTheme.getStatusColor(status);
    final assignedDriver = request['assignedDriverId'];
    final assignedVehicle = request['assignedVehicleId'];
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    destination,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    RequestWorkflow.formatStatus(status),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            if (purpose.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                purpose,
                style: theme.textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
            ],
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingL,
              runSpacing: AppTheme.spacingS,
              children: [
                _InfoChip(
                  icon: Icons.event_available_rounded,
                  label: 'Start: $startDate',
                ),
                _InfoChip(
                  icon: Icons.people_alt_rounded,
                  label: 'Passengers: $passengerCount',
                ),
                if (assignedDriver != null)
                  _InfoChip(
                    icon: Icons.person_rounded,
                    label: 'Driver: ${_resolveName(assignedDriver)}',
                  ),
                if (assignedVehicle != null)
                  _InfoChip(
                    icon: Icons.directions_car_rounded,
                    label: 'Vehicle: ${_resolveVehicleLabel(assignedVehicle)}',
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingL),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppTheme.spacingS,
                runSpacing: AppTheme.spacingS,
                children: [
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.remove_red_eye_rounded),
                    label: const Text('View Details'),
                  ),
                  FilledButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.assignment_turned_in_rounded),
                    label: Text(assignedDriver == null ? 'Assign Now' : 'Reassign'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveName(dynamic value) {
    if (value is Map && value['name'] != null) {
      return value['name'].toString();
    }
    return 'Assigned';
  }

  String _resolveVehicleLabel(dynamic value) {
    if (value is Map) {
      final plate = value['plateNumber']?.toString() ?? '';
      final make = value['make']?.toString() ?? '';
      final model = value['model']?.toString() ?? '';
      return [plate, '$make $model'.trim()].where((part) => part.trim().isNotEmpty).join(' • ');
    }
    return 'Vehicle Assigned';
  }
}

class _FleetOverviewTab extends StatefulWidget {
  const _FleetOverviewTab({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<_FleetOverviewTab> createState() => _FleetOverviewTabState();
}

class _FleetOverviewTabState extends State<_FleetOverviewTab> {
  String? _selectedVehicleId;
  bool _loadingMaintenance = false;
  late final PageController _pageController;
  Set<int> _selectedSegment = const {0};

  void _ensureInitialSelection(TransportOfficerProvider provider) {
    if (_selectedVehicleId != null) return;
    final vehicles = provider.filteredFleetVehicles;
    if (vehicles.isEmpty) return;
    final firstId = _extractId(vehicles.first);
    if (firstId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedVehicleId != null) return;
      _selectVehicle(firstId, provider, silent: true);
    });
  }

  Future<void> _selectVehicle(
    String vehicleId,
    TransportOfficerProvider provider, {
    bool silent = false,
  }) async {
    setState(() {
      _selectedVehicleId = vehicleId;
      if (!silent) {
        _loadingMaintenance = true;
      }
    });

    try {
      await provider.loadMaintenance(vehicleId);
    } catch (e) {
      if (!silent) {
        ToastHelper.showErrorToast('Failed to load maintenance: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          if (!silent) {
            _loadingMaintenance = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransportOfficerProvider>(
      builder: (context, provider, _) {
        _ensureInitialSelection(provider);

        return LayoutBuilder(
          builder: (context, constraints) {
            final double pageHeight =
                (MediaQuery.of(context).size.height * 0.65).clamp(360.0, 640.0).toDouble();

            return RefreshIndicator(
              onRefresh: widget.onRefresh,
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FleetSummaryCard(
                      provider: provider,
                      onMetricTap: (metric) => _handleMetricTap(metric, provider),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildPagerHeader(),
                    const SizedBox(height: AppTheme.spacingS),
                    SizedBox(
                      height: pageHeight,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _selectedSegment = {index});
                        },
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                            child: _VehicleSection(
                              provider: provider,
                              vehicles: provider.filteredFleetVehicles,
                            ),
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                            child: _DriverSection(
                              provider: provider,
                              drivers: provider.filteredDrivers,
                            ),
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                            child: _buildMaintenancePanel(provider),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleMetricTap(FleetMetric metric, TransportOfficerProvider provider) {
    switch (metric) {
      case FleetMetric.totalVehicles:
        _showVehiclesBottomSheet(
          title: 'All Vehicles',
          vehicles: provider.filteredFleetVehicles,
        );
        break;
      case FleetMetric.availableVehicles:
        _showVehiclesBottomSheet(
          title: 'Available Vehicles',
          vehicles: provider.filteredFleetVehicles
              .where((vehicle) => (vehicle['status'] ?? '').toString().toLowerCase() == 'available')
              .toList(),
        );
        break;
      case FleetMetric.permanentAssignments:
        _showVehiclesBottomSheet(
          title: 'Permanent Assignments',
          vehicles: provider.filteredFleetVehicles
              .where((vehicle) => (vehicle['status'] ?? '').toString().toLowerCase() == 'permanently_assigned')
              .toList(),
        );
        break;
      case FleetMetric.totalDrivers:
        _showDriversBottomSheet(
          title: 'All Drivers',
          drivers: provider.filteredDrivers,
        );
        break;
      case FleetMetric.availableDrivers:
        _showDriversBottomSheet(
          title: 'Available Drivers',
          drivers: provider.filteredDrivers.where((driver) {
            if (driver is! Map<String, dynamic>) return false;
            final hasCurrentTrip = driver['currentTripId'] != null;
            final hasPermanentVehicle = driver['permanentVehicle'] != null;
            return !hasCurrentTrip && !hasPermanentVehicle;
          }).toList(),
        );
        break;
    }
  }

  void _showVehiclesBottomSheet({required String title, required List<dynamic> vehicles}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppTheme.spacingM,
            right: AppTheme.spacingM,
            bottom: AppTheme.spacingM + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppTheme.spacingM),
                Expanded(
                  child: vehicles.isEmpty
                      ? Center(
                          child: Text(
                            'No records found.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppPalette.of(context).textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: vehicles.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingS),
                          itemBuilder: (context, index) {
                            final vehicle = vehicles[index] as Map<String, dynamic>;
                            return _VehicleTile(vehicle: vehicle);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDriversBottomSheet({required String title, required List<dynamic> drivers}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppTheme.spacingM,
            right: AppTheme.spacingM,
            bottom: AppTheme.spacingM + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppTheme.spacingM),
                Expanded(
                  child: drivers.isEmpty
                      ? Center(
                          child: Text(
                            'No records found.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppPalette.of(context).textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: drivers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingS),
                          itemBuilder: (context, index) {
                            final driver = drivers[index] as Map<String, dynamic>;
                            return _DriverTile(driver: driver);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagerHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Vehicles'), icon: Icon(Icons.directions_car_rounded)),
        ButtonSegment(value: 1, label: Text('Drivers'), icon: Icon(Icons.people_alt_rounded)),
        ButtonSegment(value: 2, label: Text('Maintenance'), icon: Icon(Icons.build_rounded)),
      ],
      selected: _selectedSegment,
      showSelectedIcon: false,
      style: ButtonStyle(
        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: AppTheme.spacingM)),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceVariant;
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        side: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return BorderSide(color: colorScheme.primary, width: 1);
          }
          return BorderSide(color: colorScheme.outline.withOpacity(0.3), width: 1);
        }),
      ),
      onSelectionChanged: (newSelection) {
        setState(() => _selectedSegment = newSelection);
        final index = newSelection.first;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildMaintenancePanel(TransportOfficerProvider provider) {
    final vehicles = provider.filteredFleetVehicles;
    final selectedId = _selectedVehicleId;
    final records =
        selectedId == null ? const <dynamic>[] : provider.maintenanceRecordsFor(selectedId);
    final reminders =
        selectedId == null ? const <dynamic>[] : provider.maintenanceRemindersFor(selectedId);

    if (vehicles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintenance',
                style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'No vehicles available. Add vehicles before managing maintenance.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppPalette.of(context).textSecondary),
              ),
            ],
          ),
        ),
      );
    }

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
                  'Maintenance',
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_loadingMaintenance)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            DropdownButtonFormField<String>(
              value: selectedId,
              decoration: const InputDecoration(
                labelText: 'Select vehicle',
                border: OutlineInputBorder(),
              ),
              items: vehicles.map<DropdownMenuItem<String>>((vehicle) {
                final id = _extractId(vehicle);
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(_vehicleDisplayLabel(vehicle)),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null || value == _selectedVehicleId) return;
                _selectVehicle(value, provider);
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
            if (selectedId == null)
              Text(
                'Select a vehicle to view maintenance history.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppPalette.of(context).textSecondary),
              )
            else
              _MaintenanceSection(
                vehicleId: selectedId,
                records: records,
                reminders: reminders,
                onAddRecord: () async {
                  if (_selectedVehicleId == null) return;
                  await _showAddMaintenanceRecordSheet(context, _selectedVehicleId!, provider);
                },
                onAddReminder: () async {
                  if (_selectedVehicleId == null) return;
                  await _showAddMaintenanceReminderSheet(context, _selectedVehicleId!, provider);
                },
                onDeleteRecord: (recordId) async {
                  if (_selectedVehicleId == null) return;
                  setState(() => _loadingMaintenance = true);
                  try {
                    await provider.deleteMaintenanceRecord(_selectedVehicleId!, recordId);
                    ToastHelper.showSuccessToast('Maintenance record removed');
                  } catch (e) {
                    ToastHelper.showErrorToast('Failed to delete record: $e');
                  } finally {
                    if (mounted) {
                      setState(() => _loadingMaintenance = false);
                    }
                  }
                },
                onDeleteReminder: (reminderId) async {
                  if (_selectedVehicleId == null) return;
                  setState(() => _loadingMaintenance = true);
                  try {
                    await provider.deleteMaintenanceReminder(_selectedVehicleId!, reminderId);
                    ToastHelper.showSuccessToast('Reminder deleted');
                  } catch (e) {
                    ToastHelper.showErrorToast('Failed to delete reminder: $e');
                  } finally {
                    if (mounted) {
                      setState(() => _loadingMaintenance = false);
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMaintenanceRecordSheet(
    BuildContext context,
    String vehicleId,
    TransportOfficerProvider provider,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    String selectedType = _maintenanceTypeOptions.first.key;
    final customTypeController = TextEditingController();
    final descriptionController = TextEditingController();
    final performedByController = TextEditingController();
    final costController = TextEditingController();
    DateTime performedAt = DateTime.now();
    final performedAtController =
        TextEditingController(text: DateFormat('MMM dd, yyyy').format(performedAt));

    Future<void> pickDate(StateSetter setModalState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: performedAt,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        performedAt = DateTime(picked.year, picked.month, picked.day);
        setModalState(() {
          performedAtController.text = DateFormat('MMM dd, yyyy').format(performedAt);
        });
      }
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacingL,
                right: AppTheme.spacingL,
                top: AppTheme.spacingL,
                bottom: bottomInset + AppTheme.spacingL,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Maintenance Record',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Maintenance Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _maintenanceTypeOptions
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedType = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: customTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Type (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Performed At',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_rounded),
                            onPressed: () => pickDate(setModalState),
                          ),
                        ),
                        controller: performedAtController,
                        onTap: () => pickDate(setModalState),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: performedByController,
                        decoration: const InputDecoration(
                          labelText: 'Performed By (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cost (optional)',
                          prefixText: '₦ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                      FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                Navigator.of(context).pop(true);
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(isSaving ? 'Saving...' : 'Save Record'),
                      ),
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      final payload = <String, dynamic>{
        'maintenanceType': selectedType,
        'performedAt': performedAt.toIso8601String(),
      };
      if (customTypeController.text.trim().isNotEmpty) {
        payload['customTypeName'] = customTypeController.text.trim();
      }
      if (descriptionController.text.trim().isNotEmpty) {
        payload['description'] = descriptionController.text.trim();
      }
      if (performedByController.text.trim().isNotEmpty) {
        payload['performedBy'] = performedByController.text.trim();
      }
      final parsedCost = double.tryParse(costController.text.trim());
      if (parsedCost != null) {
        payload['cost'] = parsedCost;
      }

      try {
        setState(() => _loadingMaintenance = true);
        await provider.addMaintenanceRecord(vehicleId, payload);
        ToastHelper.showSuccessToast('Maintenance record added');
      } catch (e) {
        ToastHelper.showErrorToast('Failed to add record: $e');
      } finally {
        if (mounted) {
          setState(() => _loadingMaintenance = false);
        }
      }
    }

    customTypeController.dispose();
    descriptionController.dispose();
    performedByController.dispose();
    costController.dispose();
    performedAtController.dispose();
  }

  Future<void> _showAddMaintenanceReminderSheet(
    BuildContext context,
    String vehicleId,
    TransportOfficerProvider provider,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    String selectedType = _maintenanceTypeOptions.first.key;
    final customTypeController = TextEditingController();
    final notesController = TextEditingController();
    final intervalController = TextEditingController(text: '30');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacingL,
                right: AppTheme.spacingL,
                top: AppTheme.spacingL,
                bottom: bottomInset + AppTheme.spacingL,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Maintenance Reminder',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Maintenance Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _maintenanceTypeOptions
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedType = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: customTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Type (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: intervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reminder Interval (days)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                      FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSaving = true);
                                Navigator.of(context).pop(true);
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(isSaving ? 'Saving...' : 'Save Reminder'),
                      ),
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      final payload = <String, dynamic>{
        'maintenanceType': selectedType,
        'reminderIntervalDays': int.parse(intervalController.text.trim()),
      };
      if (customTypeController.text.trim().isNotEmpty) {
        payload['customTypeName'] = customTypeController.text.trim();
      }
      if (notesController.text.trim().isNotEmpty) {
        payload['notes'] = notesController.text.trim();
      }

      try {
        setState(() => _loadingMaintenance = true);
        await provider.addMaintenanceReminder(vehicleId, payload);
        ToastHelper.showSuccessToast('Maintenance reminder added');
      } catch (e) {
        ToastHelper.showErrorToast('Failed to add reminder: $e');
      } finally {
        if (mounted) {
          setState(() => _loadingMaintenance = false);
        }
      }
    }

    customTypeController.dispose();
    notesController.dispose();
    intervalController.dispose();
  }
}

class _FleetSummaryCard extends StatelessWidget {
  const _FleetSummaryCard({required this.provider, required this.onMetricTap});

  final TransportOfficerProvider provider;
  final void Function(FleetMetric metric) onMetricTap;

  @override
  Widget build(BuildContext context) {
    final lastUpdated = provider.lastUpdated;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      backgroundColor: colorScheme.surface,
      borderColor: colorScheme.outline.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fleet Overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Wrap(
            spacing: AppTheme.spacingM,
            runSpacing: AppTheme.spacingS,
            children: [
              _SummaryChip(
                icon: Icons.directions_car_filled_rounded,
                label: 'Total Vehicles',
                value: provider.totalVehicles,
                onTap: () => onMetricTap(FleetMetric.totalVehicles),
              ),
              _SummaryChip(
                icon: Icons.local_shipping_rounded,
                label: 'Available Vehicles',
                value: provider.availableVehicleCount,
                onTap: () => onMetricTap(FleetMetric.availableVehicles),
              ),
              _SummaryChip(
                icon: Icons.link_rounded,
                label: 'Permanent Assignments',
                value: provider.permanentVehicleCount,
                onTap: () => onMetricTap(FleetMetric.permanentAssignments),
              ),
              _SummaryChip(
                icon: Icons.group_rounded,
                label: 'Drivers',
                value: provider.totalDrivers,
                onTap: () => onMetricTap(FleetMetric.totalDrivers),
              ),
              _SummaryChip(
                icon: Icons.emoji_people_rounded,
                label: 'Available Drivers',
                value: provider.availableDriverCount,
                onTap: () => onMetricTap(FleetMetric.availableDrivers),
              ),
            ],
          ),
          if (lastUpdated != null) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Last updated ${DateFormat('MMM dd, yyyy • HH:mm').format(lastUpdated)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppPalette.of(context).textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _VehicleSection extends StatelessWidget {
  const _VehicleSection({
    required this.provider,
    required this.vehicles,
  });

  final TransportOfficerProvider provider;
  final List<dynamic> vehicles;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      backgroundColor: AppTheme.neutral0,
      borderColor: AppTheme.neutral20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final gridCrossAxisCount = constraints.maxWidth >= 960
              ? 3
              : constraints.maxWidth >= 640
                  ? 2
                  : 1;
          final itemAspectRatio = gridCrossAxisCount == 1 ? 1.4 : 1.6;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vehicles',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      provider.setVehicleFilter('all');
                      provider.setVehicleSearch('');
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
                  child: _FilterChips(
                    options: const [
                      ('all', 'All'),
                      ('available', 'Available'),
                      ('assigned', 'On Assignment'),
                      ('permanent', 'Permanent'),
                      ('maintenance', 'Maintenance'),
                    ],
                    selected: provider.vehicleFilter,
                    onSelected: provider.setVehicleFilter,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search by plate number, make, or model',
                ),
                onChanged: provider.setVehicleSearch,
              ),
              const SizedBox(height: AppTheme.spacingM),
              if (vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingL),
                  child: Text(
                    'No vehicles match the current filters.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.of(context).textSecondary),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vehicles.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCrossAxisCount,
                    mainAxisSpacing: AppTheme.spacingS,
                    crossAxisSpacing: AppTheme.spacingS,
                    childAspectRatio: itemAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index] as Map<String, dynamic>;
                    return _VehicleTile(vehicle: vehicle);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DriverSection extends StatelessWidget {
  const _DriverSection({
    required this.provider,
    required this.drivers,
  });

  final TransportOfficerProvider provider;
  final List<dynamic> drivers;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      backgroundColor: AppTheme.neutral0,
      borderColor: AppTheme.neutral20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final gridCrossAxisCount = constraints.maxWidth >= 960
              ? 3
              : constraints.maxWidth >= 640
                  ? 2
                  : 1;
          final itemAspectRatio = gridCrossAxisCount == 1 ? 1.4 : 1.6;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Drivers',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      provider.setDriverFilter('all');
                      provider.setDriverSearch('');
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
                  child: _FilterChips(
                    options: const [
                      ('all', 'All'),
                      ('available', 'Available'),
                      ('on_assignment', 'On Assignment'),
                      ('permanent', 'Permanent'),
                    ],
                    selected: provider.driverFilter,
                    onSelected: provider.setDriverFilter,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search by driver name, email, or ID',
                ),
                onChanged: provider.setDriverSearch,
              ),
              const SizedBox(height: AppTheme.spacingM),
              if (drivers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingL),
                  child: Text(
                    'No drivers match the current filters.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.of(context).textSecondary),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: drivers.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCrossAxisCount,
                    mainAxisSpacing: AppTheme.spacingS,
                    crossAxisSpacing: AppTheme.spacingS,
                    childAspectRatio: itemAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final driver = drivers[index] as Map<String, dynamic>;
                    return _DriverTile(driver: driver);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({
    required this.vehicleId,
    required this.records,
    required this.reminders,
    required this.onAddRecord,
    required this.onAddReminder,
    required this.onDeleteRecord,
    required this.onDeleteReminder,
  });

  final String? vehicleId;
  final List<dynamic> records;
  final List<dynamic> reminders;
  final Future<void> Function() onAddRecord;
  final Future<void> Function() onAddReminder;
  final Future<void> Function(String recordId) onDeleteRecord;
  final Future<void> Function(String reminderId) onDeleteReminder;

  @override
  Widget build(BuildContext context) {
    if (vehicleId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Text(
            'Select a vehicle to view maintenance records.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: [
                    const Text(
                      'Maintenance Records',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    FilledButton.icon(
                      onPressed: onAddRecord,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Record'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                if (records.isEmpty)
                  Text(
                    'No maintenance records yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppPalette.of(context).textSecondary),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final record = records[index] as Map<String, dynamic>;
                      final recordId = _extractId(record);
                      final type = _maintenanceTypeLabel(record['maintenanceType']?.toString() ?? 'other');
                      final performedAt = _formatDate(record['performedAt']);
                      final description = record['description']?.toString();
                      final performedBy = record['performedBy']?.toString();
                      final cost = record['cost'];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Performed: $performedAt'),
                            if (performedBy != null && performedBy.isNotEmpty)
                              Text('Performed by: $performedBy'),
                            if (description != null && description.isNotEmpty)
                              Text(description),
                            if (cost != null)
                              Text('Cost: ₦${cost.toString()}'),
                          ],
                        ),
                        trailing: recordId == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async => onDeleteRecord(recordId),
                              ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: [
                    const Text(
                      'Maintenance Reminders',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    FilledButton.icon(
                      onPressed: onAddReminder,
                      icon: const Icon(Icons.add_alert_rounded),
                      label: const Text('Add Reminder'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                if (reminders.isEmpty)
                  Text(
                    'No reminders configured.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppPalette.of(context).textSecondary),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reminders.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final reminder = reminders[index] as Map<String, dynamic>;
                      final reminderId = _extractId(reminder);
                      final type = _maintenanceTypeLabel(reminder['maintenanceType']?.toString() ?? 'other');
                      final interval = reminder['reminderIntervalDays'];
                      final nextReminder = _formatDate(reminder['nextReminderDate']);
                      final notes = reminder['notes']?.toString();
                      final active = reminder['isActive'] != false;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Interval: $interval days'),
                            Text('Next reminder: $nextReminder'),
                            Text(active ? 'Status: Active' : 'Status: Inactive'),
                            if (notes != null && notes.isNotEmpty) Text('Notes: $notes'),
                          ],
                        ),
                        trailing: reminderId == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async => onDeleteReminder(reminderId),
                              ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, String)> options;
  final String selected;
  final void Function(String value) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Wrap(
      spacing: AppTheme.spacingS,
      runSpacing: AppTheme.spacingS,
      children: options.map((entry) {
        final value = entry.$1;
        final label = entry.$2;
        final isSelected = value == selected;
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          selectedColor: colorScheme.primaryContainer,
          backgroundColor: colorScheme.surfaceVariant,
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            color: isSelected 
              ? colorScheme.onPrimaryContainer 
              : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected 
              ? colorScheme.primary 
              : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        );
      }).toList(),
    );
  }
}

class DrawerMenuLeadingButton extends StatelessWidget {
  const DrawerMenuLeadingButton({super.key, this.fallbackOnPressed});

  final VoidCallback? fallbackOnPressed;

  @override
  Widget build(BuildContext context) {
    final controller =
        DrawerControllerScope.maybeOf(context) ?? context.watch<AdvancedDrawerController?>();

    if (controller == null) {
      return IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: fallbackOnPressed,
      );
    }

    return ValueListenableBuilder<AdvancedDrawerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return IconButton(
          onPressed: () {
            if (value.visible) {
              controller.hideDrawer();
              return;
            }
            if (fallbackOnPressed != null) {
              fallbackOnPressed!();
              return;
            }
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      backgroundColor: primaryColor.withOpacity(0.08),
      borderColor: primaryColor.withOpacity(0.16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            '$label: $value',
            style: theme
                .textTheme
                .labelMedium
                ?.copyWith(color: primaryColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = Color.lerp(
          colorScheme.surfaceVariant,
          colorScheme.surface,
          theme.brightness == Brightness.dark ? 0.1 : 0.4,
        ) ??
        colorScheme.surfaceVariant;

    return Chip(
      avatar: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
      ),
      side: BorderSide.none,
      backgroundColor: background,
    );
  }
}

String _vehicleDisplayLabel(dynamic vehicle) {
  if (vehicle is Map<String, dynamic>) {
    final plate = vehicle['plateNumber']?.toString() ?? '';
    final make = vehicle['make']?.toString() ?? '';
    final model = vehicle['model']?.toString() ?? '';
    return [plate, '$make $model'.trim()].where((part) => part.trim().isNotEmpty).join(' • ');
  }
  return vehicle.toString();
}

String _formatDate(dynamic value) {
  if (value == null) return '—';
  try {
    final date = value is DateTime ? value : DateTime.parse(value.toString());
    return DateFormat('MMM dd, yyyy').format(date.toLocal());
  } catch (_) {
    return value.toString();
  }
}

String? _extractId(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Map) {
    final id = value['_id'] ?? value['id'];
    return id?.toString();
  }
  return value.toString();
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plateNumber = vehicle['plateNumber']?.toString() ?? 'Unknown';
    final make = vehicle['make']?.toString() ?? '';
    final model = vehicle['model']?.toString() ?? '';
    final status = (vehicle['status'] ?? '').toString();
    final statusColor = AppTheme.getStatusColor(status);
    final capacity = vehicle['capacity']?.toString() ?? '-';
    final currentDriver = vehicle['currentDriver'];
    final isPermanent = status.toLowerCase() == 'permanently_assigned';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral0,
        border: Border.all(color: AppTheme.neutral20),
        borderRadius: AppTheme.bradiusM,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plateNumber,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusPill(text: RequestWorkflow.formatStatus(status), color: statusColor),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          if (make.isNotEmpty || model.isNotEmpty)
            Text(
              '$make $model'.trim(),
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppTheme.spacingS),
          _MetaRow(
            icon: Icons.people_alt_rounded,
            label: 'Capacity',
            value: capacity,
          ),
          if (currentDriver != null)
            _MetaRow(
              icon: Icons.person_rounded,
              label: isPermanent ? 'Permanent driver' : 'Current driver',
              value: _resolveName(currentDriver),
              valueColor: isPermanent ? Colors.orange[800] : AppTheme.warningColor,
            ),
        ],
      ),
    );
  }

  String _resolveName(dynamic value) {
    if (value is Map && value['name'] != null) {
      return value['name'].toString();
    }
    return 'Unknown';
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({required this.driver});

  final Map<String, dynamic> driver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = driver['name']?.toString() ?? 'Unknown Driver';
    final email = driver['email']?.toString() ?? '';
    final phone = driver['phone']?.toString() ?? '';
    final employeeId = driver['employeeId']?.toString() ?? '';
    final currentVehicle = driver['currentVehicle'];
    final permanentVehicle = driver['permanentVehicle'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral0,
        border: Border.all(color: AppTheme.neutral20),
        borderRadius: AppTheme.bradiusM,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.secondaryColor.withOpacity(0.12),
                foregroundColor: AppTheme.secondaryColor,
                child: const Icon(Icons.person_rounded, size: 18),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          if (email.isNotEmpty)
            Text(email, style: theme.textTheme.bodyMedium),
          if (phone.isNotEmpty)
            Text('Phone: $phone', style: theme.textTheme.bodySmall),
          if (employeeId.isNotEmpty)
            Text('Employee ID: $employeeId', style: theme.textTheme.bodySmall),
          if (currentVehicle != null) ...[
            const SizedBox(height: AppTheme.spacingXS),
            _MetaRow(
              icon: Icons.directions_car_rounded,
              label: 'On assignment',
              value: _vehicleLabel(currentVehicle),
              valueColor: AppTheme.warningColor,
            ),
          ],
          if (permanentVehicle != null) ...[
            const SizedBox(height: AppTheme.spacingXS),
            _MetaRow(
              icon: Icons.link_rounded,
              label: 'Permanent vehicle',
              value: _vehicleLabel(permanentVehicle),
              valueColor: Colors.orange[800],
            ),
          ],
        ],
      ),
    );
  }

  String _vehicleLabel(dynamic vehicle) {
    if (vehicle is Map<String, dynamic>) {
      final plate = vehicle['plateNumber']?.toString() ?? '';
      final make = vehicle['make']?.toString() ?? '';
      final model = vehicle['model']?.toString() ?? '';
      return [plate, '$make $model'.trim()].where((part) => part.trim().isNotEmpty).join(' • ');
    }
    return 'Vehicle';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppTheme.bradiusS,
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: AppPalette.of(context).textSecondary),
        const SizedBox(width: AppTheme.spacingXS),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppPalette.of(context).textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

