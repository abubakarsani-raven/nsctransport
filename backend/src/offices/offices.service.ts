import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Office, OfficeDocument } from './schemas/office.schema';

@Injectable()
export class OfficesService {
  constructor(@InjectModel(Office.name) private officeModel: Model<OfficeDocument>) {}

  async create(createOfficeDto: any): Promise<OfficeDocument> {
    const createdOffice = new this.officeModel(createOfficeDto);
    return createdOffice.save();
  }

  async findAll(): Promise<OfficeDocument[]> {
    return this.officeModel.find().exec();
  }

  async findById(id: string): Promise<OfficeDocument | null> {
    return this.officeModel.findById(id).exec();
  }

  async update(id: string, updateOfficeDto: any): Promise<OfficeDocument> {
    const office = await this.officeModel.findByIdAndUpdate(id, updateOfficeDto, { new: true }).exec();
    if (!office) {
      throw new NotFoundException('Office not found');
    }
    return office;
  }

  async delete(id: string): Promise<void> {
    const result = await this.officeModel.findByIdAndDelete(id).exec();
    if (!result) {
      throw new NotFoundException('Office not found');
    }
  }
}

