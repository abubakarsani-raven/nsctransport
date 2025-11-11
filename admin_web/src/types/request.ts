// Shared request types
export type RequestType = 'VEHICLE' | 'ICT' | 'STORE';

export interface BaseRequest {
  _id: string;
  requestType: RequestType;
  requesterId: string | { _id: string; name: string; email: string };
  supervisorId?: string | { _id: string; name: string; email: string };
  status: string;
  createdAt?: string;
  updatedAt?: string;
}

// Re-export types from specific request modules
export * from './ict-request';
export * from './store-request';

