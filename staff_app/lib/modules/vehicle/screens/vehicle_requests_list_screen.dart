import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/vehicle_requests_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/layout/app_page_container.dart';
import '../../../widgets/layout/app_scaffold.dart';
import '../../../widgets/ui/app_card.dart';
import '../../../widgets/ui/app_empty_state.dart';
import '../../../screens/create_request_screen.dart';
import '../../../screens/request_details_screen.dart';
import 'package:animations/animations.dart';

class VehicleRequestsListScreen extends StatefulWidget {
  const VehicleRequestsListScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<VehicleRequestsListScreen> createState() => _VehicleRequestsListScreenState();
}

class _VehicleRequestsListScreenState extends State<VehicleRequestsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<VehicleRequestsProvider>(context, listen: false).loadRequests();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'submitted':
        return Colors.orange;
      case 'approved':
      case 'ad_transport_approved':
        return Colors.green;
      case 'transport_officer_assigned':
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'needs_correction':
        return Colors.amber;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? request['currentStage'] ?? '';
    final statusColor = _getStatusColor(status);
    final theme = Theme.of(context);

    return AppCard(
      onTap: () async {
        final result = await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => RequestDetailsScreen(
              requestId: request['_id'],
              canApprove: false, // Will be determined by the details screen
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
          Provider.of<VehicleRequestsProvider>(context, listen: false).loadRequests();
        }
      },
      backgroundColor: theme.colorScheme.surface,
      borderColor: theme.colorScheme.outline.withOpacity(0.04),
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.12),
              borderRadius: AppTheme.bradiusS,
            ),
            child: Text(
              _formatStatus(status),
              style: theme.textTheme.labelLarge?.copyWith(color: statusColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Icon(Icons.directions_car_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(
                child: Text(
                  request['destination'] ?? 'Unknown destination',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            request['purpose'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          if (request['startDate'] != null) ...[
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(request['startDate'])),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canCreate = authProvider.canCreateRequest();

    return AppScaffold(
      backgroundGradient: LinearGradient(
        colors: [
          Theme.of(context).scaffoldBackgroundColor,
          Theme.of(context).scaffoldBackgroundColor,
        ],
      ),
      header: AppBar(
        title: const Text('Transport Requests'),
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
              )
            : null,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateRequestScreen(),
                  ),
                ).then((_) {
                  Provider.of<VehicleRequestsProvider>(context, listen: false).loadRequests();
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Request'),
            )
          : null,
      body: Consumer<VehicleRequestsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.requests.isEmpty) {
            return AppPageContainer(
              child: AppEmptyState(
                icon: Icons.directions_car_rounded,
                title: 'No Transport Requests',
                message: canCreate
                    ? 'Create your first transport request to get started'
                    : 'No transport requests available',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadRequests(),
            color: AppTheme.primaryColor,
            child: AppPageContainer(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingXXL),
                itemCount: provider.requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingS),
                itemBuilder: (context, index) {
                  return _buildRequestCard(provider.requests[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

