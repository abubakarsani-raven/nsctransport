import { Model } from 'mongoose';
import { VehicleRequest, VehicleRequestDocument } from '../../requests/vehicle/schemas/vehicle-request.schema';
import { RequestStatus } from '../../requests/vehicle/schemas/vehicle-request.schema';
import { VehicleRequestStage } from '../../workflow/workflow-definition';
import { WorkflowAction } from '../../workflow/schemas/workflow-actions.enum';

/**
 * Migration script to convert existing requests from status-based to workflow-based system
 * 
 * This script:
 * 1. Maps old statuses to new workflow stages
 * 2. Converts approval chain entries to action history
 * 3. Extracts correction history from approval chain
 * 4. Sets currentStage based on status
 */
export async function migrateToWorkflow(requestModel: Model<VehicleRequestDocument>): Promise<void> {
  console.log('Starting workflow migration...');

  const requests = await requestModel.find({}).exec();
  console.log(`Found ${requests.length} requests to migrate`);

  let migrated = 0;
  let errors = 0;

  for (const request of requests) {
    try {
      // Map status to workflow stage
      const stage = mapStatusToStage(request.status);
      
      // Set currentStage if not already set
      if (!request.currentStage) {
        (request as any).currentStage = stage;
      }

      // Convert approval chain to action history if actionHistory is empty
      if ((!request.actionHistory || request.actionHistory.length === 0) && 
          request.approvalChain && request.approvalChain.length > 0) {
        const actionHistory: any[] = [];
        
        for (const entry of request.approvalChain) {
          // Determine action type from status
          let action: WorkflowAction;
          if (entry.status === 'rejected') {
            action = WorkflowAction.REJECT;
          } else if (entry.status === 'needs_correction') {
            action = WorkflowAction.SEND_BACK;
          } else {
            action = WorkflowAction.APPROVE;
          }

          // Determine stage from status
          const entryStage = mapStatusToStage(entry.status);

          actionHistory.push({
            action,
            performedBy: entry.approverId,
            performedAt: entry.timestamp,
            stage: entryStage,
            notes: entry.comments,
          });
        }

        (request as any).actionHistory = actionHistory;
      }

      // Extract correction history from approval chain
      if ((!request.correctionHistory || request.correctionHistory.length === 0) && 
          request.approvalChain && request.approvalChain.length > 0) {
        const correctionHistory: any[] = [];
        
        for (const entry of request.approvalChain) {
          if (entry.status === 'needs_correction') {
            // Check if this correction was resolved (if there's a later entry)
            const entryIndex = request.approvalChain.indexOf(entry);
            const laterEntries = request.approvalChain.slice(entryIndex + 1);
            const resolvedAt = laterEntries.length > 0 ? laterEntries[0].timestamp : undefined;

            correctionHistory.push({
              stage: mapStatusToStage(entry.status),
              requestedBy: entry.approverId,
              requestedAt: entry.timestamp,
              correctionNote: entry.comments || request.correctionNote || '',
              resolvedAt,
              resubmissionCount: 1,
            });
          }
        }

        if (correctionHistory.length > 0) {
          (request as any).correctionHistory = correctionHistory;
        }
      }

      // Ensure arrays exist
      if (!request.actionHistory) {
        (request as any).actionHistory = [];
      }
      if (!request.correctionHistory) {
        (request as any).correctionHistory = [];
      }

      // Mark arrays as modified
      request.markModified('actionHistory');
      request.markModified('correctionHistory');
      request.markModified('currentStage');

      await request.save();
      migrated++;
      
      if (migrated % 100 === 0) {
        console.log(`Migrated ${migrated} requests...`);
      }
    } catch (error) {
      console.error(`Error migrating request ${request._id}:`, error);
      errors++;
    }
  }

  console.log(`Migration complete. Migrated: ${migrated}, Errors: ${errors}`);
}

/**
 * Map old status to new workflow stage
 */
function mapStatusToStage(status: RequestStatus | string): string {
  const statusMap: Record<string, string> = {
    [RequestStatus.PENDING]: VehicleRequestStage.SUBMITTED,
    [RequestStatus.SUPERVISOR_APPROVED]: VehicleRequestStage.SUPERVISOR_REVIEW,
    [RequestStatus.DGS_APPROVED]: VehicleRequestStage.DGS_REVIEW,
    [RequestStatus.DDGS_APPROVED]: VehicleRequestStage.DDGS_REVIEW,
    [RequestStatus.AD_TRANSPORT_APPROVED]: VehicleRequestStage.AD_TRANSPORT_REVIEW,
    [RequestStatus.TRANSPORT_OFFICER_ASSIGNED]: VehicleRequestStage.ASSIGNED,
    [RequestStatus.DRIVER_ACCEPTED]: VehicleRequestStage.ASSIGNED,
    [RequestStatus.IN_PROGRESS]: VehicleRequestStage.IN_PROGRESS,
    [RequestStatus.COMPLETED]: VehicleRequestStage.COMPLETED,
    [RequestStatus.RETURNED]: VehicleRequestStage.RETURNED,
    [RequestStatus.REJECTED]: VehicleRequestStage.REJECTED,
    [RequestStatus.NEEDS_CORRECTION]: VehicleRequestStage.NEEDS_CORRECTION,
    [RequestStatus.CANCELLED]: VehicleRequestStage.CANCELLED,
  };

  return statusMap[status] || VehicleRequestStage.SUBMITTED;
}

