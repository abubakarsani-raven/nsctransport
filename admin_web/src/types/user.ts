export type UserRole =
  | 'staff'
  | 'driver'
  | 'transport_officer'
  | 'admin'
  | 'dgs'
  | 'ddgs'
  | 'ad_transport';

export interface UserProfile {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  department?: string;
  isSupervisor?: boolean;
  phone?: string;
  employeeId?: string;
}


