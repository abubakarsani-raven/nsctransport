import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/request_workflow.dart';
import '../widgets/timeline_widget.dart';

class CorrectionHistoryScreen extends StatelessWidget {
  final List<dynamic> correctionHistory;
  final List<dynamic>? actionHistory;
  final List<dynamic>? approvalChain;

  const CorrectionHistoryScreen({
    super.key,
    required this.correctionHistory,
    this.actionHistory,
    this.approvalChain,
  });

  @override
  Widget build(BuildContext context) {
    final timelineItems = RequestWorkflow.buildCorrectionTimeline(
      correctionHistory: correctionHistory,
      actionHistory: actionHistory,
      approvalChain: approvalChain,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correction Timeline'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingL),
          child: timelineItems.isEmpty
              ? _buildEmptyState(context)
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Track all corrections and resubmissions for this request.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                      TimelineWidget(
                        items: timelineItems,
                        expandable: true,
                        lineWidth: 3,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No correction history yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Corrections will appear here once the request is sent back for updates.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

