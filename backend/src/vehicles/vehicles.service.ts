import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, isValidObjectId } from 'mongoose';
import { Vehicle, VehicleDocument, VehicleStatus } from './schemas/vehicle.schema';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { AssignPermanentlyDto } from './dto/assign-permanently.dto';
import { UpdatePermanentAssignmentDto } from './dto/update-permanent-assignment.dto';
import { UsersService } from '../users/users.service';

@Injectable()
export class VehiclesService {
  constructor(
    @InjectModel(Vehicle.name) private vehicleModel: Model<VehicleDocument>,
    private usersService: UsersService,
  ) {}

  async create(createVehicleDto: CreateVehicleDto): Promise<VehicleDocument> {
    const createdVehicle = new this.vehicleModel(createVehicleDto);
    return createdVehicle.save();
  }

  async findAll(): Promise<VehicleDocument[]> {
    return this.vehicleModel.find()
      .populate('permanentlyAssignedToUserId', 'name email roles')
      .populate('permanentlyAssignedDriverId', 'name email phone employeeId')
      .exec();
  }

  async findById(id: string): Promise<VehicleDocument | null> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      return null;
    }
    return this.vehicleModel.findById(cleanId)
      .populate('permanentlyAssignedToUserId', 'name email roles')
      .populate('permanentlyAssignedDriverId', 'name email phone employeeId')
      .exec();
  }

  async findAvailable(): Promise<VehicleDocument[]> {
    return this.vehicleModel.find({ 
      status: { $ne: VehicleStatus.PERMANENTLY_ASSIGNED } 
    }).exec();
  }

  async update(id: string, updateVehicleDto: any): Promise<VehicleDocument> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new NotFoundException('Vehicle not found');
    }
    const vehicle = await this.vehicleModel.findByIdAndUpdate(cleanId, updateVehicleDto, { new: true }).exec();
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }
    return vehicle;
  }

  async updateStatus(id: string, status: VehicleStatus): Promise<VehicleDocument> {
    return this.update(id, { status });
  }

  async delete(id: string): Promise<void> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new NotFoundException('Vehicle not found');
    }
    const result = await this.vehicleModel.findByIdAndDelete(cleanId).exec();
    if (!result) {
      throw new NotFoundException('Vehicle not found');
    }
  }

  async assignPermanently(id: string, assignDto: AssignPermanentlyDto): Promise<VehicleDocument> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new NotFoundException('Vehicle not found');
    }

    const vehicle = await this.findById(cleanId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    // Verify user exists
    const user = await this.usersService.findById(assignDto.userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Verify driver exists
    const driver = await this.usersService.findById(assignDto.driverId);
    if (!driver) {
      throw new NotFoundException('Driver not found');
    }

    // Check if vehicle is already permanently assigned
    if (vehicle.status === VehicleStatus.PERMANENTLY_ASSIGNED) {
      throw new BadRequestException('Vehicle is already permanently assigned');
    }

    // Update vehicle with permanent assignment
    return this.update(cleanId, {
      status: VehicleStatus.PERMANENTLY_ASSIGNED,
      permanentlyAssignedToUserId: assignDto.userId,
      permanentlyAssignedDriverId: assignDto.driverId,
      permanentAssignmentPosition: assignDto.position,
      permanentAssignmentNotes: assignDto.notes,
    });
  }

  async updatePermanentAssignment(id: string, updateDto: UpdatePermanentAssignmentDto): Promise<VehicleDocument> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new NotFoundException('Vehicle not found');
    }

    const vehicle = await this.findById(cleanId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    if (vehicle.status !== VehicleStatus.PERMANENTLY_ASSIGNED) {
      throw new BadRequestException('Vehicle is not permanently assigned');
    }

    // Verify user exists if provided
    if (updateDto.userId) {
      const user = await this.usersService.findById(updateDto.userId);
      if (!user) {
        throw new NotFoundException('User not found');
      }
    }

    // Verify driver exists if provided
    if (updateDto.driverId) {
      const driver = await this.usersService.findById(updateDto.driverId);
      if (!driver) {
        throw new NotFoundException('Driver not found');
      }
    }

    const updateData: any = {};
    if (updateDto.userId !== undefined) {
      updateData.permanentlyAssignedToUserId = updateDto.userId;
    }
    if (updateDto.driverId !== undefined) {
      updateData.permanentlyAssignedDriverId = updateDto.driverId;
    }
    if (updateDto.position !== undefined) {
      updateData.permanentAssignmentPosition = updateDto.position;
    }
    if (updateDto.notes !== undefined) {
      updateData.permanentAssignmentNotes = updateDto.notes;
    }

    return this.update(cleanId, updateData);
  }

  async removePermanentAssignment(id: string): Promise<VehicleDocument> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new NotFoundException('Vehicle not found');
    }

    const vehicle = await this.findById(cleanId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    if (vehicle.status !== VehicleStatus.PERMANENTLY_ASSIGNED) {
      throw new BadRequestException('Vehicle is not permanently assigned');
    }

    return this.update(cleanId, {
      status: VehicleStatus.AVAILABLE,
      permanentlyAssignedToUserId: undefined,
      permanentlyAssignedDriverId: undefined,
      permanentAssignmentPosition: undefined,
      permanentAssignmentNotes: undefined,
    });
  }

  async findPermanentlyAssigned(): Promise<VehicleDocument[]> {
    return this.vehicleModel.find({ status: VehicleStatus.PERMANENTLY_ASSIGNED })
      .populate('permanentlyAssignedToUserId', 'name email roles')
      .populate('permanentlyAssignedDriverId', 'name email phone employeeId')
      .exec();
  }

  async findPermanentlyAssignedByUser(userId: string): Promise<VehicleDocument | null> {
    return this.vehicleModel.findOne({ 
      status: VehicleStatus.PERMANENTLY_ASSIGNED,
      permanentlyAssignedToUserId: userId 
    })
      .populate('permanentlyAssignedToUserId', 'name email roles')
      .populate('permanentlyAssignedDriverId', 'name email phone employeeId')
      .exec();
  }
}

