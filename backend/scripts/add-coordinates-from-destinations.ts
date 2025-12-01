/**
 * Script to add coordinates to existing vehicle requests by geocoding destination addresses
 * 
 * This script:
 * 1. Fetches all vehicle requests without coordinates
 * 2. Uses Google Maps Geocoding API to get coordinates from destination addresses
 * 3. Updates requests with the geocoded coordinates
 * 
 * Usage:
 * 1. Make sure GOOGLE_MAPS_API_KEY is set in your environment
 * 2. Run: ts-node -r tsconfig-paths/register scripts/add-coordinates-from-destinations.ts
 */

import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { getModelToken } from '@nestjs/mongoose';
import { VehicleRequest, VehicleRequestDocument } from '../src/requests/vehicle/schemas/vehicle-request.schema';
import { Model } from 'mongoose';
import { MapsService } from '../src/maps/maps.service';
import { ConfigService } from '@nestjs/config';

async function addCoordinatesFromDestinations() {
  console.log('🚀 Starting to add coordinates from destination addresses...\n');

  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const requestModel = app.get<Model<VehicleRequestDocument>>(
      getModelToken(VehicleRequest.name),
    );
    const mapsService = app.get(MapsService);
    const configService = app.get(ConfigService);

    // Check if Google Maps API key is configured
    const apiKey = configService.get<string>('GOOGLE_MAPS_API_KEY');
    if (!apiKey) {
      console.error('❌ Error: GOOGLE_MAPS_API_KEY is not configured');
      console.log('Please set GOOGLE_MAPS_API_KEY in your environment variables');
      process.exit(1);
    }

    // Find all requests without coordinates
    const requests = await requestModel
      .find({
        $or: [
          { coordinates: { $exists: false } },
          { coordinates: null },
          { destinationCoordinates: { $exists: false } },
          { destinationCoordinates: null },
        ],
      })
      .exec();

    console.log(`Found ${requests.length} requests without coordinates\n`);

    if (requests.length === 0) {
      console.log('✅ All requests already have coordinates!');
      return;
    }

    let updated = 0;
    let failed = 0;
    const errors: Array<{ requestId: string; error: string }> = [];

    for (const request of requests) {
      try {
        if (!request.destination) {
          console.log(`⏭️  Skipping request ${request._id}: No destination address`);
          continue;
        }

        console.log(`📍 Geocoding destination for request ${request._id}: ${request.destination}`);

        // Geocode the destination address using MapsService
        const geocodedCoordinates = await mapsService.geocodeAddress(request.destination);

        // Update both coordinates and destinationCoordinates
        (request as any).coordinates = geocodedCoordinates;
        (request as any).destinationCoordinates = geocodedCoordinates;

        request.markModified('coordinates');
        request.markModified('destinationCoordinates');
        await request.save();

        updated++;
        console.log(
          `✅ Updated request ${request._id} with coordinates: ${geocodedCoordinates.lat}, ${geocodedCoordinates.lng}`,
        );

        // Add a small delay to avoid rate limiting
        await new Promise((resolve) => setTimeout(resolve, 100));
      } catch (error) {
        failed++;
        const errorMessage = error instanceof Error ? error.message : String(error);
        errors.push({
          requestId: String(request._id),
          error: errorMessage,
        });
        console.error(`❌ Error processing request ${request._id}:`, errorMessage);
      }
    }

    console.log('\n📊 Migration Summary:');
    console.log(`   ✅ Updated: ${updated}`);
    console.log(`   ❌ Failed: ${failed}`);
    if (errors.length > 0) {
      console.log('\n❌ Errors:');
      errors.forEach((error) => {
        console.log(`   - Request ${error.requestId}: ${error.error}`);
      });
    }
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await app.close();
    process.exit(0);
  }
}


// Run the script
addCoordinatesFromDestinations();

