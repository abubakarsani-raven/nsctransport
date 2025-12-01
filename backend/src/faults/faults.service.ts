import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, isValidObjectId } from 'mongoose';
import { FaultReport, FaultReportDocument, FaultStatus } from './schemas/fault-report.schema';
import { CreateFaultReportDto } from './dto/create-fault-report.dto';
import { UpdateFaultReportDto } from './dto/update-fault-report.dto';
import { VehiclesService } from '../vehicles/vehicles.service';

@Injectable()
export class FaultsService {
  constructor(
    @InjectModel(FaultReport.name) private faultReportModel: Model<FaultReportDocument>,
    private vehiclesService: VehiclesService,
  ) {}

  async create(createDto: CreateFaultReportDto, reportedBy: string): Promise<FaultReportDocument> {
    if (!isValidObjectId(createDto.vehicleId)) {
      throw new BadRequestException('Invalid vehicle ID');
    }

    const vehicle = await this.vehiclesService.findById(createDto.vehicleId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    const faultReport = new this.faultReportModel({
      ...createDto,
      reportedBy,
    });

    return faultReport.save();
  }

  async findAll(): Promise<FaultReportDocument[]> {
    return this.faultReportModel
      .find()
      .populate('vehicleId', 'plateNumber make model')
      .populate('reportedBy', 'name email')
      .populate('resolvedBy', 'name email')
      .sort({ createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<FaultReportDocument | null> {
    if (!isValidObjectId(id)) {
      return null;
    }
    return this.faultReportModel
      .findById(id)
      .populate('vehicleId', 'plateNumber make model')
      .populate('reportedBy', 'name email')
      .populate('resolvedBy', 'name email')
      .exec();
  }

  async findByVehicle(vehicleId: string): Promise<FaultReportDocument[]> {
    if (!isValidObjectId(vehicleId)) {
      throw new BadRequestException('Invalid vehicle ID');
    }
    return this.faultReportModel
      .find({ vehicleId })
      .populate('reportedBy', 'name email')
      .populate('resolvedBy', 'name email')
      .sort({ createdAt: -1 })
      .exec();
  }

  async findByReporter(reportedBy: string): Promise<FaultReportDocument[]> {
    if (!isValidObjectId(reportedBy)) {
      throw new BadRequestException('Invalid user ID');
    }
    return this.faultReportModel
      .find({ reportedBy })
      .populate('vehicleId', 'plateNumber make model')
      .populate('resolvedBy', 'name email')
      .sort({ createdAt: -1 })
      .exec();
  }

  async update(id: string, updateDto: UpdateFaultReportDto, updatedBy?: string): Promise<FaultReportDocument> {
    const faultReport = await this.findById(id);
    if (!faultReport) {
      throw new NotFoundException('Fault report not found');
    }

    if (updateDto.status === FaultStatus.RESOLVED || updateDto.status === FaultStatus.CLOSED) {
      faultReport.resolvedAt = new Date();
      if (updatedBy) {
        faultReport.resolvedBy = updatedBy;
      }
    }

    if (updateDto.resolutionNotes) {
      faultReport.resolutionNotes = updateDto.resolutionNotes;
    }

    if (updateDto.status) {
      faultReport.status = updateDto.status;
    }

    return faultReport.save();
  }

  async delete(id: string): Promise<void> {
    const result = await this.faultReportModel.deleteOne({ _id: id }).exec();
    if (result.deletedCount === 0) {
      throw new NotFoundException('Fault report not found');
    }
  }
}

