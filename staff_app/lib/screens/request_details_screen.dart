import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/requests_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_helper.dart';
import '../widgets/timeline_widget.dart';
import '../utils/request_workflow.dart';
import '../widgets/ui/app_card.dart';
import 'create_request_screen.dart';

class RequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final bool canApprove;

  const RequestDetailsScreen({super.key, required this.requestId, this.canApprove = false});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  Map<String, dynamic>? _request;
  bool _isLoading = true;
  bool _isAssigning = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadRequest();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    try {
      final request = await _apiService.getRequest(widget.requestId);
      if (mounted) {
        debugPrint('[RequestDetails] Loaded request status: ${request['status']}');
        debugPrint('[RequestDetails] Loaded request correctionNote: ${request['correctionNote']}');
        debugPrint('[RequestDetails] Loaded request approvalChain: ${request['approvalChain']}');
        setState(() {
          _request = request;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load request: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ToastHelper.showErrorToast(message);
  }

  void _showSuccessSnackBar(String message) {
    ToastHelper.showSuccessToast(message);
  }

  Future<void> _openAssignmentSheet() async {
    debugPrint('[RequestDetails] _openAssignmentSheet called');
    debugPrint('[RequestDetails] _request is null: ${_request == null}');
    debugPrint('[RequestDetails] mounted: $mounted');
    
    if (_request == null || !mounted) {
      debugPrint('[RequestDetails] Early return: _request=${_request == null}, mounted=$mounted');
      return;
    }

    final requestsProvider = Provider.of<RequestsProvider>(context, listen: false);
    debugPrint('[RequestDetails] Setting _isAssigning to true');

    setState(() {
      _isAssigning = true;
    });

    // Show loading dialog while fetching assignment data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    List<dynamic> drivers = [];
    List<dynamic> vehicles = [];
    List<dynamic> offices = [];

    try {

      final results = await Future.wait<List<dynamic>>([
        requestsProvider.getAvailableDriversForRequest(widget.requestId),
        requestsProvider.getAvailableVehiclesForRequest(widget.requestId),
        _apiService.getOffices(),
      ]);

      if (!mounted) {
        return;
      }

      drivers = List<dynamic>.from(results[0]);
      vehicles = List<dynamic>.from(results[1]);
      offices = List<dynamic>.from(results[2]);
      
      debugPrint('[RequestDetails] Assignment data loaded:');
      debugPrint('[RequestDetails]   Drivers: ${drivers.length}');
      debugPrint('[RequestDetails]   Vehicles: ${vehicles.length}');
      debugPrint('[RequestDetails]   Offices: ${offices.length}');
    } catch (e) {
      debugPrint('[RequestDetails] Error loading assignment data: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load assignment data: $e');
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isAssigning = false;
        });
      }
    }

    if (!mounted) {
      debugPrint('[RequestDetails] Widget not mounted, returning');
      return;
    }

    if (offices.isEmpty) {
      debugPrint('[RequestDetails] No offices available - blocking assignment sheet');
      _showErrorSnackBar('No pickup offices found. Please contact the administrator.');
      return;
    }
    
    debugPrint('[RequestDetails] Showing assignment sheet');
    debugPrint('[RequestDetails] Drivers available: ${drivers.length}, Vehicles available: ${vehicles.length}');

    // Allow sheet to show even if drivers/vehicles are empty, but disable selection
    String? selectedDriverId = drivers.isNotEmpty ? _extractId(drivers.first) : null;
    String? selectedVehicleId = vehicles.isNotEmpty ? _extractId(vehicles.first) : null;
    final String? existingPickupId =
        _extractId(_request!['pickupOffice']) ?? _extractId(_request!['originOffice']);
    String? selectedPickupOfficeId = existingPickupId ?? _extractId(offices.first);

    debugPrint('[RequestDetails] About to show modal bottom sheet');
    debugPrint('[RequestDetails] Selected driver: $selectedDriverId');
    debugPrint('[RequestDetails] Selected vehicle: $selectedVehicleId');
    debugPrint('[RequestDetails] Selected pickup office: $selectedPickupOfficeId');

    bool? assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isSubmitting = false;

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
                    if (drivers.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                          borderRadius: AppTheme.bradiusS,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                'No drivers are currently available. All drivers may be assigned to active trips.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                    ],
                    DropdownButtonFormField<String>(
                      value: selectedDriverId,
                      decoration: const InputDecoration(
                        labelText: 'Driver',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                      items: drivers.isEmpty
                          ? [
                              const DropdownMenuItem<String>(
                                value: null,
                                enabled: false,
                                child: Text('No drivers available'),
                              ),
                            ]
                          : drivers.map<DropdownMenuItem<String>>((driver) {
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
                      onChanged: isSubmitting || drivers.isEmpty
                          ? null
                          : (value) {
                              setModalState(() {
                                selectedDriverId = value;
                              });
                            },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    if (vehicles.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                          borderRadius: AppTheme.bradiusS,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                'No vehicles are currently available. All vehicles may be assigned to active trips.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                    ],
                    DropdownButtonFormField<String>(
                      value: selectedVehicleId,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                      items: vehicles.isEmpty
                          ? [
                              const DropdownMenuItem<String>(
                                value: null,
                                enabled: false,
                                child: Text('No vehicles available'),
                              ),
                            ]
                          : vehicles.map<DropdownMenuItem<String>>((vehicle) {
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
                      onChanged: isSubmitting || vehicles.isEmpty
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
                      isExpanded: true,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
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
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

                              final errorMessage = await requestsProvider.assignDriverAndVehicle(
                                requestId: widget.requestId,
                                driverId: selectedDriverId!,
                                vehicleId: selectedVehicleId!,
                                pickupOfficeId: selectedPickupOfficeId!,
                              );

                              if (!mounted) {
                                return;
                              }

                              if (errorMessage == null) {
                                Navigator.of(context).pop(true);
                              } else {
                                setModalState(() {
                                  isSubmitting = false;
                                });
                                ToastHelper.showErrorToast(
                                  errorMessage.isNotEmpty
                                      ? errorMessage
                                      : 'Failed to assign driver and vehicle',
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

    if (assigned == true && mounted) {
      _showSuccessSnackBar('Driver and vehicle assigned successfully');
      await _loadRequest();
      if (mounted) {
        requestsProvider.loadRequests();
      }
    }
  }

  Future<void> _approveRequest() async {
    final commentsController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildAnimatedDialog(
        title: 'Approve Request',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add optional comments:'),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: commentsController,
              decoration: InputDecoration(
                hintText: 'Comments (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final success = await Provider.of<RequestsProvider>(context, listen: false)
            .approveRequest(widget.requestId, comments: commentsController.text.isEmpty ? null : commentsController.text);

        if (success && mounted) {
          Navigator.pop(context);
          _showSuccessSnackBar('Request approved successfully');
          _loadRequest(); // Refresh to show updated status
        } else if (mounted) {
          _showErrorSnackBar('Failed to approve request');
        }
      } catch (e) {
        if (mounted) {
          debugPrint('[RequestDetails] Approval error: $e');
          _showErrorSnackBar('Error approving request: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _sendBackForCorrection() async {
    final noteController = TextEditingController();
    String? correctionNote; // Store the note
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _buildAnimatedDialog(
          title: 'Send Back for Correction',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a note explaining what needs to be corrected:'),
              const SizedBox(height: AppTheme.spacingM),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'Correction note',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                maxLines: 3,
                autofocus: true,
                onChanged: (value) {
                  // Update state when text changes to enable/disable button
                  setState(() {
                    correctionNote = value.trim();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (correctionNote != null && correctionNote!.isNotEmpty)
                  ? () {
                      if (correctionNote!.isNotEmpty) {
                        Navigator.pop(context, true);
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
              ),
              child: const Text('Send Back'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && correctionNote != null && correctionNote!.isNotEmpty && mounted) {
      try {
        debugPrint('[RequestDetails] Sending back for correction with note: $correctionNote');
        final success = await Provider.of<RequestsProvider>(context, listen: false)
            .sendBackForCorrection(widget.requestId, correctionNote!);

        if (success && mounted) {
          Navigator.pop(context);
          _showSuccessSnackBar('Request sent back for correction');
          // Wait a bit for backend to process
          await Future.delayed(const Duration(milliseconds: 500));
          // Force reload to get updated request with correction details
          await _loadRequest();
          // Also reload requests list to update status
          await Provider.of<RequestsProvider>(context, listen: false).loadRequests();
          debugPrint('[RequestDetails] After correction - status: ${_request?['status']}');
          debugPrint('[RequestDetails] After correction - correctionNote: ${_request?['correctionNote']}');
        } else if (mounted) {
          _showErrorSnackBar('Failed to send back for correction');
        }
      } catch (e) {
        if (mounted) {
          debugPrint('[RequestDetails] Send back error: $e');
          _showErrorSnackBar('Error: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _cancelRequest() async {
    final noteController = TextEditingController();
    String? cancellationReason;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _buildAnimatedDialog(
          title: 'Cancel Request',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for cancelling this request:'),
              const SizedBox(height: AppTheme.spacingM),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'Cancellation reason',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                maxLines: 3,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    cancellationReason = value.trim();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (cancellationReason != null && cancellationReason!.isNotEmpty)
                  ? () {
                      if (cancellationReason!.isNotEmpty) {
                        Navigator.pop(context, true);
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && cancellationReason != null && cancellationReason!.isNotEmpty && mounted) {
      try {
        debugPrint('[RequestDetails] Cancelling request with reason: $cancellationReason');
        final success = await Provider.of<RequestsProvider>(context, listen: false)
            .cancelRequest(widget.requestId, cancellationReason!);

        if (success && mounted) {
          Navigator.pop(context);
          _showSuccessSnackBar('Request cancelled');
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadRequest();
          await Provider.of<RequestsProvider>(context, listen: false).loadRequests();
        } else if (mounted) {
          _showErrorSnackBar('Failed to cancel request');
        }
      } catch (e) {
        if (mounted) {
          debugPrint('[RequestDetails] Cancel error: $e');
          _showErrorSnackBar('Error: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _rejectRequest() async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildAnimatedDialog(
        title: 'Reject Request',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Rejection reason',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: reasonController.text.trim().isEmpty
                ? null
                : () {
                    if (reasonController.text.trim().isNotEmpty) {
                      Navigator.pop(context, true);
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty && mounted) {
      final success = await Provider.of<RequestsProvider>(context, listen: false)
          .rejectRequest(widget.requestId, reasonController.text.trim());

      if (success && mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Request rejected');
        _loadRequest(); // Refresh to show updated status
      } else if (mounted) {
        _showErrorSnackBar('Failed to reject request');
      }
    }
  }

  Widget _buildAnimatedDialog({required String title, required Widget content, required List<Widget> actions}) {
    return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppTheme.spacingM),
            content,
            SizedBox(height: AppTheme.spacingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: AppTheme.spacingM),
              const Text('Loading request details...'),
            ],
          ),
        ),
      );
    }

    if (_request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingM),
              const Text('Request not found'),
              const SizedBox(height: AppTheme.spacingL),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final status = _request!['status'] ?? '';
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?['id'] ?? authProvider.user?['_id'];
    
    // Debug logging
    debugPrint('[RequestDetails] widget.canApprove: ${widget.canApprove}');
    debugPrint('[RequestDetails] status: $status');
    debugPrint('[RequestDetails] userId: $userId');
    debugPrint('[RequestDetails] isSupervisor: ${authProvider.isSupervisor()}');
    debugPrint('[RequestDetails] supervisorId from request: ${_request!['supervisorId']}');
    
    // Always check if user can approve, regardless of widget.canApprove
    // This ensures buttons show even if navigation didn't set canApprove correctly
    // Get current stage (use currentStage if available, otherwise map from status)
    final currentStage = RequestWorkflow.getCurrentStage(_request!);
    bool canActuallyApprove = false;
    
    // Check if user can approve based on workflow stage and role
    switch (currentStage) {
      case 'submitted':
        // Supervisors can approve if they are the assigned supervisor
        if (authProvider.isSupervisor()) {
          final supervisorId = _request!['supervisorId'];
          if (supervisorId == null) {
            canActuallyApprove = false;
            debugPrint('[RequestDetails] Supervisor cannot approve: supervisorId is null');
          } else {
            String? supervisorIdStr;
            if (supervisorId is Map) {
              supervisorIdStr = (supervisorId['_id'] ?? supervisorId['id'])?.toString();
            } else {
              supervisorIdStr = supervisorId?.toString();
            }
            final userIdStr = userId?.toString();
            canActuallyApprove = supervisorIdStr == userIdStr;
            debugPrint('[RequestDetails] Supervisor approval check at submitted: supervisorId=$supervisorIdStr, userId=$userIdStr, canApprove=$canActuallyApprove');
          }
        } 
        // DGS can approve any SUBMITTED request
        if (!canActuallyApprove) {
          canActuallyApprove = authProvider.hasRole('dgs');
        }
        break;
      case 'supervisor_review':
        // Supervisors can approve if they are the assigned supervisor
        if (authProvider.isSupervisor()) {
          final supervisorId = _request!['supervisorId'];
          if (supervisorId == null) {
            canActuallyApprove = false;
          } else {
            String? supervisorIdStr;
            if (supervisorId is Map) {
              supervisorIdStr = (supervisorId['_id'] ?? supervisorId['id'])?.toString();
            } else {
              supervisorIdStr = supervisorId?.toString();
            }
            final userIdStr = userId?.toString();
            canActuallyApprove = supervisorIdStr == userIdStr;
          }
        } else {
          // DGS can also act at supervisor_review
          canActuallyApprove = authProvider.hasRole('dgs');
        }
        break;
      case 'dgs_review':
        canActuallyApprove = authProvider.hasRole('dgs');
        break;
      case 'ddgs_review':
        canActuallyApprove = authProvider.hasRole('ddgs');
        break;
      case 'ad_transport_review':
        canActuallyApprove = authProvider.hasRole('ad_transport');
        break;
      case 'transport_officer_assignment':
        canActuallyApprove = authProvider.hasRole('transport_officer') || authProvider.hasRole('dgs');
        break;
      case 'dgs_review':
        // DGS can approve normally or assign (skip to Transport Officer)
        canActuallyApprove = authProvider.hasRole('dgs');
        break;
      default:
        canActuallyApprove = false;
    }
    
    debugPrint('[RequestDetails] Current stage: $currentStage, Final canActuallyApprove: $canActuallyApprove');

    // DGS can assign at dgs_review (skip) or transport_officer_assignment, Transport Officer can assign at transport_officer_assignment
    final canAssignTransportOfficer =
        (authProvider.hasRole('transport_officer') && currentStage == 'transport_officer_assignment') ||
        (authProvider.hasRole('dgs') && (currentStage == 'transport_officer_assignment' || currentStage == 'dgs_review'));

    // Determine if buttons should be shown
    // Show for all approvers at their respective stages, excluding terminal and correction states
    final terminalStages = [
      'rejected',
      'needs_correction',
      'completed',
      'in_progress',
      'returned',
      'assigned',
      'transport_officer_assignment',
      'cancelled',
    ];
    final shouldShowApproveButtons = canActuallyApprove && !terminalStages.contains(currentStage);
    
    // Check if user can cancel (only requester at certain stages)
    final isRequester = _request!['requesterId'] != null && 
                       (userId?.toString() == _request!['requesterId']?['_id']?.toString() ||
                        userId?.toString() == _request!['requesterId']?['id']?.toString() ||
                        userId?.toString() == _request!['requesterId']?.toString());
    final canCancel = isRequester && RequestWorkflow.canCancelAtStage(currentStage) && 
                     !terminalStages.contains(currentStage);
    
    debugPrint('[RequestDetails] shouldShowApproveButtons: $shouldShowApproveButtons');

    final showActionBar = shouldShowApproveButtons || canAssignTransportOfficer || canCancel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        elevation: 0,
      ),
      bottomNavigationBar: showActionBar
          ? _buildBottomActionBar(
              shouldShowApproveButtons: shouldShowApproveButtons,
              canAssign: canAssignTransportOfficer,
              canCancel: canCancel,
            )
          : null,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: AppTheme.spacingL),
              _buildCorrectionSection(),
              
              // Timeline - Hide for requester when status is needs_correction
              Builder(
                builder: (context) {
                  final status = _request!['status'] ?? '';
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final userId = authProvider.user?['id'] ?? authProvider.user?['_id'];
                  final requesterId = _request!['requesterId'];
                  String? requesterIdStr;
                  if (requesterId != null) {
                    if (requesterId is Map) {
                      requesterIdStr = (requesterId['_id'] ?? requesterId['id'])?.toString();
                    } else {
                      requesterIdStr = requesterId.toString();
                    }
                  }
                  final isRequester = requesterIdStr == userId?.toString();
                  
                  // Hide timeline if requester is viewing a needs_correction request
                  if (status == 'needs_correction' && isRequester) {
                    return const SizedBox.shrink();
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWorkflowTimeline(),
                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  );
                },
              ),
              
              // Trip Information Section
              _buildSectionHeader('Trip Information'),
              const SizedBox(height: AppTheme.spacingM),
              _buildInfoRow('Origin Office', _getOriginOfficeInfo(), Icons.location_on),
              if (authProvider.hasRole('transport_officer') ||
                  _request!['pickupOffice'] != null) ...[
                const Divider(height: AppTheme.spacingXL),
                _buildInfoRow(
                  'Pickup Office',
                  _getPickupOfficeInfo(),
                  Icons.store_mall_directory_rounded,
                ),
              ],
              const Divider(height: AppTheme.spacingXL),
              _buildInfoRow('Destination', _request!['destination'] ?? 'Not specified', Icons.place),
              const Divider(height: AppTheme.spacingXL),
              _buildInfoRow('Purpose', _request!['purpose'] ?? 'Not specified', Icons.description),
              const Divider(height: AppTheme.spacingXL),
              _buildInfoRow('Passengers', '${_request!['passengerCount'] ?? 0}', Icons.people),
              if (_request!['estimatedDistance'] != null) ...[
                const Divider(height: AppTheme.spacingXL),
                _buildInfoRow(
                  'Estimated Distance',
                  '${(_request!['estimatedDistance'] as num).toStringAsFixed(1)} km',
                  Icons.straighten_rounded,
                ),
              ],
              if (_request!['estimatedFuelLitres'] != null) ...[
                const Divider(height: AppTheme.spacingXL),
                _buildInfoRow(
                  'Estimated Fuel',
                  '${(_request!['estimatedFuelLitres'] as num).toStringAsFixed(2)} L',
                  Icons.local_gas_station_rounded,
                ),
              ],
              if (_request!['startDate'] != null) ...[
                const Divider(height: AppTheme.spacingXL),
                _buildInfoRow(
                  'Start Date',
                  DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(_request!['startDate'])),
                  Icons.calendar_today,
                ),
              ],
              if (_request!['endDate'] != null) ...[
                const Divider(height: AppTheme.spacingXL),
                _buildInfoRow(
                  'End Date',
                  DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(_request!['endDate'])),
                  Icons.event,
                ),
              ],
              
              // Assignment Details Section (if assigned)
              if (_request!['assignedDriverId'] != null || _request!['assignedVehicleId'] != null) ...[
                const SizedBox(height: AppTheme.spacingXL),
                _buildSectionHeader('Assignment Details'),
                const SizedBox(height: AppTheme.spacingM),
                if (_request!['assignedDriverId'] != null)
                  _buildInfoRow('Driver', _getDriverInfo(), Icons.drive_eta),
                if (_request!['assignedDriverId'] != null && _request!['assignedVehicleId'] != null)
                  const Divider(height: AppTheme.spacingXL),
                if (_request!['assignedVehicleId'] != null)
                  _buildInfoRow('Vehicle', _getVehicleInfo(), Icons.directions_car),
              ],
              
              // Requester Information Section
              const SizedBox(height: AppTheme.spacingXL),
              _buildSectionHeader('Requester Information'),
              const SizedBox(height: AppTheme.spacingM),
              _buildInfoRow('Requester', _getRequesterInfo(), Icons.person),
              
              const SizedBox(height: AppTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final theme = Theme.of(context);
    final request = _request!;
    final status = (request['status'] ?? '').toString();
    final statusColor = AppTheme.getStatusColor(status);
    final statusLabel = RequestWorkflow.formatStatus(status);
    final destination = (request['destination'] ?? 'Unknown destination').toString();
    final purpose = (request['purpose'] ?? '').toString();
    final passengerCount = request['passengerCount']?.toString() ?? '-';
    final pickupOfficeInfo = request['pickupOffice'] ?? request['originOffice'];
    final pickup = _resolveOfficeLabel(pickupOfficeInfo);
    final startDate = _formatDate(request['startDate'], includeTime: true);
    final endDate = _formatDate(request['endDate'], includeTime: true);
    final driverName = _resolvePersonName(request['assignedDriverId']);
    final vehicleLabel = _resolveVehicleLabel(request['assignedVehicleId']);
    final estimatedDistance = request['estimatedDistance'];
    final estimatedFuelLitres = request['estimatedFuelLitres'];

    return AppCard(
      backgroundColor: theme.colorScheme.surface,
      borderColor: theme.colorScheme.outline.withOpacity(0.08),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                borderRadius: AppTheme.bradiusS,
                color: statusColor.withOpacity(0.12),
                border: Border.all(color: statusColor.withOpacity(0.32)),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            destination,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (purpose.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              purpose,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppTheme.spacingM),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final allowMultiColumn = availableWidth >= 420;
              final pillWidth = allowMultiColumn
                  ? (availableWidth - AppTheme.spacingS) / 2
                  : availableWidth;

              final summaryTiles = <Widget>[
                _summaryPill(
                  icon: Icons.event_available_rounded,
                  label: 'Start: $startDate',
                  maxWidth: pillWidth,
                ),
                if (endDate.isNotEmpty)
                  _summaryPill(
                    icon: Icons.event_busy_rounded,
                    label: 'End: $endDate',
                    maxWidth: pillWidth,
                  ),
                _summaryPill(
                  icon: Icons.people_alt_rounded,
                  label: 'Passengers: $passengerCount',
                  maxWidth: pillWidth,
                ),
                if (estimatedDistance is num && estimatedDistance > 0)
                  _summaryPill(
                    icon: Icons.straighten_rounded,
                    label: 'Est. distance: ${estimatedDistance.toStringAsFixed(1)} km',
                    maxWidth: pillWidth,
                  ),
                if (estimatedFuelLitres is num && estimatedFuelLitres > 0)
                  _summaryPill(
                    icon: Icons.local_gas_station_rounded,
                    label: 'Est. fuel: ${estimatedFuelLitres.toStringAsFixed(2)} L',
                    maxWidth: pillWidth,
                  ),
                if (pickup.isNotEmpty)
                  _summaryPill(
                    icon: Icons.location_city_rounded,
                    label: 'Pickup: $pickup',
                    maxWidth: pillWidth,
                  ),
                if (driverName.isNotEmpty)
                  _summaryPill(
                    icon: Icons.person_rounded,
                    label: 'Driver: $driverName',
                    maxWidth: pillWidth,
                  ),
                if (vehicleLabel.isNotEmpty)
                  _summaryPill(
                    icon: Icons.directions_car_rounded,
                    label: 'Vehicle: $vehicleLabel',
                    maxWidth: pillWidth,
                  ),
              ];

              return Wrap(
                spacing: AppTheme.spacingS,
                runSpacing: AppTheme.spacingS,
                children: summaryTiles,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar({
    required bool shouldShowApproveButtons,
    required bool canAssign,
    required bool canCancel,
  }) {
    final actions = <Widget>[];

    if (canAssign) {
      debugPrint('[RequestDetails] Adding Assign button to action bar');
      debugPrint('[RequestDetails] _isAssigning: $_isAssigning');
      actions.add(
        OutlinedButton.icon(
          onPressed: _isAssigning
              ? null
              : () {
                  debugPrint('[RequestDetails] Assign button pressed');
                  _openAssignmentSheet();
                },
          icon: const Icon(Icons.assignment_ind_rounded),
          label: Text(_isAssigning ? 'Assigning...' : 'Assign'),
        ),
      );
    } else {
      debugPrint('[RequestDetails] canAssign is false - not showing Assign button');
    }

    if (shouldShowApproveButtons) {
      actions.add(
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.warningColor,
            side: BorderSide(color: AppTheme.warningColor.withOpacity(0.4)),
          ),
          onPressed: _sendBackForCorrection,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Send Back'),
        ),
      );
      actions.add(
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: BorderSide(color: AppTheme.errorColor.withOpacity(0.4)),
          ),
          onPressed: _rejectRequest,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Reject'),
        ),
      );
      actions.add(
        FilledButton.icon(
          onPressed: _approveRequest,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approve'),
        ),
      );
    }

    if (canCancel) {
      actions.add(
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
          ),
          onPressed: _cancelRequest,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel'),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: AppTheme.neutral20)),
        ),
        child: Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          alignment: WrapAlignment.end,
          children: actions
              .map(
                (button) => ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: button,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _summaryPill({required IconData icon, required String label, double? maxWidth}) {
    final theme = Theme.of(context);
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        borderRadius: AppTheme.bradiusS,
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.12)),
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppTheme.spacingXS),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
              softWrap: true,
            ),
          ),
        ],
      ),
    );

    if (maxWidth != null) {
      return SizedBox(
        width: maxWidth,
        child: pill,
      );
    }

    return pill;
  }

  String _resolvePersonName(dynamic value) {
    if (value is Map && value['name'] != null) {
      return value['name'].toString();
    }
    return '';
  }

  String _resolveVehicleLabel(dynamic value) {
    if (value is Map<String, dynamic>) {
      final plate = value['plateNumber']?.toString() ?? '';
      final make = value['make']?.toString() ?? '';
      final model = value['model']?.toString() ?? '';
      return [plate, '$make $model'.trim()].where((segment) => segment.trim().isNotEmpty).join(' • ');
    }
    return '';
  }

  String _resolveOfficeLabel(dynamic value) {
    if (value is Map<String, dynamic>) {
      final name = value['name']?.toString().trim() ?? '';
      final address = value['address']?.toString().trim() ?? '';
      final parts = [
        if (name.isNotEmpty) name,
        if (address.isNotEmpty) address,
      ];
      return parts.join(' • ');
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      final isHexId = RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(trimmed);
      return isHexId ? 'Pending assignment' : trimmed;
    }

    return '';
  }

  String _formatDate(dynamic value, {bool includeTime = false}) {
    if (value == null) return '';
    try {
      final date = value is DateTime ? value : DateTime.parse(value.toString());
      return DateFormat(includeTime ? 'MMM dd, yyyy • HH:mm' : 'MMM dd, yyyy').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  Widget _buildWorkflowTimeline() {
    final approvalChain = _request!['approvalChain'] as List? ?? [];
    final status = _request!['status'] ?? '';
    final rejectionReason = _request!['rejectionReason'] as String?;
    final rejectedAt = _request!['rejectedAt'] != null 
        ? DateTime.parse(_request!['rejectedAt']) 
        : null;
    final rejectedBy = _request!['rejectedBy'] != null
        ? (_request!['rejectedBy'] is Map
            ? (_request!['rejectedBy'] as Map)['name']?.toString()
            : _request!['rejectedBy'].toString())
        : null;
    final resubmittedAt = _request!['resubmittedAt'] != null
        ? DateTime.parse(_request!['resubmittedAt'])
        : null;
    final createdAt = _request!['createdAt'] != null
        ? DateTime.parse(_request!['createdAt'])
        : null;
    final correctionNote = _request!['correctionNote'] as String?;
    final correctedAt = _request!['correctedAt'] != null
        ? DateTime.parse(_request!['correctedAt'])
        : null;
    final correctedBy = _request!['correctedBy'] != null
        ? (_request!['correctedBy'] is Map
            ? (_request!['correctedBy'] as Map)['name']?.toString()
            : _request!['correctedBy'].toString())
        : null;

    // Get action history and correction history if available
    final actionHistory = _request!['actionHistory'] as List?;
    final correctionHistory = _request!['correctionHistory'] as List?;
    final cancellationReason = _request!['cancellationReason'] as String?;
    final cancelledAt = _request!['cancelledAt'] != null
        ? DateTime.parse(_request!['cancelledAt'])
        : null;
    final cancelledBy = _request!['cancelledBy'] != null
        ? (_request!['cancelledBy'] is Map
            ? (_request!['cancelledBy'] as Map)['name']?.toString()
            : _request!['cancelledBy'].toString())
        : null;

    // Get current stage (prefer currentStage field, fallback to mapping from status)
    final currentStage = RequestWorkflow.getCurrentStage(_request!);
    
    final timelineItems = RequestWorkflow.buildWorkflowTimeline(
      currentStatus: status,
      currentStage: currentStage, // Pass currentStage explicitly
      approvalChain: approvalChain,
      actionHistory: actionHistory,
      correctionHistory: correctionHistory,
      rejectionReason: rejectionReason,
      rejectedAt: rejectedAt,
      rejectedBy: rejectedBy,
      resubmittedAt: resubmittedAt,
      createdAt: createdAt,
      correctionNote: correctionNote,
      correctedAt: correctedAt,
      correctedBy: correctedBy,
      cancellationReason: cancellationReason,
      cancelledAt: cancelledAt,
      cancelledBy: cancelledBy,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.timeline_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Request Progress',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingL),
        TimelineWidget(
          items: timelineItems,
          expandable: true,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildCorrectionSection() {
    final status = _request?['status']?.toString() ?? '';
    final correctionHistory = _request?['correctionHistory'] as List?;
    final hasCorrectionHistory = correctionHistory != null && correctionHistory.isNotEmpty;
    final correctionNote = _request?['correctionNote']?.toString();

    final shouldShowCard = status == 'needs_correction' ||
        (correctionNote != null && correctionNote.isNotEmpty) ||
        hasCorrectionHistory;

    if (!shouldShowCard) {
      return const SizedBox.shrink();
    }

    // Determine if current user (requester) can edit during needs_correction and not yet resubmitted
    bool canEdit = false;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['id'] ?? authProvider.user?['_id'];
      final requesterId = _request?['requesterId'];
      String? requesterIdStr;
      if (requesterId != null) {
        if (requesterId is Map) {
          requesterIdStr = (requesterId['_id'] ?? requesterId['id'])?.toString();
        } else {
          requesterIdStr = requesterId.toString();
        }
      }
      final isRequester = requesterIdStr == userId?.toString();
      final resubmittedRaw = _request?['resubmittedAt'];
      final DateTime? resubmittedAt =
          resubmittedRaw != null ? DateTime.tryParse(resubmittedRaw.toString()) : null;
      final hasBeenResubmitted = resubmittedAt != null;
      canEdit = status == 'needs_correction' && isRequester && !hasBeenResubmitted;
    } catch (_) {
      canEdit = false;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXL),
      child: _buildCorrectionDetailsCard(canEdit: canEdit),
    );
  }

  Widget _buildCorrectionDetailsCard({bool canEdit = false}) {
    debugPrint('[RequestDetails] Building correction card');
    debugPrint('[RequestDetails] correctionNote from request: ${_request!['correctionNote']}');
    debugPrint('[RequestDetails] status: ${_request!['status']}');
    
    // Get all correction entries from approval chain (for full audit trail)
    final approvalChain = _request!['approvalChain'] as List? ?? [];
    final correctionEntries = approvalChain
        .where((entry) => entry['status'] == 'needs_correction')
        .toList();
    var correctionNote = _request!['correctionNote'] as String?;
    Map<String, dynamic>? latestCorrectionEntry;
    
    // Find latest correction entry
    for (var entry in approvalChain.reversed) {
      if (entry['status'] == 'needs_correction') {
        latestCorrectionEntry = entry;
        if (correctionNote == null && entry['comments'] != null) {
          correctionNote = entry['comments'].toString();
        }
        break;
      }
    }
    
    final correctionEntry = latestCorrectionEntry;
    
    final correctedAt = _request!['correctedAt'] != null
        ? DateTime.parse(_request!['correctedAt'])
        : (correctionEntry?['timestamp'] != null 
            ? DateTime.parse(correctionEntry!['timestamp']) 
            : null);
    final correctedBy = _request!['correctedBy'] != null
        ? (_request!['correctedBy'] is Map
            ? (_request!['correctedBy'] as Map)['name']?.toString()
            : _request!['correctedBy'].toString())
        : null;
    final status = _request!['status'] ?? '';
    final isNeedsCorrection = status == 'needs_correction';
    final resubmittedAt = _request!['resubmittedAt'] != null
        ? DateTime.parse(_request!['resubmittedAt'])
        : null;
    final hasBeenResubmitted = resubmittedAt != null;
    
    // Get correctedBy from approval chain if not directly available
    final correctedByFromChain = correctionEntry != null && correctionEntry['approverId'] != null
        ? (correctionEntry['approverId'] is Map
            ? (correctionEntry['approverId'] as Map)['name']?.toString()
            : null)
        : null;
    final finalCorrectedBy = correctedBy ?? correctedByFromChain;
    
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: isNeedsCorrection 
            ? AppTheme.warningColor.withOpacity(0.1)
            : AppTheme.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isNeedsCorrection
              ? AppTheme.warningColor.withOpacity(0.3)
              : AppTheme.infoColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNeedsCorrection ? Icons.edit_note_rounded : Icons.info_outline_rounded,
                color: isNeedsCorrection ? AppTheme.warningColor : AppTheme.infoColor,
                size: 24,
              ),
              SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  isNeedsCorrection ? 'Correction Required' : 'Correction History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNeedsCorrection ? AppTheme.warningColor : AppTheme.infoColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          if (correctionNote != null && correctionNote.isNotEmpty) ...[
            Text(
              'Correction Note:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              correctionNote,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: AppTheme.spacingM),
          ],
          if (finalCorrectedBy != null) ...[
            _buildInfoRow('Sent Back By', finalCorrectedBy, Icons.person_outline),
            SizedBox(height: AppTheme.spacingS),
          ],
          if (correctedAt != null) ...[
            _buildInfoRow(
              'Sent Back On',
              DateFormat('MMM dd, yyyy HH:mm').format(correctedAt),
              Icons.access_time,
            ),
          ],
          // Show resubmission status if resubmitted
          if (hasBeenResubmitted) ...[
            SizedBox(height: AppTheme.spacingM),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 24,
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Resubmitted',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Resubmitted on ${DateFormat('MMM dd, yyyy HH:mm').format(resubmittedAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.of(context).textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Fix Request button at the bottom - only show if needs correction AND not resubmitted
          if (isNeedsCorrection && canEdit && !hasBeenResubmitted) ...[
            SizedBox(height: AppTheme.spacingM),
            FilledButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateRequestScreen(
                      requestId: widget.requestId,
                      onMenuPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    fullscreenDialog: false,
                  ),
                );
                if (result == true && mounted) {
                  await _loadRequest();
                  Provider.of<RequestsProvider>(context, listen: false).loadRequests();
                }
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Fix Request'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
          // Show all corrections if there are multiple
          if (correctionEntries.length > 1) ...[
            SizedBox(height: AppTheme.spacingM),
            Divider(),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'All Corrections (${correctionEntries.length}):',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppTheme.spacingS),
            ...correctionEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final correction = entry.value;
              final correctionNoteText = correction['comments']?.toString() ?? 'No note';
              final correctionTimestamp = correction['timestamp'] != null
                  ? DateTime.parse(correction['timestamp'])
                  : null;
              final approver = correction['approverId'];
              final approverName = approver is Map
                  ? (approver['name']?.toString() ?? 'Unknown')
                  : 'Unknown';
              
              return Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final colorScheme = theme.colorScheme;
                  final background = Color.lerp(
                        colorScheme.surfaceVariant,
                        colorScheme.surface,
                        theme.brightness == Brightness.dark ? 0.1 : 0.4,
                      ) ??
                      colorScheme.surfaceVariant;

                  return Container(
                    margin: EdgeInsets.only(bottom: AppTheme.spacingS),
                    padding: EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Correction #${index + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingXS),
                        Text(
                          correctionNoteText,
                          style: theme.textTheme.bodySmall,
                        ),
                        SizedBox(height: AppTheme.spacingXS),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: AppTheme.spacingXS),
                            Text(
                              approverName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (correctionTimestamp != null) ...[
                              SizedBox(width: AppTheme.spacingM),
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: AppTheme.spacingXS),
                              Text(
                                DateFormat('MMM dd, yyyy HH:mm').format(correctionTimestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  String _getRequesterInfo() {
    final requester = _request!['requesterId'];
    if (requester == null) return 'Unknown';
    final name = requester['name'] ?? 'Unknown';
    final email = requester['email'] ?? '';
    if (email.isNotEmpty) {
      return '$name\n$email';
    }
    return name;
  }

  String _getDriverInfo() {
    final driver = _request!['assignedDriverId'];
    if (driver == null) return 'Not assigned';
    final name = driver['name'] ?? 'Unknown';
    final phone = driver['phone'] ?? '';
    if (phone.isNotEmpty) {
      return '$name\n$phone';
    }
    return name;
  }

  String _getVehicleInfo() {
    final vehicle = _request!['assignedVehicleId'];
    if (vehicle == null) return 'Not assigned';
    final plateNumber = vehicle['plateNumber'] ?? 'Unknown';
    final make = vehicle['make'] ?? '';
    final model = vehicle['model'] ?? '';
    if (make.isNotEmpty && model.isNotEmpty) {
      return '$plateNumber\n$make $model';
    }
    return plateNumber;
  }

  String _getPickupOfficeInfo() {
    final pickupOffice = _request!['pickupOffice'];
    if (pickupOffice == null) return 'Not assigned';

    if (pickupOffice is Map) {
      final name = pickupOffice['name']?.toString();
      final address = pickupOffice['address']?.toString();
      if (name != null && address != null) {
        return '$name\n$address';
      }
      if (name != null) return name;
    }

    return 'Office ID: ${pickupOffice.toString()}';
  }

  String? _extractId(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final idValue = value['_id'] ?? value['id'];
      if (idValue == null) return null;
      return idValue.toString();
    }
    return value.toString();
  }

  String _getOriginOfficeInfo() {
    final originOffice = _request!['originOffice'];
    if (originOffice == null) return 'Not specified';
    
    // Handle both cases: if populated (Map) or just ID (String)
    if (originOffice is Map) {
      // If populated, use the name
      return originOffice['name'] ?? 'Not specified';
    } else if (originOffice is String) {
      // If it's just an ID, return a placeholder or the ID
      // In a real app, you might want to fetch the office name here
      return 'Office ID: $originOffice';
    }
    
    return 'Not specified';
  }

}




