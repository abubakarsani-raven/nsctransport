import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { OfficesService } from './offices.service';
import { OfficesController } from './offices.controller';
import { Office, OfficeSchema } from './schemas/office.schema';

@Module({
  imports: [MongooseModule.forFeature([{ name: Office.name, schema: OfficeSchema }])],
  controllers: [OfficesController],
  providers: [OfficesService],
  exports: [OfficesService],
})
export class OfficesModule {}

