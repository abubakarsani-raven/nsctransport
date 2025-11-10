import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/timeline_widget.dart';
import '../theme/app_theme.dart';

/// Complete workflow sequence for vehicle requests
class RequestWorkflow {
  /// Ordered list of all workflow steps (using workflow stages)
  /// Note: 'submitted' is not shown as a separate stage - requests go directly to supervisor_review or dgs_review
  static const List<WorkflowStep> workflowSteps = [
    WorkflowStep(
      status: 'supervisor_review',
      title: 'Supervisor Review',
      description: 'Request is being reviewed by supervisor',
      role: 'supervisor',
    ),
    WorkflowStep(
      status: 'dgs_review',
      title: 'DGS Review',
      description: 'Request is being reviewed by Deputy General Secretary',
      role: 'dgs',
    ),
    WorkflowStep(
      status: 'ddgs_review',
      title: 'DDGS Review',
      description: 'Request is being reviewed by Deputy Director General Secretary',
      role: 'ddgs',
    ),
    WorkflowStep(
      status: 'ad_transport_review',
      title: 'AD Transport Review',
      description: 'Request is being reviewed by Assistant Director Transport',
      role: 'ad_transport',
    ),
    WorkflowStep(
      status: 'transport_officer_assignment',
      title: 'Transport Officer Assignment',
      description: 'Driver and vehicle are being assigned',
      role: 'transport_officer',
    ),
    WorkflowStep(
      status: 'assigned',
      title: 'Trip Ready',
      description: 'Driver and vehicle have been assigned',
      role: 'driver',
    ),
    WorkflowStep(
      status: 'in_progress',
      title: 'Trip In Progress',
      description: 'Trip is currently ongoing',
      role: 'driver',
    ),
    WorkflowStep(
      status: 'completed',
      title: 'Completed',
      description: 'Trip has been completed',
      role: 'driver',
    ),
    WorkflowStep(
      status: 'returned',
      title: 'Returned',
      description: 'Vehicle has been returned',
      role: 'driver',
    ),
  ];
  
  /// Map old status to new workflow stage (for backward compatibility)
  static String mapStatusToStage(String status) {
    final statusMap = {
      'pending': 'supervisor_review', // Pending means waiting for supervisor review
      'submitted': 'supervisor_review', // Submitted also means supervisor review
      'supervisor_approved': 'dgs_review', // Supervisor approved means now at DGS review
      'dgs_approved': 'ddgs_review', // DGS approved means now at DDGS review
      'ddgs_approved': 'ad_transport_review', // DDGS approved means now at AD Transport review
      'ad_transport_approved': 'transport_officer_assignment', // AD Transport approved means now at TO assignment
      'transport_officer_assigned': 'assigned',
      'driver_accepted': 'assigned',
      'in_progress': 'in_progress',
      'completed': 'completed',
      'returned': 'returned',
      'rejected': 'rejected',
      'needs_correction': 'needs_correction',
      'cancelled': 'cancelled',
    };
    return statusMap[status.toLowerCase()] ?? status.toLowerCase();
  }
  
  /// Get current stage from request (supports both old status and new currentStage)
  static String getCurrentStage(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase().trim() ?? '';
    final currentStage = request['currentStage']?.toString().toLowerCase().trim() ?? '';
    
    // Prefer currentStage if available and valid
    if (currentStage.isNotEmpty && currentStage != 'submitted') {
      // Debug logging
      debugPrint('[RequestWorkflow] getCurrentStage: Using currentStage=$currentStage, status=$status');
      return currentStage;
    }
    
    // Fallback to status and map it
    if (status.isNotEmpty) {
      final mappedStage = mapStatusToStage(status);
      debugPrint('[RequestWorkflow] getCurrentStage: Mapping status=$status to stage=$mappedStage');
      return mappedStage;
    }
    
    // Default to supervisor_review for new requests
    debugPrint('[RequestWorkflow] getCurrentStage: Using default supervisor_review');
    return 'supervisor_review';
  }

  /// Get the index of a status/stage in the workflow
  static int getStatusIndex(String status) {
    // Normalize status to stage
    final stage = mapStatusToStage(status);
    final index = workflowSteps.indexWhere((step) => step.status == stage.toLowerCase());
    // If status not found, return -1
    return index;
  }

  /// Get workflow step by status/stage
  static WorkflowStep? getStepByStatus(String status) {
    try {
      // Normalize status to stage
      final stage = mapStatusToStage(status);
      return workflowSteps.firstWhere(
        (step) => step.status == stage.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Check if a stage supports cancellation
  static bool canCancelAtStage(String stage) {
    final cancellableStages = [
      'submitted', // For backward compatibility
      'supervisor_review',
      'dgs_review',
      'ddgs_review',
      'ad_transport_review',
    ];
    return cancellableStages.contains(stage.toLowerCase());
  }

  /// Build timeline items for the complete workflow
  static List<TimelineItem> buildWorkflowTimeline({
    required String currentStatus,
    String? currentStage, // Prefer currentStage if provided
    required List<dynamic> approvalChain,
    List<dynamic>? actionHistory,
    List<dynamic>? correctionHistory,
    String? rejectionReason,
    DateTime? rejectedAt,
    String? rejectedBy,
    DateTime? resubmittedAt,
    DateTime? createdAt,
    String? correctionNote,
    DateTime? correctedAt,
    String? correctedBy,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? cancelledBy,
  }) {
    // Use actionHistory if available, otherwise fallback to approvalChain
    final history = actionHistory ?? approvalChain;
    
    // Determine actual current stage
    // If status indicates we've progressed (e.g., "supervisor_approved" means we're at "dgs_review"),
    // use that mapping instead of trusting currentStage field (which might be stale)
    String actualCurrentStage;
    final statusMappedStage = mapStatusToStage(currentStatus).toLowerCase().trim();
    
    if (currentStage != null && currentStage.trim().isNotEmpty) {
      final currentStageLower = currentStage.toLowerCase().trim();
      // If status mapping indicates a later stage than currentStage, trust the status
      // This handles cases where currentStage might not be updated yet
      final statusIndex = getStatusIndex(statusMappedStage);
      final currentStageIndex = getStatusIndex(currentStageLower);
      
      if (statusIndex >= 0 && currentStageIndex >= 0 && statusIndex > currentStageIndex) {
        // Status indicates we've progressed further, use status mapping
        actualCurrentStage = statusMappedStage;
        debugPrint('[RequestWorkflow] Status indicates progression: using $statusMappedStage (from status) instead of $currentStageLower (from currentStage)');
      } else {
        // Use currentStage as-is
        actualCurrentStage = currentStageLower;
      }
    } else {
      // No currentStage provided, map from status
      actualCurrentStage = statusMappedStage;
    }
    
    final currentStatusLower = actualCurrentStage;
    final isRejected = currentStatusLower == 'rejected' || currentStatusLower.contains('rejected');
    final needsCorrection = currentStatusLower == 'needs_correction' || currentStatusLower.contains('needs_correction');
    final isCancelled = currentStatusLower == 'cancelled' || currentStatusLower.contains('cancelled');
    
    // Debug logging
    debugPrint('[RequestWorkflow] Building timeline - currentStage: $currentStage, currentStatus: $currentStatus, actualCurrentStage: $actualCurrentStage');
    
    // Find rejection point in history
    Map<String, dynamic>? rejectionEntry;
    String? rejectionStepStatus;
    if (isRejected || rejectionReason != null) {
      for (int i = history.length - 1; i >= 0; i--) {
        final entry = history[i];
        final entryStatus = entry['status']?.toString().toLowerCase() ?? '';
        final entryAction = entry['action']?.toString().toLowerCase() ?? '';
        if (entryStatus == 'rejected' || entryAction == 'reject') {
          rejectionEntry = entry;
          // Find which step this rejection corresponds to
          // Get stage from entry if available
          final entryStage = entry['stage']?.toString().toLowerCase() ?? '';
          if (entryStage.isNotEmpty) {
            rejectionStepStatus = entryStage;
          } else {
            // Look at previous entries to determine the step
            if (i > 0) {
              final prevEntry = history[i - 1];
              final prevStatus = prevEntry['status']?.toString().toLowerCase() ?? '';
              final prevStage = prevEntry['stage']?.toString().toLowerCase() ?? '';
              // The rejection happened at the step after the last approved step
              final prevStageToUse = prevStage.isNotEmpty ? prevStage : mapStatusToStage(prevStatus);
              final prevIndex = getStatusIndex(prevStageToUse);
              if (prevIndex >= 0 && prevIndex < workflowSteps.length - 1) {
                rejectionStepStatus = workflowSteps[prevIndex + 1].status;
              }
            } else {
              // Rejected at first step
              rejectionStepStatus = workflowSteps[0].status;
            }
          }
          break;
        }
      }
    }

    // Find ALL correction points (use correctionHistory if available, otherwise extract from history)
    final correctionEntries = <Map<String, dynamic>>[];
    final correctionStepStatuses = <String>{};
    
    // Prefer correctionHistory if available
    if (correctionHistory != null && correctionHistory.isNotEmpty) {
      for (final correction in correctionHistory) {
        correctionEntries.add(correction);
        final stage = correction['stage']?.toString().toLowerCase() ?? '';
        if (stage.isNotEmpty) {
          correctionStepStatuses.add(stage);
        }
      }
    } else if (needsCorrection || correctionNote != null) {
      // Fallback: find correction entries from history
      for (int i = 0; i < history.length; i++) {
        final entry = history[i];
        final entryStatus = entry['status']?.toString().toLowerCase() ?? '';
        final entryAction = entry['action']?.toString().toLowerCase() ?? '';
        if (entryStatus == 'needs_correction' || entryAction == 'send_back') {
          correctionEntries.add(entry);
          
          // Get stage from entry or infer from context
          String? stepStatus = entry['stage']?.toString().toLowerCase();
          if (stepStatus == null || stepStatus.isEmpty) {
            // Try to infer from previous entry
            if (i > 0) {
              final prevEntry = history[i - 1];
              final prevStatus = prevEntry['status']?.toString().toLowerCase() ?? '';
              final prevAction = prevEntry['action']?.toString().toLowerCase() ?? '';
              if (prevAction == 'approve') {
                stepStatus = mapStatusToStage(prevStatus);
              }
            }
            if (stepStatus == null || stepStatus.isEmpty) {
              stepStatus = workflowSteps[0].status;
            }
          }
          correctionStepStatuses.add(stepStatus);
        }
      }
    }
    
    // Get latest correction entry for backward compatibility
    Map<String, dynamic>? correctionEntry = correctionEntries.isNotEmpty 
        ? correctionEntries.last 
        : null;
    String? correctionStepStatus = correctionStepStatuses.isNotEmpty
        ? correctionStepStatuses.last
        : null;

    // Build map of approval entries by stage (from actionHistory or approvalChain)
    // When an approval happens at a stage, that stage is completed
    final approvalMap = <String, Map<String, dynamic>>{};
    final completedStages = <String>{};
    
    for (final entry in history) {
      final status = entry['status']?.toString().toLowerCase() ?? '';
      final action = entry['action']?.toString().toLowerCase() ?? '';
      final stage = entry['stage']?.toString().toLowerCase() ?? '';
      
      // Use stage if available, otherwise map status to stage
      final entryStage = stage.isNotEmpty ? stage : mapStatusToStage(status);
      
      // Explicitly check for approval actions
      // In actionHistory, approved actions have action='approve'
      // In approvalChain (legacy), any entry with status that's not rejected/needs_correction is an approval
      final isApprovalAction = action == 'approve' || 
          (action.isEmpty && entryStage.isNotEmpty && 
           status != 'rejected' && 
           status != 'needs_correction');
      
      // Only include approval actions, exclude rejections, corrections, and cancellations
      if (entryStage.isNotEmpty && 
          isApprovalAction &&
          action != 'reject' &&
          action != 'send_back' &&
          action != 'cancel') {
        approvalMap[entryStage] = entry;
        completedStages.add(entryStage); // Stage where approval happened is completed
      }
    }

    // Determine current stage index in workflow
    final currentStageIndex = getStatusIndex(actualCurrentStage);
    
    // Debug logging
    debugPrint('[RequestWorkflow] Timeline Debug:');
    debugPrint('  currentStatus: $currentStatus');
    debugPrint('  currentStage param: $currentStage');
    debugPrint('  actualCurrentStage: $actualCurrentStage');
    debugPrint('  currentStageIndex: $currentStageIndex');
    debugPrint('  completedStages from history: ${completedStages.toList()}');
    debugPrint('  approvalMap keys: ${approvalMap.keys.toList()}');
    
    // All stages before the current stage should be marked as completed
    // (if they are in the workflow path and we're not at an initial stage)
    // This ensures that even if actionHistory is incomplete, we still mark previous stages as completed
    if (currentStageIndex >= 0) {
      for (int i = 0; i < currentStageIndex; i++) {
        final stageToMark = workflowSteps[i].status;
        completedStages.add(stageToMark);
        debugPrint('  Marking stage $stageToMark as completed (before current stage $actualCurrentStage)');
      }
      debugPrint('  completedStages after adding before current: ${completedStages.toList()}');
    } else {
      debugPrint('  WARNING: currentStageIndex is -1, actualCurrentStage=$actualCurrentStage not found in workflowSteps');
    }

    // If resubmitted, determine where it resumed from
    int? resumeFromIndex;
    if (resubmittedAt != null && rejectionStepStatus != null) {
      resumeFromIndex = getStatusIndex(rejectionStepStatus);
    }

    final timelineItems = <TimelineItem>[];
    bool resubmissionShown = false;

    for (int i = 0; i < workflowSteps.length; i++) {
      final step = workflowSteps[i];
      final stepStatus = step.status;
      
      // Determine status of this step
      TimelineItemStatus itemStatus;
      IconData icon;
      Color color;
      String? subtitle;
      DateTime? timestamp;
      Map<String, dynamic>? metadata = {};

      // Check if this step has any correction entries
      final stepCorrections = correctionEntries.where((entry) {
        // Get stage from correction entry
        final entryStage = entry['stage']?.toString().toLowerCase() ?? '';
        if (entryStage.isNotEmpty) {
          return entryStage == stepStatus;
        }
        // Fallback: try to infer from entry index
        final entryIndex = history.indexOf(entry);
        if (entryIndex < 0) return false;
        
        String? inferredStage;
        if (entryIndex > 0) {
          final prevEntry = history[entryIndex - 1];
          final prevStage = prevEntry['stage']?.toString().toLowerCase() ?? '';
          final prevStatus = prevEntry['status']?.toString().toLowerCase() ?? '';
          inferredStage = prevStage.isNotEmpty ? prevStage : mapStatusToStage(prevStatus);
        } else {
          inferredStage = workflowSteps[0].status;
        }
        
        return inferredStage == stepStatus;
      }).toList();
      
      // Show latest correction at this step (if any)
      if (stepCorrections.isNotEmpty && stepStatus == correctionStepStatus) {
        final latestCorrectionAtStep = stepCorrections.last;
        
        itemStatus = TimelineItemStatus.pending; // Use pending status with warning color
        icon = Icons.edit_note_rounded;
        color = AppTheme.warningColor;
        
        final approver = latestCorrectionAtStep['approverId'];
        subtitle = approver?['name'] ?? 'Unknown';
        timestamp = latestCorrectionAtStep['timestamp'] != null 
            ? DateTime.parse(latestCorrectionAtStep['timestamp']) 
            : correctedAt;
        
        final correctionMetadata = <String, dynamic>{};
        final correctionNoteText = latestCorrectionAtStep['comments']?.toString() ?? correctionNote;
        if (correctionNoteText != null && correctionNoteText.isNotEmpty) {
          correctionMetadata['Correction Note'] = correctionNoteText;
        }
        if (approver != null) {
          correctionMetadata['Sent Back By'] = approver['name']?.toString() ?? 'Unknown';
        }
        
        // If multiple corrections at this step, add count
        if (stepCorrections.length > 1) {
          correctionMetadata['Total Corrections'] = '${stepCorrections.length} corrections at this stage';
        }
        
        timelineItems.add(TimelineItem(
          id: 'correction_${stepStatus}_${latestCorrectionAtStep['timestamp']}',
          title: step.title,
          subtitle: subtitle,
          description: step.description,
          timestamp: timestamp,
          status: itemStatus,
          icon: icon,
          color: color,
          metadata: correctionMetadata.isNotEmpty ? correctionMetadata : null,
        ));
        
        // Add resubmission indicator if resubmitted (only for latest correction)
        if (resubmittedAt != null && !resubmissionShown && latestCorrectionAtStep == correctionEntry) {
          timelineItems.add(TimelineItem(
            id: 'resubmission_correction_$stepStatus',
            title: 'Resubmitted',
            subtitle: 'Request corrected and resubmitted',
            description: 'The request was corrected and resubmitted. Continuing from this point.',
            timestamp: resubmittedAt,
            status: TimelineItemStatus.inProgress,
            icon: Icons.refresh_rounded,
            color: AppTheme.infoColor,
          ));
          resubmissionShown = true;
        }
        
        continue;
      }

      // Check if this is the cancellation point
      if (isCancelled && stepStatus == 'submitted' && cancellationReason != null) {
        itemStatus = TimelineItemStatus.failed;
        icon = Icons.cancel_rounded;
        color = AppTheme.errorColor;
        
        subtitle = cancelledBy ?? 'Unknown';
        timestamp = cancelledAt;
        
        final cancellationMetadata = <String, dynamic>{};
        cancellationMetadata['Cancellation Reason'] = cancellationReason;
        if (cancelledBy != null) {
          cancellationMetadata['Cancelled By'] = cancelledBy;
        }
        
        timelineItems.add(TimelineItem(
          id: 'cancellation_$stepStatus',
          title: 'Cancelled',
          subtitle: subtitle,
          description: 'Request has been cancelled',
          timestamp: timestamp,
          status: itemStatus,
          icon: icon,
          color: color,
          metadata: cancellationMetadata.isNotEmpty ? cancellationMetadata : null,
        ));
        continue;
      }
      
      // Check if this is the rejection point
      if (rejectionStepStatus == stepStatus && rejectionEntry != null && !isCancelled) {
        itemStatus = TimelineItemStatus.failed;
        icon = Icons.cancel_rounded;
        color = AppTheme.errorColor;
        
        final approver = rejectionEntry['approverId'];
        subtitle = approver?['name'] ?? 'Unknown';
        timestamp = rejectionEntry['timestamp'] != null 
            ? DateTime.parse(rejectionEntry['timestamp']) 
            : rejectedAt;
        
        if (rejectionReason != null) {
          metadata['Rejection Reason'] = rejectionReason;
        }
        if (rejectedBy != null) {
          final rejectedByUser = rejectionEntry['approverId'];
          metadata['Rejected By'] = rejectedByUser?['name'] ?? rejectedBy;
        }
        
        timelineItems.add(TimelineItem(
          id: 'rejection_$stepStatus',
          title: step.title,
          subtitle: subtitle,
          description: step.description,
          timestamp: timestamp,
          status: itemStatus,
          icon: icon,
          color: color,
          metadata: metadata.isNotEmpty ? metadata : null,
        ));
        
        // Add resubmission indicator if resubmitted (only once, right after rejection)
        if (resubmittedAt != null && !resubmissionShown) {
          timelineItems.add(TimelineItem(
            id: 'resubmission_$stepStatus',
            title: 'Resubmitted',
            subtitle: 'Request corrected and resubmitted',
            description: 'The request was corrected and resubmitted. Continuing from this point.',
            timestamp: resubmittedAt,
            status: TimelineItemStatus.inProgress,
            icon: Icons.refresh_rounded,
            color: AppTheme.infoColor,
          ));
          resubmissionShown = true;
        }
        
        continue;
      }

      // Determine step status: completed, current, or pending
      final stepStatusNormalized = stepStatus.toLowerCase().trim();
      final isCurrentStep = stepStatusNormalized == currentStatusLower;
      final isStepCompleted = completedStages.contains(stepStatus);
      
      // Debug logging for each step
      if (stepStatus == 'supervisor_review' || stepStatus == 'dgs_review') {
        debugPrint('[RequestWorkflow] Step $stepStatus: isCurrentStep=$isCurrentStep, isStepCompleted=$isStepCompleted, currentStatusLower=$currentStatusLower');
      }
      
      // Check if this is the current step (and not rejected or needs correction)
      // IMPORTANT: Check current step FIRST before checking if completed
      // A step can't be both current and completed
      if (isCurrentStep && !isRejected && !needsCorrection && !isCancelled) {
        itemStatus = TimelineItemStatus.inProgress;
        icon = Icons.radio_button_checked_rounded;
        color = AppTheme.warningColor; // Use warning color (yellow/orange) for current stage
        
        final entry = approvalMap[stepStatus];
        if (entry != null) {
          final approver = entry['approverId'];
          subtitle = approver?['name'] ?? 'Current';
          timestamp = entry['timestamp'] != null 
              ? DateTime.parse(entry['timestamp']) 
              : null;
        } else {
          // For review stages, use appropriate wording
          if (stepStatus == 'supervisor_review' || stepStatus == 'dgs_review' || 
              stepStatus == 'ddgs_review' || stepStatus == 'ad_transport_review') {
            timestamp = createdAt;
            subtitle = 'In Review';
          } else {
            timestamp = createdAt;
            subtitle = 'Current';
          }
        }
      }
      // Check if step is completed
      else if (isStepCompleted || (resubmittedAt != null && resumeFromIndex != null && i < resumeFromIndex)) {
        itemStatus = TimelineItemStatus.completed;
        icon = Icons.check_circle_rounded;
        color = AppTheme.successColor;
        
        final entry = approvalMap[stepStatus];
        if (entry != null) {
          final approver = entry['performedBy'] ?? entry['approverId'];
          final approverName = approver is Map ? (approver['name'] ?? 'Unknown') : 'Unknown';
          subtitle = 'Approved by $approverName';
          timestamp = entry['performedAt'] != null 
              ? DateTime.parse(entry['performedAt'].toString()) 
              : (entry['timestamp'] != null 
                  ? DateTime.parse(entry['timestamp'].toString()) 
                  : null);
          
          if (entry['notes'] != null && entry['notes'].toString().isNotEmpty) {
            metadata['Comments'] = entry['notes'].toString();
          } else if (entry['comments'] != null && entry['comments'].toString().isNotEmpty) {
            metadata['Comments'] = entry['comments'].toString();
          }
        } else {
          subtitle = 'Approved';
        }
      }
      // Handle 'returned' status - treat as completed
      else if (currentStatusLower == 'returned' && stepStatus == 'returned') {
        itemStatus = TimelineItemStatus.completed;
        icon = Icons.check_circle_rounded;
        color = AppTheme.successColor;
        subtitle = 'Completed';
      }
      // Future step (not reached) - use "Pending" instead of "Not Reached"
      else {
        itemStatus = TimelineItemStatus.notReached;
        icon = Icons.radio_button_unchecked_rounded;
        color = Colors.grey.withOpacity(0.5);
        subtitle = 'Pending';
      }

      timelineItems.add(TimelineItem(
        id: stepStatus,
        title: step.title,
        subtitle: subtitle,
        description: step.description,
        timestamp: timestamp,
        status: itemStatus,
        icon: icon,
        color: color,
        metadata: metadata.isNotEmpty ? metadata : null,
      ));
    }

    return timelineItems;
  }

  /// Format status string for display
  static String formatStatus(String status) {
    return status.split('_').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  /// Build timeline items for correction history
  static List<TimelineItem> buildCorrectionTimeline({
    required List<dynamic> correctionHistory,
    List<dynamic>? actionHistory,
    List<dynamic>? approvalChain,
  }) {
    if (correctionHistory.isEmpty) {
      return [];
    }

    final history = correctionHistory
        .map((entry) => entry is Map<String, dynamic>
            ? entry
            : Map<String, dynamic>.from(entry as Map))
        .toList();

    history.sort((a, b) {
      final aDate = _parseDate(a['requestedAt']);
      final bDate = _parseDate(b['requestedAt']);
      return aDate.compareTo(bDate);
    });

    final timelineItems = <TimelineItem>[];

    for (int index = 0; index < history.length; index++) {
      final entry = history[index];
      final stage = (entry['stage'] ?? '').toString();
      final step = getStepByStatus(stage);

      final title = step?.title ?? formatStatus(stage.isNotEmpty ? stage : 'Correction');
      final description = step?.description ?? 'Correction requested at this stage';

      final requestedAt = _parseDate(entry['requestedAt']);
      final resolvedAt = _parseNullableDate(entry['resolvedAt']);
      final correctionNote = (entry['correctionNote'] ?? '').toString().trim();
      final resubmissionCount = entry['resubmissionCount'] is int
          ? entry['resubmissionCount'] as int
          : int.tryParse(entry['resubmissionCount']?.toString() ?? '');

      final requestedByName = _resolveUserName(entry['requestedBy'], approvalChain);
      final timelineStatus = resolvedAt != null
          ? TimelineItemStatus.completed
          : TimelineItemStatus.inProgress;

      final metadata = <String, dynamic>{};
      if (correctionNote.isNotEmpty) {
        metadata['Correction Note'] = correctionNote;
      }
      metadata['Requested By'] = requestedByName ?? 'Unknown';
      metadata['Requested On'] = DateFormat('MMM dd, yyyy HH:mm').format(requestedAt);
      if (resubmissionCount != null && resubmissionCount > 0) {
        metadata['Resubmission Count'] = resubmissionCount;
      }

      if (resolvedAt != null) {
        metadata['Resolved On'] = DateFormat('MMM dd, yyyy HH:mm').format(resolvedAt);
      } else {
        metadata['Status'] = 'Awaiting resubmission';
      }

      timelineItems.add(
        TimelineItem(
          id: 'correction_${stage}_$index',
          title: title,
          subtitle: requestedByName ?? 'Correction Requested',
          description: description,
          timestamp: requestedAt,
          status: timelineStatus,
          icon: timelineStatus == TimelineItemStatus.completed
              ? Icons.check_circle_rounded
              : Icons.edit_note_rounded,
          color: timelineStatus == TimelineItemStatus.completed
              ? AppTheme.successColor
              : AppTheme.warningColor,
          metadata: metadata,
        ),
      );

      if (resolvedAt != null) {
        final resolvedEntry = _findResubmissionEntry(
          actionHistory,
          resolvedAt,
        );

        if (resolvedEntry != null) {
          final resolvedBy = _resolveUserName(resolvedEntry['performedBy'], approvalChain);
          final resolvedMetadata = <String, dynamic>{
            'Resubmitted By': resolvedBy ?? 'Unknown',
            'Comments': (resolvedEntry['notes'] ?? '').toString().trim().isNotEmpty
                ? resolvedEntry['notes']
                : 'No additional comments',
          };

          timelineItems.add(
            TimelineItem(
              id: 'correction_resolved_${stage}_$index',
              title: 'Resubmitted',
              subtitle: resolvedBy ?? 'Request Resubmitted',
              description: 'Request was corrected and resubmitted.',
              timestamp: resolvedAt,
              status: TimelineItemStatus.completed,
              icon: Icons.refresh_rounded,
              color: AppTheme.infoColor,
              metadata: resolvedMetadata,
            ),
          );
        }
      }
    }

    return timelineItems;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic>? _findResubmissionEntry(
    List<dynamic>? actionHistory,
    DateTime resolvedAt,
  ) {
    if (actionHistory == null) return null;
    for (final entry in actionHistory) {
      final map = entry is Map<String, dynamic> ? entry : Map<String, dynamic>.from(entry as Map);
      final action = (map['action'] ?? '').toString().toLowerCase();
      if (action == 'resubmit') {
        final performedAt = _parseNullableDate(map['performedAt']);
        if (performedAt != null) {
          final diff = performedAt.difference(resolvedAt).abs();
          if (diff.inMinutes <= 5) {
            return map;
          }
        }
      }
    }
    return null;
  }

  static String? _resolveUserName(dynamic value, List<dynamic>? approvalChain) {
    if (value == null) return null;
    if (value is Map) {
      if (value['name'] != null) {
        return value['name'].toString();
      }
      if (value['_id'] != null) {
        return _lookupNameInApprovalChain(value['_id'].toString(), approvalChain);
      }
    }
    if (value is String && value.trim().isNotEmpty) {
      return _lookupNameInApprovalChain(value, approvalChain);
    }
    return null;
  }

  static String? _lookupNameInApprovalChain(String id, List<dynamic>? approvalChain) {
    if (approvalChain == null) return null;
    for (final entry in approvalChain) {
      final map = entry is Map<String, dynamic> ? entry : Map<String, dynamic>.from(entry as Map);
      final approver = map['approverId'];
      if (approver is Map && (approver['_id']?.toString() == id || approver['id']?.toString() == id)) {
        return approver['name']?.toString();
      }
      if (approver is String && approver == id) {
        if (map['approverName'] != null) {
          return map['approverName'].toString();
        }
      }
    }
    return null;
  }
}

/// Represents a single step in the workflow
class WorkflowStep {
  final String status;
  final String title;
  final String description;
  final String role;

  const WorkflowStep({
    required this.status,
    required this.title,
    required this.description,
    required this.role,
  });
}

