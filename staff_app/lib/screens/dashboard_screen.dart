import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animations/animations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/requests_provider.dart';
import '../providers/request_history_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/realtime_provider.dart';
import '../modules/vehicle/providers/vehicle_requests_provider.dart';
import '../modules/ict/providers/ict_requests_provider.dart';
import '../modules/store/providers/store_requests_provider.dart';
import 'create_request_screen.dart';
import 'request_details_screen.dart';
import 'notifications_screen.dart';
import '../modules/ict/screens/create_ict_request_screen.dart';
import '../modules/store/screens/create_store_request_screen.dart';
import '../theme/app_theme.dart';
import '../utils/toast_helper.dart';
import '../utils/request_workflow.dart';
import '../widgets/layout/app_page_container.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/app_empty_state.dart';
import '../widgets/ui/app_section_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _SummaryTileData {
  const _SummaryTileData({
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
    this.filterKey,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? tint;
  final String? filterKey; // For filtering: 'my_requests', 'pending', 'vehicle', 'ict', 'store'
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _currentTab = 0;
  String? _activeFilter; // null = all, 'my_requests', 'pending', 'vehicle', 'ict', 'store'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RequestsProvider>(context, listen: false).loadRequests();
      Provider.of<VehicleRequestsProvider>(context, listen: false).loadRequests();
      Provider.of<IctRequestsProvider>(context, listen: false).loadRequests();
      Provider.of<StoreRequestsProvider>(context, listen: false).loadRequests();
      Provider.of<RequestHistoryProvider>(context, listen: false).loadHistory();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final canApprove = authProvider.canApproveRequests();
      final canCreate = authProvider.canCreateRequest();
      final tabCount = (canCreate ? 1 : 0) + (canApprove ? 1 : 0);
      if (tabCount > 0) {
        _tabController = TabController(length: tabCount, vsync: this);
        _tabController!.addListener(() {
          setState(() {
            _currentTab = _tabController!.index;
          });
        });
        setState(() {});
      }
      
      // Setup real-time updates
      final realtimeProvider = Provider.of<RealtimeProvider>(context, listen: false);
      final requestsProvider = Provider.of<RequestsProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleRequestsProvider>(context, listen: false);
      final ictProvider = Provider.of<IctRequestsProvider>(context, listen: false);
      final storeProvider = Provider.of<StoreRequestsProvider>(context, listen: false);
      
      realtimeProvider.setRequestsUpdateCallback(() {
        requestsProvider.loadRequests();
        vehicleProvider.loadRequests();
        ictProvider.loadRequests();
        storeProvider.loadRequests();
        ToastHelper.showInfoToast('Requests updated');
      });
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<dynamic> _getMyRequests(List<dynamic> allRequests) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?['id'] ?? authProvider.user?['_id'];
    if (userId == null) {
      return [];
    }
    // Show ONLY requests created by this user (not requests assigned to them as supervisor)
    return allRequests.where((r) {
      final requesterId = r['requesterId'];
      if (requesterId == null) return false;
      
      // Handle both populated (object) and non-populated (string ID) cases
      String? reqIdStr;
      if (requesterId is Map) {
        reqIdStr = (requesterId['_id'] ?? requesterId['id'])?.toString();
      } else {
        reqIdStr = requesterId.toString();
      }
      
      return reqIdStr == userId.toString();
    }).toList();
  }

  List<dynamic> _getPendingApprovalRequests(List<dynamic> allRequests) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?['id'] ?? authProvider.user?['_id'];
    final userRoles = authProvider.getRoles();
    
    debugPrint('[DEBUG PENDING] Total requests: ${allRequests.length}');
    debugPrint('[DEBUG PENDING] User roles: $userRoles');
    debugPrint('[DEBUG PENDING] User ID: $userId');
    
    return allRequests.where((r) {
      final status = r['status'] ?? '';
      final currentStage = r['currentStage'] ?? '';
      final reqId = r['requesterId'];
      final requestId = r['_id']?.toString() ?? 'unknown';
      
      debugPrint('[DEBUG PENDING] Checking request $requestId: currentStage=$currentStage, status=$status');
      
      // Don't show own requests
      String? reqIdStr;
      if (reqId != null) {
        if (reqId is Map) {
          reqIdStr = (reqId['_id'] ?? reqId['id'])?.toString();
        } else {
          reqIdStr = reqId.toString();
        }
      }
      
      // Exclude own requests
      if (reqIdStr == userId?.toString()) {
        debugPrint('[DEBUG PENDING] Request $requestId excluded: own request (requesterId=$reqIdStr, userId=$userId)');
        return false;
      }
      
      // Only show requests that can actually be approved (status must be pending, not needs_correction)
      if (status == 'needs_correction') {
        debugPrint('[DEBUG PENDING] Request $requestId excluded: needs_correction');
        return false;
      }
      
      final canApprove = _canApproveRequest(r);
      debugPrint('[DEBUG PENDING] Request $requestId canApprove: $canApprove (currentStage=$currentStage, status=$status)');
      if (!canApprove && (currentStage.toString().contains('ddgs') || status.toString().contains('dgs_approved'))) {
        debugPrint('[DEBUG PENDING] Request $requestId at DDGS stage but canApprove=false. Check role: hasRole(ddgs)=${authProvider.hasRole('ddgs')}');
      }
      
      return canApprove;
    }).toList();
  }

  Widget _buildDashboardHeader(BuildContext context, AuthProvider authProvider) {
     final roles = authProvider.getRoles();
    final subtitleWidget = roles.isNotEmpty
        ? Wrap(
            spacing: AppTheme.spacingS,
            runSpacing: AppTheme.spacingXS,
            children: roles
                .map(
                  (role) => Chip(
                    label: Text(role.replaceAll('_', ' ').toUpperCase()),
                    backgroundColor: _roleColor(role).withOpacity(0.14),
                    labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _roleColor(role),
                        ),
                    side: BorderSide(color: _roleColor(role).withOpacity(0.3)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXS,
                      vertical: AppTheme.spacingXS / 2,
                    ),
                  ),
                )
                .toList(),
          )
        : null;
 
    return AppSectionHeader(
      showMenuButton: true,
      onMenuPressed: widget.onMenuPressed,
      title: 'Dashboard',
      subtitle: subtitleWidget == null
          ? 'Track, approve, and monitor all requests'
          : null,
      subtitleWidget: subtitleWidget,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<RealtimeProvider>(
            builder: (context, realtimeProvider, _) {
              final connected = realtimeProvider.isConnected;
              return Tooltip(
                message: connected ? 'Real-time connected' : 'Reconnect to real-time updates',
                child: IconButton(
                  onPressed: connected
                      ? null
                      : () {
                          realtimeProvider.connect();
                          ToastHelper.showInfoToast('Attempting to reconnect...');
                        },
                  icon: Icon(
                    connected ? Icons.podcasts_rounded : Icons.cloud_off_rounded,
                    color: connected ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const NotificationsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SharedAxisTransition(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      transitionType: SharedAxisTransitionType.horizontal,
                      child: child,
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
    );
  }

  bool _canApproveRequest(Map<String, dynamic> request) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Get current stage (use currentStage if available, otherwise map from status)
    final currentStage = (request['currentStage'] ?? request['status'] ?? '').toString().toLowerCase().trim();
    final userId = authProvider.user?['id'] ?? authProvider.user?['_id'];
    final requestType = request['requestType'] ?? 'vehicle';
    
    // Handle supervisor approval for all request types
    if (authProvider.isSupervisor()) {
      final supervisorId = request['supervisorId'];
      if (supervisorId != null) {
        final supervisorIdStr = supervisorId is Map
            ? (supervisorId['_id'] ?? supervisorId['id'])?.toString()
            : supervisorId?.toString();
        if (supervisorIdStr == userId?.toString()) {
          // Supervisor can approve at submitted or supervisor_review stages
          // Use exact match first, then fallback to contains for backward compatibility
          if (currentStage == 'submitted' || 
              currentStage == 'supervisor_review' ||
              currentStage.contains('submitted') || 
              currentStage.contains('supervisor_review')) {
            return true;
          }
        }
      }
    }
    
    // Handle request type-specific stages
    switch (requestType) {
      case 'ict':
        // ICT Officer can approve at ict_officer_review stage
        // Use exact match to avoid substring matching issues
        if (currentStage == 'ict_officer_review' || currentStage.contains('ict_officer_review')) {
          return authProvider.hasRole('ict_officer');
        }
        // Already handled supervisor stages above
        return false;
      case 'store':
        // Store Officer can approve at store_officer_review stage
        // Use exact match to avoid substring matching issues
        if (currentStage == 'store_officer_review' || currentStage.contains('store_officer_review')) {
          return authProvider.hasRole('store_officer');
        }
        // Already handled supervisor stages above
        return false;
      case 'vehicle':
      default:
        // Vehicle request stages - Use exact match first, check in order from most specific to least specific
        // IMPORTANT: Always check DDGS before DGS since "ddgs_review".contains("dgs_review") = true
        
        // 1. DDGS Review (must check before DGS due to substring match)
        if (currentStage == 'ddgs_review') {
          final hasRole = authProvider.hasRole('ddgs');
          debugPrint('[DEBUG CAN APPROVE] DDGS check: currentStage=$currentStage, hasRole(ddgs)=$hasRole');
          return hasRole;
        }
        
        // 2. DGS Review
        if (currentStage == 'dgs_review') {
          final hasRole = authProvider.hasRole('dgs');
          debugPrint('[DEBUG CAN APPROVE] DGS check: currentStage=$currentStage, hasRole(dgs)=$hasRole');
          return hasRole;
        }
        
        // 3. AD Transport Review
        if (currentStage == 'ad_transport_review') {
          return authProvider.hasRole('ad_transport');
        }
        
        // 4. Transport Officer Assignment
        if (currentStage == 'transport_officer_assignment') {
          return authProvider.hasRole('transport_officer') || authProvider.hasRole('dgs');
        }
        
        // 5. Submitted/Supervisor Review - DGS can also approve (if not supervisor)
        if ((currentStage == 'submitted' || currentStage == 'supervisor_review') &&
            !authProvider.isSupervisor()) {
          return authProvider.hasRole('dgs');
        }
        
        // Fallback: backward compatibility for legacy data (contains check)
        // But only if exact match didn't work
        if (currentStage.contains('ddgs_review') && currentStage != 'ddgs_review') {
          final hasRole = authProvider.hasRole('ddgs');
          debugPrint('[DEBUG CAN APPROVE] DDGS fallback check: currentStage=$currentStage, hasRole(ddgs)=$hasRole');
          return hasRole;
        }
        if (currentStage.contains('dgs_review') && 
            !currentStage.contains('ddgs_review') && 
            currentStage != 'dgs_review') {
          final hasRole = authProvider.hasRole('dgs');
          debugPrint('[DEBUG CAN APPROVE] DGS fallback check: currentStage=$currentStage, hasRole(dgs)=$hasRole');
          return hasRole;
        }
        
        return false;
    }
  }

  Color _getStatusColor(String status) {
    return AppTheme.getStatusColor(status);
  }

  String _formatStatus(String status) {
    return RequestWorkflow.formatStatus(status);
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'transport_officer':
        return AppTheme.primaryColor;
      case 'ad_transport':
        return AppTheme.secondaryColor;
      case 'dgs':
        return AppTheme.tertiaryColor;
      case 'ddgs':
        return AppTheme.warningColor;
      case 'staff':
        return AppTheme.neutral60;
      case 'supervisor':
        return AppTheme.infoColor;
      default:
        return AppTheme.primaryColorLight;
    }
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingS),
      itemBuilder: (context, index) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final baseColor = Color.lerp(
              colorScheme.surfaceVariant,
              colorScheme.surface,
              0.25,
            ) ??
            colorScheme.surface;
        final highlightColor = Color.lerp(
              colorScheme.surface,
              colorScheme.surfaceTint,
              theme.brightness == Brightness.dark ? 0.05 : 0.2,
            ) ??
            colorScheme.surface;

        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: AppCard(
            borderColor: Colors.transparent,
            child: SizedBox(
              height: 118,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 160,
                    height: 16,
                    color: theme.colorScheme.surface,
                  ),
                  Container(
                    width: double.infinity,
                    height: 12,
                    color: theme.colorScheme.surface,
                  ),
                  Row(
                    children: [
                      Container(width: 80, height: 12, color: theme.colorScheme.surface),
                      const SizedBox(width: AppTheme.spacingS),
                      Container(width: 120, height: 12, color: theme.colorScheme.surface),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool canCreate, required bool isPendingTab}) {
    return AppEmptyState(
      icon: isPendingTab ? Icons.verified_outlined : Icons.inbox_outlined,
      title: isPendingTab ? 'No pending approvals' : 'No requests yet',
      message: isPendingTab
          ? 'All transport requests are up to date.'
          : 'Start a new vehicle request to kick off the workflow.',
      action: canCreate && !isPendingTab
          ? FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateRequestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Request'),
            )
          : null,
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isPendingApproval) {
    final status = request['status'] ?? request['currentStage'] ?? '';
    final statusColor = _getStatusColor(status);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final requestType = request['requestType'] ?? 'vehicle';
    final estimatedDistance = request['estimatedDistance'];
    final estimatedFuelLitres = request['estimatedFuelLitres'];
    
    // Determine title, icon, and color label based on request type
    String title;
    IconData typeIcon;
    Color typeColor;
    String typeLabel;
    switch (requestType) {
      case 'ict':
        title = request['item'] ?? 'ICT Request';
        typeIcon = Icons.computer_rounded;
        typeColor = Colors.blue;
        typeLabel = 'ICT';
        break;
      case 'store':
        title = request['item'] ?? 'Store Request';
        typeIcon = Icons.inventory_2_rounded;
        typeColor = Colors.green;
        typeLabel = 'Store';
        break;
      default:
        title = request['destination'] ?? 'Unknown destination';
        typeIcon = Icons.directions_car_rounded;
        typeColor = AppTheme.primaryColor;
        typeLabel = 'Transport';
    }

    Widget cardContent = AppCard(
      onTap: () async {
        // For now, only vehicle requests have detail screens
        // TODO: Add detail screens for ICT and Store requests
        if (requestType == 'vehicle' || requestType == null) {
          final result = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => RequestDetailsScreen(
                requestId: request['_id'],
                canApprove: isPendingApproval && _canApproveRequest(request),
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SharedAxisTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  transitionType: SharedAxisTransitionType.horizontal,
                  child: child,
                );
              },
            ),
          );
          if (result == true && mounted) {
            Provider.of<RequestsProvider>(context, listen: false).loadRequests();
            Provider.of<VehicleRequestsProvider>(context, listen: false).loadRequests();
            Provider.of<IctRequestsProvider>(context, listen: false).loadRequests();
            Provider.of<StoreRequestsProvider>(context, listen: false).loadRequests();
          }
        }
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      borderColor: Theme.of(context).colorScheme.outline.withOpacity(0.04),
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Request type color label - smooth chip style
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: typeColor.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 14, color: typeColor),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      typeLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Status badge - smooth chip style
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  _formatStatus(status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Icon(typeIcon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          if (requestType == 'vehicle' || requestType == null)
            Text(
              request['purpose'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            )
          else if (requestType == 'ict' || requestType == 'store')
            Row(
              children: [
                Icon(Icons.numbers_rounded, size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'Quantity: ${request['quantity'] ?? 0}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: AppTheme.spacingS),
              if (requestType == 'vehicle' && request['startDate'] != null)
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(request['startDate'])),
                  style: theme.textTheme.bodySmall,
                )
              else if (request['createdAt'] != null)
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(request['createdAt'])),
                  style: theme.textTheme.bodySmall,
                ),
              if (isPendingApproval && request['requesterId'] != null) ...[
                const SizedBox(width: AppTheme.spacingL),
                Icon(Icons.person_outline_rounded,
                    size: 16, color: palette.textSecondary),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    request['requesterId']?['name'] ?? 'Unknown',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (requestType == 'vehicle' &&
              ((estimatedDistance is num && estimatedDistance > 0) ||
                  (estimatedFuelLitres is num && estimatedFuelLitres > 0)))
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingS),
              child: Row(
                children: [
                  if (estimatedDistance is num && estimatedDistance > 0) ...[
                    Icon(
                      Icons.straighten_rounded,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      '${estimatedDistance.toStringAsFixed(1)} km',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (estimatedFuelLitres is num && estimatedFuelLitres > 0) ...[
                    if (estimatedDistance is num && estimatedDistance > 0)
                      const SizedBox(width: AppTheme.spacingL),
                    Icon(
                      Icons.local_gas_station_rounded,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      '${estimatedFuelLitres.toStringAsFixed(2)} L',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    if (isPendingApproval && _canApproveRequest(request)) {
      cardContent = Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (context) async {
                if (requestType == 'vehicle' || requestType == null) {
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          RequestDetailsScreen(
                        requestId: request['_id'],
                        canApprove: true,
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return SharedAxisTransition(
                          animation: animation,
                          secondaryAnimation: secondaryAnimation,
                          transitionType: SharedAxisTransitionType.horizontal,
                          child: child,
                        );
                      },
                    ),
                  );
                  if (result == true && mounted) {
                    Provider.of<RequestsProvider>(context, listen: false).loadRequests();
                    Provider.of<VehicleRequestsProvider>(context, listen: false).loadRequests();
                    Provider.of<IctRequestsProvider>(context, listen: false).loadRequests();
                    Provider.of<StoreRequestsProvider>(context, listen: false).loadRequests();
                  }
                }
              },
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: Icons.task_alt_rounded,
              label: 'Review',
            ),
          ],
        ),
        child: cardContent,
      );
    }

    return cardContent;
  }

  List<dynamic> _getAllRequests() {
    final vehicleProvider = Provider.of<VehicleRequestsProvider>(context, listen: false);
    final ictProvider = Provider.of<IctRequestsProvider>(context, listen: false);
    final storeProvider = Provider.of<StoreRequestsProvider>(context, listen: false);
    final requestsProvider = Provider.of<RequestsProvider>(context, listen: false);
    
    // Combine all request types
    final allRequests = <dynamic>[];
    allRequests.addAll(vehicleProvider.requests);
    allRequests.addAll(ictProvider.requests);
    allRequests.addAll(storeProvider.requests);
    // Also include legacy requests for backward compatibility
    allRequests.addAll(requestsProvider.requests.where((r) {
      // Only add if not already in vehicle requests (avoid duplicates)
      final requestId = r['_id']?.toString();
      return !vehicleProvider.requests.any((vr) => vr['_id']?.toString() == requestId);
    }));
    
    debugPrint('[DEBUG ALL REQUESTS] Vehicle: ${vehicleProvider.requests.length}, ICT: ${ictProvider.requests.length}, Store: ${storeProvider.requests.length}, Legacy: ${requestsProvider.requests.length}');
    debugPrint('[DEBUG ALL REQUESTS] Total combined: ${allRequests.length}');
    
    // Log requests with ddgs_review stage
    for (final req in allRequests) {
      final currentStage = req['currentStage']?.toString() ?? '';
      final status = req['status']?.toString() ?? '';
      if (currentStage.contains('ddgs') || status.contains('dgs_approved')) {
        debugPrint('[DEBUG ALL REQUESTS] Found DDGS request: _id=${req['_id']}, currentStage=$currentStage, status=$status, requestType=${req['requestType']}');
      }
    }
    
    return allRequests;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<AuthProvider, VehicleRequestsProvider, IctRequestsProvider, StoreRequestsProvider>(
      builder: (context, authProvider, vehicleProvider, ictProvider, storeProvider, _) {
        final canApprove = authProvider.canApproveRequests();
        final canCreate = authProvider.canCreateRequest();
        
        // Combine all requests
        final allRequests = _getAllRequests();
        final isLoading = context.watch<RequestsProvider>().isLoading || 
                         vehicleProvider.isLoading || 
                         ictProvider.isLoading || 
                         storeProvider.isLoading;

        return AppScaffold(
          backgroundGradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface,
            ],
          ),
          header: _buildDashboardHeader(context, authProvider),
          floatingActionButton: canCreate && (!canApprove || _currentTab == 0)
              ? _buildFloatingActionButton(context, canCreate)
              : null,
          body: AppPageContainer(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spacingL,
              AppTheme.spacingS,
              AppTheme.spacingL,
              AppTheme.spacingL,
            ),
            child: Column(
              children: [
                if (_tabController != null && (canApprove || canCreate))
                  AppCard(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    borderColor: Theme.of(context).colorScheme.outline.withOpacity(0.12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    child: TabBar(
                      controller: _tabController!,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppPalette.of(context).textSecondary,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(.18),
                        borderRadius: AppTheme.bradiusS,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                      tabs: [
                        if (canCreate)
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.list_rounded, size: 18),
                                SizedBox(width: AppTheme.spacingXS),
                                Text('My Requests'),
                              ],
                            ),
                          ),
                        if (canApprove)
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.pending_actions_rounded, size: 18),
                                SizedBox(width: AppTheme.spacingXS),
                                Text('Pending Approval'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppTheme.spacingM),
                isLoading
                    ? _buildSummaryLoading()
                    : _buildSummaryStrip(context, allRequests, canApprove, canCreate),
                Expanded(
                  child: isLoading
                      ? _buildShimmerLoading()
                      : _buildRequestsList(
                          context,
                          allRequests,
                          canCreate: canCreate,
                          canApprove: canApprove,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, bool canCreate) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -100),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusM),
      child: FloatingActionButton.extended(
        onPressed: null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Request'),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'vehicle',
          child: Row(
            children: [
              Icon(Icons.directions_car_rounded, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text('Vehicle Request'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ict',
          child: Row(
            children: [
              Icon(Icons.computer_rounded, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text('ICT Request'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'store',
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text('Store Request'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'vehicle':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateRequestScreen(),
              ),
            );
            break;
          case 'ict':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateIctRequestScreen(),
              ),
            );
            break;
          case 'store':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateStoreRequestScreen(),
              ),
            );
            break;
        }
      },
    );
  }

  Widget _buildSummaryStrip(
    BuildContext context,
    List<dynamic> allRequests,
    bool canApprove,
    bool canCreate,
  ) {
    final theme = Theme.of(context);
    final myRequests = _getMyRequests(allRequests);
    final pendingRequests = _getPendingApprovalRequests(allRequests);
    
    // Count by request type
    final vehicleCount = allRequests.where((r) => 
      r['requestType'] == 'vehicle' || r['requestType'] == null
    ).length;
    final ictCount = allRequests.where((r) => 
      r['requestType'] == 'ict'
    ).length;
    final storeCount = allRequests.where((r) => 
      r['requestType'] == 'store'
    ).length;

    final summaryItems = [
      if (canCreate)
        _SummaryTileData(
          label: 'My Requests',
          value: myRequests.length,
          icon: Icons.badge_rounded,
          tint: AppTheme.primaryColor,
          filterKey: 'my_requests',
        ),
      if (canApprove)
        _SummaryTileData(
          label: 'Pending Approval',
          value: pendingRequests.length,
          icon: Icons.pending_actions_rounded,
          tint: AppTheme.secondaryColor,
          filterKey: 'pending',
        ),
      _SummaryTileData(
        label: 'Vehicle',
        value: vehicleCount,
        icon: Icons.directions_car_rounded,
        tint: AppTheme.primaryColor,
        filterKey: 'vehicle',
      ),
      _SummaryTileData(
        label: 'ICT',
        value: ictCount,
        icon: Icons.computer_rounded,
        tint: Colors.blue,
        filterKey: 'ict',
      ),
      _SummaryTileData(
        label: 'Store',
        value: storeCount,
        icon: Icons.inventory_2_rounded,
        tint: Colors.green,
        filterKey: 'store',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        children: summaryItems
            .map(
              (item) {
                final isActive = _activeFilter == item.filterKey;
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacingS),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_activeFilter == item.filterKey) {
                            _activeFilter = null; // Toggle off if already active
                          } else {
                            _activeFilter = item.filterKey; // Set new filter
                          }
                        });
                      },
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
                              ? (item.tint ?? AppTheme.primaryColor).withOpacity(0.15)
                              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? (item.tint ?? AppTheme.primaryColor).withOpacity(0.5)
                                : Theme.of(context).colorScheme.outline.withOpacity(0.15),
                            width: isActive ? 2 : 1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: (item.tint ?? AppTheme.primaryColor).withOpacity(0.15),
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
                              item.icon,
                              color: isActive
                                  ? (item.tint ?? AppTheme.primaryColor)
                                  : item.tint ?? AppTheme.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Text(
                              item.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 12,
                                color: isActive
                                    ? (item.tint ?? AppTheme.primaryColor)
                                    : AppPalette.of(context).textSecondary,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (item.tint ?? AppTheme.primaryColor).withOpacity(0.2)
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.value.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: isActive
                                      ? (item.tint ?? AppTheme.primaryColor)
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: AppTheme.spacingXS),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: item.tint ?? AppTheme.primaryColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
            .toList(),
      ),
    );
  }

  Widget _buildSummaryLoading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final count = maxWidth >= 720 ? 3 : maxWidth >= 480 ? 2 : 1;
        final tileWidth = count == 1
            ? maxWidth
            : (maxWidth - AppTheme.spacingM * (count - 1)) / count;
        return Wrap(
          spacing: AppTheme.spacingM,
          runSpacing: AppTheme.spacingM,
          children: List.generate(
            count,
            (_) => ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: tileWidth,
                minWidth: tileWidth,
              ),
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: AppTheme.bradiusL,
                  border: Border.all(color: AppTheme.neutral20),
                  color: AppTheme.neutral0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    List<dynamic> allRequests, {
    required bool canCreate,
    required bool canApprove,
  }) {
    final myRequests = _getMyRequests(allRequests);
    final pendingRequests = _getPendingApprovalRequests(allRequests);

    List<dynamic> displayRequests;
    bool isPendingTab = false;

    if (!canCreate && canApprove) {
      displayRequests = pendingRequests;
      isPendingTab = true;
    } else if (canCreate && !canApprove) {
      displayRequests = myRequests;
    } else if (canCreate && canApprove) {
      isPendingTab = _currentTab == 1;
      displayRequests = _currentTab == 0 ? myRequests : pendingRequests;
    } else {
      displayRequests = [];
    }

    // Apply filter if active
    if (_activeFilter != null) {
      displayRequests = displayRequests.where((request) {
        final requestType = request['requestType'];
        switch (_activeFilter) {
          case 'my_requests':
            // Already filtered by myRequests, so include all
            return true;
          case 'pending':
            // Already filtered by pendingRequests, so include all
            return true;
          case 'vehicle':
            // Vehicle requests have requestType == 'vehicle' or null (legacy requests)
            return requestType == 'vehicle' || requestType == null;
          case 'ict':
            return requestType == 'ict';
          case 'store':
            return requestType == 'store';
          default:
            return true;
        }
      }).toList();
    }

    if (displayRequests.isEmpty) {
      return _buildEmptyState(canCreate: canCreate, isPendingTab: isPendingTab);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Provider.of<RequestsProvider>(context, listen: false).loadRequests();
        await Provider.of<VehicleRequestsProvider>(context, listen: false).loadRequests();
        await Provider.of<IctRequestsProvider>(context, listen: false).loadRequests();
        await Provider.of<StoreRequestsProvider>(context, listen: false).loadRequests();
      },
      color: AppTheme.primaryColor,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: displayRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingS),
        itemBuilder: (context, index) {
          return _buildRequestCard(displayRequests[index], isPendingTab);
        },
      ),
    );
  }

  // Recent activity moved to its own screen.

  // _buildHistoryLoading removed (moved to recent activity screen)

  // _buildHistoryItem removed (moved to recent activity screen)

  // _buildHistoryBadge removed (moved to recent activity screen)

  // _formatHistoryLabel removed (moved to recent activity screen)

  // _formatHistoryTimestamp removed (moved to recent activity screen)
}
