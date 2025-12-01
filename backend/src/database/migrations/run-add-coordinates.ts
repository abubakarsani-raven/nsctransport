import { NestFactory } from '@nestjs/core';
import { AppModule } from '../../app.module';
import { getModelToken } from '@nestjs/mongoose';
import { VehicleRequest, VehicleRequestDocument } from '../../requests/vehicle/schemas/vehicle-request.schema';
import { Model } from 'mongoose';
import { addCoordinatesToRequests } from './add-coordinates-to-requests';

async function runAddCoordinates() {
  console.log('🚀 Starting coordinates migration...\n');

  const app = await NestFactory.createApplicationContext(AppModule);
  
  try {
    const requestModel = app.get<Model<VehicleRequestDocument>>(
      getModelToken(VehicleRequest.name),
    );

    await addCoordinatesToRequests(requestModel);
    
    console.log('\n✅ Coordinates migration completed successfully!');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await app.close();
    process.exit(0);
  }
}

runAddCoordinates();

