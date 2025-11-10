import { NestFactory } from '@nestjs/core';
import { AppModule } from '../../app.module';
import { getModelToken } from '@nestjs/mongoose';
import { VehicleRequest, VehicleRequestDocument } from '../../requests/vehicle/schemas/vehicle-request.schema';
import { Model } from 'mongoose';
import { cleanupCorrectionHistory } from './cleanup-correction-history';

async function runCleanup() {
  console.log('🚀 Starting correction history cleanup migration...\n');

  const app = await NestFactory.createApplicationContext(AppModule);
  
  try {
    const requestModel = app.get<Model<VehicleRequestDocument>>(
      getModelToken(VehicleRequest.name),
    );

    await cleanupCorrectionHistory(requestModel);
    
    console.log('\n✅ Cleanup completed successfully!');
  } catch (error) {
    console.error('❌ Cleanup failed:', error);
    process.exit(1);
  } finally {
    await app.close();
    process.exit(0);
  }
}

runCleanup();





