import { NestFactory } from '@nestjs/core';
import { AppModule } from '../../app.module';
import { getModelToken } from '@nestjs/mongoose';
import { VehicleRequest, VehicleRequestDocument } from '../../requests/vehicle/schemas/vehicle-request.schema';
import { Model } from 'mongoose';
import { migrateToWorkflow } from './migrate-to-workflow';

async function runMigration() {
  console.log('🚀 Starting workflow migration...\n');

  const app = await NestFactory.createApplicationContext(AppModule);
  
  try {
    const requestModel = app.get<Model<VehicleRequestDocument>>(
      getModelToken(VehicleRequest.name),
    );

    await migrateToWorkflow(requestModel);
    
    console.log('\n✅ Migration completed successfully!');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await app.close();
    process.exit(0);
  }
}

runMigration();

