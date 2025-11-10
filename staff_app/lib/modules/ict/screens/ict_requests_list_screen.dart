import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ict_requests_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/layout/app_page_container.dart';
import '../../../widgets/layout/app_scaffold.dart';
import '../../../widgets/ui/app_card.dart';
import '../../../widgets/ui/app_empty_state.dart';
import 'create_ict_request_screen.dart';

class IctRequestsListScreen extends StatefulWidget {
  const IctRequestsListScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<IctRequestsListScreen> createState() => _IctRequestsListScreenState();
}

class _IctRequestsListScreenState extends State<IctRequestsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<IctRequestsProvider>(context, listen: false).loadRequests();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'submitted':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'fulfilled':
        return Colors.blue;
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
      onTap: () {
        // TODO: Navigate to detail screen when created
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (context) => IctRequestDetailsScreen(requestId: request['_id']),
        // ));
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
          Text(
            request['item'] ?? 'Unknown item',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Row(
            children: [
              Icon(Icons.numbers_rounded, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Quantity: ${request['quantity'] ?? 0}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          if (request['reason'] != null && request['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              request['reason'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (request['createdAt'] != null) ...[
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(request['createdAt'])),
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
        title: const Text('ICT Requests'),
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
                    builder: (context) => const CreateIctRequestScreen(),
                  ),
                ).then((_) {
                  Provider.of<IctRequestsProvider>(context, listen: false).loadRequests();
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Request'),
            )
          : null,
      body: Consumer<IctRequestsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.requests.isEmpty) {
            return AppPageContainer(
              child: AppEmptyState(
                icon: Icons.computer_rounded,
                title: 'No ICT Requests',
                message: canCreate
                    ? 'Create your first ICT request to get started'
                    : 'No ICT requests available',
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

