import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../providers/store_requests_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/layout/app_page_container.dart';
import '../../../widgets/layout/app_scaffold.dart';
import '../../../widgets/ui/app_card.dart';

class CreateStoreRequestScreen extends StatefulWidget {
  const CreateStoreRequestScreen({super.key, this.requestId, this.onMenuPressed});

  final String? requestId;
  final VoidCallback? onMenuPressed;

  @override
  State<CreateStoreRequestScreen> createState() => _CreateStoreRequestScreenState();
}

class _CreateStoreRequestScreenState extends State<CreateStoreRequestScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  
  String? _selectedSupervisorId;
  List<dynamic> _supervisors = [];
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
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
    _checkAccessAndLoadSupervisors();
    
    if (widget.requestId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _loadRequestData();
        }
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final realtimeProvider = Provider.of<RealtimeProvider>(context, listen: false);
      realtimeProvider.setUsersUpdateCallback(() {
        _loadSupervisors();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadRequestData() async {
    if (widget.requestId == null) return;
    
    try {
      final request = await _apiService.getStoreRequest(widget.requestId!);
      setState(() {
        _itemController.text = request['item'] ?? '';
        _quantityController.text = (request['quantity'] ?? 0).toString();
        _reasonController.text = request['reason'] ?? '';
        _selectedSupervisorId = request['supervisorId']?.toString();
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load request data');
      }
    }
  }

  Future<void> _checkAccessAndLoadSupervisors() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isSupervisor()) {
      await _loadSupervisors();
    }
  }

  Future<void> _loadSupervisors() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final department = user['department'];
    if (department == null) return;

    setState(() {
      _isLoadingSupervisors = true;
    });

    try {
      final supervisors = await _apiService.getSupervisorsByDepartment(department);
      setState(() {
        _supervisors = supervisors;
        _isLoadingSupervisors = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSupervisors = false;
      });
      if (mounted) {
        _showErrorSnackBar('Failed to load supervisors');
      }
    }
  }

  Future<void> _showSupervisorBottomSheet() async {
    if (_supervisors.isEmpty) {
      _showErrorSnackBar('No supervisors available');
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
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Supervisor',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _supervisors.length,
                itemBuilder: (context, index) {
                  final supervisor = _supervisors[index];
                  final supervisorId = supervisor['_id']?.toString();
                  final isSelected = _selectedSupervisorId == supervisorId;
                  
                  return ListTile(
                    leading: Icon(
                      Icons.person_rounded,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(supervisor['name'] ?? 'Unknown'),
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
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedSupervisorId = selected;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isSupervisor() && (_selectedSupervisorId == null || _selectedSupervisorId!.isEmpty)) {
      _showErrorSnackBar('Please select a supervisor');
      return;
    }

    final isEditMode = widget.requestId != null;

    setState(() {
      _isLoading = true;
    });

    final requestData = <String, dynamic>{
      'item': _itemController.text.trim(),
      'quantity': int.parse(_quantityController.text),
      'reason': _reasonController.text.trim(),
    };

    if (!authProvider.isSupervisor() && _selectedSupervisorId != null && _selectedSupervisorId!.isNotEmpty) {
      requestData['supervisorId'] = _selectedSupervisorId;
    }

    try {
      final success = isEditMode
          ? await Provider.of<StoreRequestsProvider>(context, listen: false)
              .updateRequest(widget.requestId!, requestData)
          : await Provider.of<StoreRequestsProvider>(context, listen: false)
              .createRequest(requestData);

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        if (isEditMode) {
          _showSuccessSnackBar('Request updated successfully');
          final request = await _apiService.getStoreRequest(widget.requestId!);
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
                final resubmitSuccess = await Provider.of<StoreRequestsProvider>(context, listen: false)
                    .resubmitRequest(widget.requestId!);
                if (resubmitSuccess && mounted) {
                  _showSuccessSnackBar('Request resubmitted successfully');
                  await Future.delayed(const Duration(milliseconds: 1000));
                  await Provider.of<StoreRequestsProvider>(context, listen: false).loadRequests();
                  Navigator.pop(context);
                }
              } catch (e) {
                _showErrorSnackBar('Failed to resubmit request');
              }
            } else {
              Navigator.pop(context);
            }
          } else {
            Navigator.pop(context);
          }
        } else {
          _showSuccessSnackBar('Store request created successfully');
          await Future.delayed(const Duration(milliseconds: 500));
          await Provider.of<StoreRequestsProvider>(context, listen: false).loadRequests();
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to ${isEditMode ? 'update' : 'create'} request');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isSupervisor = authProvider.isSupervisor();

    return AppScaffold(
      header: AppBar(
        title: Text(widget.requestId == null ? 'Create Store Request' : 'Edit Store Request'),
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
              )
            : null,
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
                    TextFormField(
                      controller: _itemController,
                      decoration: InputDecoration(
                        labelText: 'Item *',
                        hintText: 'e.g., Pens, Notebooks, Printer Paper',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.bradiusS,
                        ),
                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an item';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity *',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.bradiusS,
                        ),
                        prefixIcon: const Icon(Icons.numbers_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter quantity';
                        }
                        final quantity = int.tryParse(value);
                        if (quantity == null || quantity < 1) {
                          return 'Please enter a valid quantity (minimum 1)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    TextFormField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Optional reason for this request',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.bradiusS,
                        ),
                        prefixIcon: const Icon(Icons.description_rounded),
                      ),
                      maxLines: 3,
                    ),
                    if (!isSupervisor) ...[
                      const SizedBox(height: AppTheme.spacingL),
                      InkWell(
                        onTap: _isLoadingSupervisors ? null : _showSupervisorBottomSheet,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Supervisor *',
                            border: OutlineInputBorder(
                              borderRadius: AppTheme.bradiusS,
                            ),
                            prefixIcon: const Icon(Icons.person_rounded),
                            suffixIcon: _isLoadingSupervisors
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : const Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _selectedSupervisorId == null
                                ? 'Select a supervisor'
                                : _supervisors.firstWhere(
                                        (supervisor) => supervisor['_id']?.toString() == _selectedSupervisorId,
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
                    ],
                    const SizedBox(height: AppTheme.spacingXXL),
                    FilledButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.bradiusS,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(widget.requestId == null ? 'Create Request' : 'Update Request'),
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

