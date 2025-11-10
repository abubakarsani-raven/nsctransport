/**
 * Workflow action types that can be performed on requests
 */
export enum WorkflowAction {
  APPROVE = 'approve',
  REJECT = 'reject',
  SEND_BACK = 'send_back',
  CANCEL = 'cancel',
  RESUBMIT = 'resubmit',
  ASSIGN = 'assign', // For transport officer assigning driver/vehicle
  ACCEPT = 'accept', // For driver accepting assignment
  START_TRIP = 'start_trip',
  COMPLETE_TRIP = 'complete_trip',
  RETURN_VEHICLE = 'return_vehicle',
  FULFILL = 'fulfill', // For fulfilling ICT/Store requests
}

