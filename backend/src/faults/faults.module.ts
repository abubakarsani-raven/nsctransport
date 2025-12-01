import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { FaultsController } from './faults.controller';
import { FaultsService } from './faults.service';
import { FaultReport, FaultReportSchema } from './schemas/fault-report.schema';
import { VehiclesModule } from '../vehicles/vehicles.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: FaultReport.name, schema: FaultReportSchema }]),
    VehiclesModule,
  ],
  controllers: [FaultsController],
  providers: [FaultsService],
  exports: [FaultsService],
})
export class FaultsModule {}

