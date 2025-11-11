export enum MaintenanceType {
  OIL_CHANGE = 'oil_change',
  TIRE_CHANGE = 'tire_change',
  BRAKE_LIGHTS = 'brake_lights',
  HEAD_LIGHTS = 'head_lights',
  BRAKE_PADS = 'brake_pads',
  GEAR_OIL_CHECK = 'gear_oil_check',
  ENGINE_FILTER = 'engine_filter',
  AIR_FILTER = 'air_filter',
  BATTERY_REPLACEMENT = 'battery_replacement',
  FLUID_CHECK = 'fluid_check',
  GENERAL_INSPECTION = 'general_inspection',
  OTHER = 'other',
}

export interface MaintenanceRecord {
  _id: string;
  vehicleId: string;
  maintenanceType: MaintenanceType;
  customTypeName?: string;
  description?: string;
  performedAt: string;
  availableUntil?: string;
  quantity?: number;
  performedBy?: string | { _id: string; name: string; email: string };
  cost?: number;
  createdAt?: string;
  updatedAt?: string;
}

export interface MaintenanceReminder {
  _id: string;
  vehicleId: string;
  maintenanceType: MaintenanceType;
  customTypeName?: string;
  reminderIntervalDays: number;
  lastPerformedDate?: string;
  nextReminderDate: string;
  isActive: boolean;
  notes?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateMaintenanceRecordDto {
  maintenanceType: MaintenanceType;
  customTypeName?: string;
  description?: string;
  performedAt: Date;
  availableUntil?: Date;
  quantity?: number;
  performedBy?: string;
  cost?: number;
}

export interface CreateReminderDto {
  maintenanceType: MaintenanceType;
  customTypeName?: string;
  reminderIntervalDays: number;
  lastPerformedDate?: Date;
  isActive?: boolean;
  notes?: string;
}

export const MAINTENANCE_TYPE_LABELS: Record<MaintenanceType, string> = {
  [MaintenanceType.OIL_CHANGE]: 'Oil Change',
  [MaintenanceType.TIRE_CHANGE]: 'Tire Change',
  [MaintenanceType.BRAKE_LIGHTS]: 'Brake Lights',
  [MaintenanceType.HEAD_LIGHTS]: 'Head Lights',
  [MaintenanceType.BRAKE_PADS]: 'Brake Pads',
  [MaintenanceType.GEAR_OIL_CHECK]: 'Gear Oil Check',
  [MaintenanceType.ENGINE_FILTER]: 'Engine Filter',
  [MaintenanceType.AIR_FILTER]: 'Air Filter',
  [MaintenanceType.BATTERY_REPLACEMENT]: 'Battery Replacement',
  [MaintenanceType.FLUID_CHECK]: 'Fluid Check',
  [MaintenanceType.GENERAL_INSPECTION]: 'General Inspection',
  [MaintenanceType.OTHER]: 'Other',
};

