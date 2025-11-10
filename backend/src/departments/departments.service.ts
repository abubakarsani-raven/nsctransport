import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, isValidObjectId } from 'mongoose';
import { Department, DepartmentDocument } from './schemas/department.schema';

@Injectable()
export class DepartmentsService {
  constructor(
    @InjectModel(Department.name) private departmentModel: Model<DepartmentDocument>,
  ) {}

  async create(createDepartmentDto: { name: string; description?: string }): Promise<DepartmentDocument> {
    const existing = await this.departmentModel.findOne({ name: createDepartmentDto.name }).exec();
    if (existing) {
      throw new BadRequestException('Department with this name already exists');
    }
    const department = new this.departmentModel(createDepartmentDto);
    return department.save();
  }

  async findAll(): Promise<DepartmentDocument[]> {
    return this.departmentModel.find().sort({ name: 1 }).exec();
  }

  async findById(id: string): Promise<DepartmentDocument | null> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new BadRequestException('Invalid department id');
    }
    return this.departmentModel.findById(cleanId).exec();
  }

  async findByName(name: string): Promise<DepartmentDocument | null> {
    return this.departmentModel.findOne({ name }).exec();
  }

  async update(id: string, updateDepartmentDto: { name?: string; description?: string }): Promise<DepartmentDocument> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new BadRequestException('Invalid department id');
    }
    if (updateDepartmentDto.name) {
      const existing = await this.departmentModel.findOne({ 
        name: updateDepartmentDto.name,
        _id: { $ne: cleanId }
      }).exec();
      if (existing) {
        throw new BadRequestException('Department with this name already exists');
      }
    }
    const department = await this.departmentModel.findByIdAndUpdate(cleanId, updateDepartmentDto, { new: true }).exec();
    if (!department) {
      throw new NotFoundException('Department not found');
    }
    return department;
  }

  async delete(id: string): Promise<void> {
    const cleanId = typeof id === 'string' ? id.trim() : id;
    if (!cleanId || !isValidObjectId(cleanId)) {
      throw new BadRequestException('Invalid department id');
    }
    const result = await this.departmentModel.findByIdAndDelete(cleanId).exec();
    if (!result) {
      throw new NotFoundException('Department not found');
    }
  }
}

