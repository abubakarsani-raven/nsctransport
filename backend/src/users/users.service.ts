import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as bcrypt from 'bcrypt';
import { User, UserDocument, UserRole } from './schemas/user.schema';
import { Trip, TripDocument, TripStatus } from '../trips/schemas/trip.schema';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { UserUpdatedEvent } from '../events/events';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Trip.name) private tripModel: Model<TripDocument>,
    private eventEmitter: EventEmitter2,
  ) {}

  async create(createUserDto: any): Promise<UserDocument> {
    const createdUser = new this.userModel(createUserDto);
    const savedUser = await createdUser.save();
    
    // Emit user updated event
    this.eventEmitter.emit('user.updated', new UserUpdatedEvent());
    
    return savedUser;
  }

  async findAll(): Promise<UserDocument[]> {
    const users = await this.userModel.find().exec();
    console.log(`Found ${users.length} users in database`);
    return users;
  }

  async findById(id: string): Promise<UserDocument | null> {
    return this.userModel.findById(id).exec();
  }

  async findByEmail(email: string): Promise<UserDocument | null> {
    const user = await this.userModel.findOne({ email }).exec();
    if (user) {
      console.log('User found by email:', { email, userId: user._id, roles: user.roles });
    }
    return user;
  }

  async findByRole(role: UserRole): Promise<UserDocument[]> {
    return this.userModel.find({ roles: { $in: [role] } }).exec();
  }

  async findDrivers(): Promise<any[]> {
    const drivers = await this.userModel.find({ roles: { $in: [UserRole.DRIVER] } }).exec();
    
    // Get active trips for each driver to show current vehicle assignment
    const driversWithVehicles = await Promise.all(
      drivers.map(async (driver) => {
        const activeTrip = await this.tripModel
          .findOne({
            driverId: driver._id,
            status: { $in: [TripStatus.PENDING, TripStatus.IN_PROGRESS] },
          })
          .populate('vehicleId', 'plateNumber make model')
          .exec();
        
        return {
          ...driver.toObject(),
          currentVehicle: activeTrip?.vehicleId || null,
          currentTripId: activeTrip?._id || null,
        };
      })
    );
    
    return driversWithVehicles;
  }

  async findStaff(): Promise<UserDocument[]> {
    return this.userModel.find({ roles: { $in: [UserRole.STAFF] } }).exec();
  }

  async findSupervisorsByDepartment(department: string): Promise<UserDocument[]> {
    return this.userModel.find({ 
      roles: { $in: [UserRole.STAFF] },
      department,
      isSupervisor: true 
    }).exec();
  }

  async update(id: string, updateUserDto: any): Promise<UserDocument> {
    const updateData: any = { ...updateUserDto };

    // If password is being updated, hash it before saving
    // Check for both existence and non-empty string to ensure we only hash when password is actually provided
    if (updateData.password !== undefined && updateData.password !== null && updateData.password !== '') {
      // Only hash if it's not already hashed (bcrypt hashes always start with $2a$, $2b$, or $2y$)
      const passwordStr = String(updateData.password);
      if (!passwordStr.startsWith('$2a$') && !passwordStr.startsWith('$2b$') && !passwordStr.startsWith('$2y$')) {
        console.log(`[UsersService] Hashing password for user ${id}`);
        updateData.password = await bcrypt.hash(passwordStr, 10);
        console.log(`[UsersService] Password hashed successfully for user ${id}`);
      } else {
        console.log(`[UsersService] Password already hashed for user ${id}, skipping re-hash`);
      }
    } else {
      // Remove password from update if it's empty/null/undefined to avoid clearing the password
      console.log(`[UsersService] No password provided in update for user ${id}, keeping existing password`);
      delete updateData.password;
    }

    console.log(`[UsersService] Updating user ${id} with data:`, { ...updateData, password: updateData.password ? '[HIDDEN]' : undefined });

    const user = await this.userModel.findByIdAndUpdate(id, updateData, { new: true }).exec();
    if (!user) {
      throw new NotFoundException('User not found');
    }
    
    // Emit user updated event
    this.eventEmitter.emit('user.updated', new UserUpdatedEvent());
    
    console.log(`[UsersService] User ${id} updated successfully`);
    return user;
  }

  async assignSupervisor(userId: string, supervisorId: string): Promise<UserDocument> {
    return this.update(userId, { supervisorId });
  }

  async delete(id: string): Promise<void> {
    const result = await this.userModel.findByIdAndDelete(id).exec();
    if (!result) {
      throw new NotFoundException('User not found');
    }
  }
}

