import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../providers/requests_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/realtime_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_helper.dart';
import '../widgets/layout/app_page_container.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/app_section_header.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key, this.requestId, this.onMenuPressed});

  final String? requestId;
  final VoidCallback? onMenuPressed;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  
  String? _selectedOfficeId;
  String? _selectedSupervisorId;
  List<dynamic> _offices = [];
  List<dynamic> _supervisors = [];
  final _destinationController = TextEditingController();
  final _purposeController = TextEditingController();
  final _passengerCountController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  LatLng? _destinationCoordinates;
  bool _isLoading = false;
  bool _isLoadingSupervisors = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _loadOffices();
    _checkAccessAndLoadSupervisors();
    
    // If in edit mode, load existing request data after a short delay to ensure offices/supervisors are loaded
    if (widget.requestId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _loadRequestData();
        }
      });
    }
    
    // Setup real-time supervisor updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final realtimeProvider = Provider.of<RealtimeProvider>(context, listen: false);
      realtimeProvider.setUsersUpdateCallback(() {
        _loadSupervisors();
      });
    });
  }

  Future<void> _loadRequestData() async {
    if (widget.requestId == null) return;
    
    try {
      setState(() => _isLoading = true);
      final request = await _apiService.getRequest(widget.requestId!);
      
      debugPrint('[CreateRequest] Loading request data: ${request.toString()}');
      
      // Pre-fill form fields
      // Handle originOffice - could be populated object or just ID
      if (request['originOffice'] != null) {
        if (request['originOffice'] is Map) {
          _selectedOfficeId = request['originOffice']['_id']?.toString() ?? 
                              request['originOffice']['id']?.toString();
        } else {
          _selectedOfficeId = request['originOffice'].toString();
        }
        debugPrint('[CreateRequest] Set originOffice: $_selectedOfficeId');
      }
      
      // Pre-fill text fields
      if (request['destination'] != null) {
        _destinationController.text = request['destination'].toString();
        debugPrint('[CreateRequest] Set destination: ${_destinationController.text}');
      }
      
      if (request['purpose'] != null) {
        _purposeController.text = request['purpose'].toString();
        debugPrint('[CreateRequest] Set purpose: ${_purposeController.text}');
      }
      
      if (request['passengerCount'] != null) {
        _passengerCountController.text = request['passengerCount'].toString();
        debugPrint('[CreateRequest] Set passengerCount: ${_passengerCountController.text}');
      }
      
      // Handle dates - could be ISO string or Date object
      if (request['startDate'] != null) {
        try {
          if (request['startDate'] is String) {
            _startDate = DateTime.parse(request['startDate']);
          } else {
            _startDate = DateTime.parse(request['startDate'].toString());
          }
          debugPrint('[CreateRequest] Set startDate: $_startDate');
        } catch (e) {
          debugPrint('[CreateRequest] Error parsing startDate: $e');
        }
      }
      
      if (request['endDate'] != null) {
        try {
          if (request['endDate'] is String) {
            _endDate = DateTime.parse(request['endDate']);
          } else {
            _endDate = DateTime.parse(request['endDate'].toString());
          }
          debugPrint('[CreateRequest] Set endDate: $_endDate');
        } catch (e) {
          debugPrint('[CreateRequest] Error parsing endDate: $e');
        }
      }
      
      // Handle destination coordinates
      if (request['destinationCoordinates'] != null) {
        try {
          final coords = request['destinationCoordinates'];
          if (coords is Map) {
            final lat = coords['lat'];
            final lng = coords['lng'];
            if (lat != null && lng != null) {
              _destinationCoordinates = LatLng(
                lat is double ? lat : double.parse(lat.toString()),
                lng is double ? lng : double.parse(lng.toString()),
              );
              debugPrint('[CreateRequest] Set coordinates: $_destinationCoordinates');
            }
          }
        } catch (e) {
          debugPrint('[CreateRequest] Error parsing coordinates: $e');
        }
      }
      
      // Set supervisor if exists
      if (request['supervisorId'] != null) {
        if (request['supervisorId'] is Map) {
          _selectedSupervisorId = request['supervisorId']['_id']?.toString() ?? 
                                  request['supervisorId']['id']?.toString();
        } else {
          _selectedSupervisorId = request['supervisorId'].toString();
        }
        debugPrint('[CreateRequest] Set supervisorId: $_selectedSupervisorId');
      }
      
      setState(() {
        _isLoading = false;
      });
      
      debugPrint('[CreateRequest] Finished loading request data');
    } catch (e) {
      debugPrint('[CreateRequest] Error loading request: $e');
      setState(() => _isLoading = false);
      ToastHelper.showErrorToast('Failed to load request: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    _passengerCountController.dispose();
    super.dispose();
  }

  void _checkAccessAndLoadSupervisors() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.canCreateRequest()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorSnackBar('You do not have permission to create requests');
          Navigator.of(context).pop();
        }
      });
      return;
    }

    if (authProvider.canCreateRequest() && !authProvider.isSupervisor()) {
      _loadSupervisors();
    }
  }

  void _showErrorSnackBar(String message) {
    ToastHelper.showErrorToast(message);
  }

  void _showSuccessSnackBar(String message) {
    ToastHelper.showSuccessToast(message);
  }

  Future<void> _showOfficeBottomSheet() async {
    if (_offices.isEmpty) {
      ToastHelper.showWarningToast('No offices available');
      return;
    }

    final theme = Theme.of(context);

    final selected = await showMaterialModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Origin Office',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _offices.length,
                itemBuilder: (context, index) {
                  final office = _offices[index];
                  final officeId = office['_id']?.toString();
                  final isSelected = _selectedOfficeId == officeId;
                  
                  return ListTile(
                    leading: Icon(
                      Icons.business_rounded,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(office['name'] ?? 'Unknown'),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context, officeId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedOfficeId = selected;
      });
    }
  }

  Future<void> _showSupervisorBottomSheet() async {
    if (_supervisors.isEmpty) {
      ToastHelper.showWarningToast('No supervisors available in your department');
      return;
    }

    final searchController = TextEditingController();
    List<dynamic> filteredSupervisors = List.from(_supervisors);

    final theme = Theme.of(context);

    final selected = await showMaterialModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Select Supervisor',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search by name or email',
                    ),
                  ),
                ),
                Flexible(
                  child: _isLoadingSupervisors
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : filteredSupervisors.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 48,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  Text(
                                    'No supervisors found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredSupervisors.length,
                              itemBuilder: (context, index) {
                                final supervisor = filteredSupervisors[index];
                                final supervisorId = supervisor['_id']?.toString();
                                final isSelected = _selectedSupervisorId == supervisorId;
                                
                                return ListTile(
                                  leading: Icon(
                                    Icons.supervisor_account_rounded,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  title: Text(supervisor['name'] ?? 'Unknown Supervisor'),
                                  subtitle: Text(supervisor['email'] ?? ''),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(context, supervisorId);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      searchController.dispose();
    });

    if (selected != null) {
      setState(() {
        _selectedSupervisorId = selected;
      });
    }
  }

  Future<void> _loadOffices() async {
    try {
      final offices = await _apiService.getOffices();
      if (mounted) {
        setState(() {
          _offices = offices;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load offices: ${e.toString()}');
      }
    }
  }

  Future<void> _loadSupervisors() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final department = authProvider.getDepartment();
    
    if (department == null || department.isEmpty) {
      if (mounted) {
        _showErrorSnackBar('Department not found. Cannot load supervisors.');
      }
      return;
    }

    setState(() {
      _isLoadingSupervisors = true;
    });

    try {
      final supervisors = await _apiService.getSupervisorsByDepartment(department);
      if (mounted) {
        setState(() {
          _supervisors = supervisors;
          _isLoadingSupervisors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSupervisors = false;
        });
        _showErrorSnackBar('Failed to load supervisors: ${e.toString()}');
      }
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    if (!mounted) return;
    
    final theme = Theme.of(context);

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(data: theme, child: child!);
      },
    );

    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(data: theme, child: child!);
        },
      );

      if (time != null) {
        setState(() {
          final dateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          if (isStartDate) {
            _startDate = dateTime;
          } else {
            _endDate = dateTime;
          }
        });
      }
    }
  }

  Future<void> _handlePlaceSelected(Prediction prediction) async {
    setState(() {
      _destinationController.text = prediction.description ?? '';
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOfficeId == null) {
      _showErrorSnackBar('Please select an origin office');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showErrorSnackBar('Please select start and end dates');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isSupervisor() && (_selectedSupervisorId == null || _selectedSupervisorId!.isEmpty)) {
      _showErrorSnackBar('Please select a supervisor');
      return;
    }

    // Check if in edit mode
    final isEditMode = widget.requestId != null;

    setState(() {
      _isLoading = true;
    });

    final requestData = <String, dynamic>{
      'originOffice': _selectedOfficeId,
      'destination': _destinationController.text,
      'startDate': _startDate!.toIso8601String(),
      'endDate': _endDate!.toIso8601String(),
      'purpose': _purposeController.text,
      'passengerCount': int.parse(_passengerCountController.text),
    };

    // Add optional fields
    if (_destinationCoordinates != null) {
      requestData['destinationCoordinates'] = {
        'lat': _destinationCoordinates!.latitude,
        'lng': _destinationCoordinates!.longitude,
      };
    }

    // Always include supervisorId if user is not a supervisor and supervisor is selected
    if (!authProvider.isSupervisor() && _selectedSupervisorId != null && _selectedSupervisorId!.isNotEmpty) {
      requestData['supervisorId'] = _selectedSupervisorId;
    }

    try {
      final success = isEditMode
          ? await Provider.of<RequestsProvider>(context, listen: false)
              .updateRequest(widget.requestId!, requestData)
          : await Provider.of<RequestsProvider>(context, listen: false)
              .createRequest(requestData);

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        if (isEditMode) {
          _showSuccessSnackBar('Request updated successfully');
          // If editing a request that needs correction, offer to resubmit
          final request = await _apiService.getRequest(widget.requestId!);
          if (request['status'] == 'needs_correction') {
            await Future.delayed(const Duration(milliseconds: 500));
            final shouldResubmit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Resubmit Request?'),
                content: const Text('Would you like to resubmit this request now?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Resubmit'),
                  ),
                ],
              ),
            );
            
            if (shouldResubmit == true && mounted) {
              try {
                debugPrint('[CreateRequest] Resubmitting request: ${widget.requestId}');
                final resubmitSuccess = await Provider.of<RequestsProvider>(context, listen: false)
                    .resubmitRequest(widget.requestId!);
                if (resubmitSuccess && mounted) {
                  _showSuccessSnackBar('Request resubmitted successfully');
                  // Wait a bit for backend to process
                  await Future.delayed(const Duration(milliseconds: 1000));
                  // Reload requests list to get updated status
                  await Provider.of<RequestsProvider>(context, listen: false).loadRequests();
                  debugPrint('[CreateRequest] Request list reloaded after resubmission');
                } else {
                  debugPrint('[CreateRequest] Resubmission returned false');
                }
              } catch (e) {
                debugPrint('[CreateRequest] Resubmission error: $e');
                if (mounted) {
                  _showErrorSnackBar('Failed to resubmit: ${e.toString()}');
                }
              }
            }
          }
        } else {
          _showSuccessSnackBar('Request created successfully');
        }
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else if (mounted) {
        _showErrorSnackBar(isEditMode 
            ? 'Failed to update request' 
            : 'Failed to create request');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.requestId != null ? 'Edit Request' : 'Create Request';
    final theme = Theme.of(context);

    Widget _buildLeading(BuildContext context) {
      return IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
          }
        },
      );
    }

    return AppScaffold(
      header: AppSectionHeader(
        onMenuPressed: widget.onMenuPressed,
        leading: _buildLeading(context),
        showMenuButton: !Navigator.of(context).canPop(),
        icon: widget.requestId != null ? Icons.edit_road_rounded : Icons.add_road_rounded,
        title: title,
        subtitle: 'Fill out the trip details and submit for approval.',
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingXXL),
          child: AppPageContainer(
            child: AppCard(
                showShadow: false,
                backgroundColor: theme.colorScheme.surface,
                borderColor: theme.colorScheme.outline.withOpacity(0.08),
                padding: const EdgeInsets.all(AppTheme.spacingXL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _showOfficeBottomSheet,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Origin Office *',
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.bradiusS,
                          ),
                          prefixIcon: const Icon(Icons.business_rounded),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _selectedOfficeId == null
                              ? 'Select an office'
                              : _offices.firstWhere(
                                      (office) => office['_id']?.toString() == _selectedOfficeId,
                                      orElse: () => {},
                                    )['name'] ??
                                  'Selected office',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _selectedOfficeId == null
                                ? theme.hintColor
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (_formKey.currentState != null &&
                        !_formKey.currentState!.validate() &&
                        _selectedOfficeId == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          'Please select an office',
                          style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: AppTheme.spacingM),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        if (authProvider.isSupervisor() || !authProvider.canCreateRequest()) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: _isLoadingSupervisors || _supervisors.isEmpty
                                  ? null
                                  : _showSupervisorBottomSheet,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Supervisor *',
                                  border: OutlineInputBorder(
                                    borderRadius: AppTheme.bradiusS,
                                  ),
                                  prefixIcon: const Icon(Icons.supervisor_account_rounded),
                                  suffixIcon: _isLoadingSupervisors
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        )
                                      : const Icon(Icons.arrow_drop_down),
                                  helperText: 'Select a supervisor from your department',
                                ),
                                child: Text(
                                  _selectedSupervisorId == null
                                      ? 'Select a supervisor'
                                      : _supervisors.firstWhere(
                                              (supervisor) =>
                                                  supervisor['_id']?.toString() ==
                                                  _selectedSupervisorId,
                                              orElse: () => {},
                                            )['name'] ??
                                            'Selected supervisor',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: _selectedSupervisorId == null
                                        ? theme.hintColor
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            if (_supervisors.isEmpty && !_isLoadingSupervisors)
                              Padding(
                                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                                child: Container(
                                  padding: const EdgeInsets.all(AppTheme.spacingS),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer.withOpacity(0.2),
                                    borderRadius: AppTheme.bradiusS,
                                    border: Border.all(
                                      color: theme.colorScheme.error.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: theme.colorScheme.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Expanded(
                                        child: Text(
                                          'No supervisors found in your department. Please contact your administrator.',
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    GooglePlaceAutoCompleteTextField(
                      textEditingController: _destinationController,
                      googleAPIKey: "AIzaSyD3apWjzMf9iPAdZTSGR4ln2pU7U6Lo7_I",
                      inputDecoration: InputDecoration(
                        labelText: 'Destination *',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.bradiusS,
                        ),
                        prefixIcon: const Icon(Icons.place_rounded),
                        hintText: 'Type or select on map',
                      ),
                      debounceTime: 400,
                      countries: const ["ng"],
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: _handlePlaceSelected,
                      itemClick: (prediction) {
                        _destinationController.text = prediction.description ?? '';
                        _destinationController.selection = TextSelection.fromPosition(
                          TextPosition(offset: prediction.description?.length ?? 0),
                        );
                      },
                      itemBuilder: (context, index, prediction) {
                        return Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(child: Text(prediction.description ?? "")),
                            ],
                          ),
                        );
                      },
                      seperatedBuilder: const Divider(),
                      containerHorizontalPadding: AppTheme.spacingS,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _purposeController,
                      decoration: InputDecoration(
                        labelText: 'Purpose *',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.bradiusS,
                        ),
                        prefixIcon: const Icon(Icons.description_rounded),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the purpose';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _passengerCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Number of Passengers *',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.bradiusS,
                        ),
                        prefixIcon: const Icon(Icons.people_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter passenger count';
                        }
                        if (int.tryParse(value) == null || int.parse(value) < 1) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Card(
                      elevation: AppTheme.elevation1,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.bradiusL,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.calendar_today_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Start Date & Time *'),
                        subtitle: Text(
                          _startDate == null
                              ? 'Not selected'
                              : DateFormat('MMM dd, yyyy HH:mm').format(_startDate!),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () => _selectDate(true),
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusL),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Card(
                      elevation: AppTheme.elevation1,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.bradiusL,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.event_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('End Date & Time *'),
                        subtitle: Text(
                          _endDate == null
                              ? 'Not selected'
                              : DateFormat('MMM dd, yyyy HH:mm').format(_endDate!),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () => _selectDate(false),
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusL),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    FilledButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.requestId != null ? 'Update Request' : 'Submit Request',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
