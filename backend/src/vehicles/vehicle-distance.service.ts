import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, isValidObjectId } from 'mongoose';
import { VehicleDistanceLog, VehicleDistanceLogDocument } from './schemas/vehicle-distance-log.schema';
import { VehiclesService } from './vehicles.service';

@Injectable()
export class VehicleDistanceService {
  constructor(
    @InjectModel(VehicleDistanceLog.name)
    private distanceLogModel: Model<VehicleDistanceLogDocument>,
    private vehiclesService: VehiclesService,
  ) {}

  async logDistance(
    vehicleId: string,
    distance: number,
    source: 'trip' | 'manual' | 'odometer',
    tripId?: string,
    recordedBy?: string,
    notes?: string,
  ): Promise<VehicleDistanceLogDocument> {
    if (!isValidObjectId(vehicleId)) {
      throw new NotFoundException('Invalid vehicle ID');
    }

    const vehicle = await this.vehiclesService.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    const currentTotal = vehicle.totalDistanceTravelled || 0;
    const newTotal = currentTotal + distance;

    // Create log entry
    const logEntry = new this.distanceLogModel({
      vehicleId,
      distance,
      cumulativeDistance: newTotal,
      tripId,
      recordedBy,
      source,
      notes,
      recordedAt: new Date(),
    });

    // Update vehicle total
    await this.vehiclesService.update(vehicleId, {
      totalDistanceTravelled: newTotal,
      lastOdometerUpdate: new Date(),
      lastRecordedDistance: distance,
    });

    return logEntry.save();
  }

  async getDistanceHistory(
    vehicleId: string,
    startDate?: Date,
    endDate?: Date,
  ): Promise<VehicleDistanceLogDocument[]> {
    if (!isValidObjectId(vehicleId)) {
      throw new NotFoundException('Invalid vehicle ID');
    }

    const query: any = { vehicleId };

    if (startDate || endDate) {
      query.recordedAt = {};
      if (startDate) query.recordedAt.$gte = startDate;
      if (endDate) query.recordedAt.$lte = endDate;
    }

    return this.distanceLogModel
      .find(query)
      .sort({ recordedAt: -1 })
      .populate('tripId', 'requestId')
      .populate('recordedBy', 'name email')
      .exec();
  }

  async getTotalDistance(vehicleId: string): Promise<number> {
    if (!isValidObjectId(vehicleId)) {
      throw new NotFoundException('Invalid vehicle ID');
    }

    const vehicle = await this.vehiclesService.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    return vehicle.totalDistanceTravelled || 0;
  }
}

