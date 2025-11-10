import { WorkflowAction } from './workflow-actions.enum';

/**
 * Represents a transition from one stage to another
 */
export interface WorkflowTransition {
  fromStage: string;
  toStage: string;
  action: WorkflowAction;
  condition?: (context: any) => boolean; // Optional condition function
}

/**
 * Represents available actions at a stage
 */
export interface StageActions {
  stage: string;
  allowedActions: WorkflowAction[];
  requiredRole?: string | string[]; // Role(s) that can perform actions at this stage
  requiresSupervisorMatch?: boolean; // If true, supervisor must match request's supervisor
}

/**
 * Workflow stage definition
 */
export interface WorkflowStage {
  id: string;
  name: string;
  description: string;
  actions: StageActions;
  isTerminal?: boolean; // If true, workflow ends at this stage
  isInitial?: boolean; // If true, this is the initial stage
}

