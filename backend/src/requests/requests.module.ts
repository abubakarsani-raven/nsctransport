import { Module } from '@nestjs/common';
import { RequestsController } from './requests.controller';
import { VehicleRequestsModule } from './vehicle/vehicle-request.module';
import { IctRequestsModule } from './ict/ict-request.module';
import { StoreRequestsModule } from './store/store-request.module';

/**
 * Legacy RequestsModule - delegates to VehicleRequestsModule for backward compatibility
 * All /requests endpoints now redirect to vehicle requests
 * History endpoint combines all request types
 */
@Module({
  imports: [VehicleRequestsModule, IctRequestsModule, StoreRequestsModule],
  controllers: [RequestsController],
  exports: [VehicleRequestsModule],
})
export class RequestsModule {}

