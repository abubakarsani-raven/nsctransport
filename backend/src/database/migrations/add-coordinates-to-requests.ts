import { Model } from 'mongoose';
import { VehicleRequestDocument } from '../../requests/vehicle/schemas/vehicle-request.schema';

/**
 * Migration script to add coordinates field to existing vehicle requests
 * 
 * This script:
 * 1. Finds all vehicle requests
 * 2. For requests with destinationCoordinates but no coordinates, sets coordinates to destinationCoordinates
 * 3. For requests with coordinates but no destinationCoordinates, sets destinationCoordinates to coordinates
 * 4. Ensures both fields are synchronized
 */
export async function addCoordinatesToRequests(
  requestModel: Model<VehicleRequestDocument>,
): Promise<void> {
  console.log('🚀 Starting coordinates migration...\n');

  // Find all requests
  const requests = await requestModel.find({}).exec();
  console.log(`Found ${requests.length} vehicle requests to process\n`);

  let updated = 0;
  let skipped = 0;
  let errors = 0;

  for (const request of requests) {
    try {
      let needsUpdate = false;

      // Case 1: Has destinationCoordinates but no coordinates
      if (request.destinationCoordinates && !request.coordinates) {
        (request as any).coordinates = request.destinationCoordinates;
        needsUpdate = true;
        console.log(`✅ Request ${request._id}: Setting coordinates from destinationCoordinates`);
      }
      // Case 2: Has coordinates but no destinationCoordinates
      else if (request.coordinates && !request.destinationCoordinates) {
        (request as any).destinationCoordinates = request.coordinates;
        needsUpdate = true;
        console.log(`✅ Request ${request._id}: Setting destinationCoordinates from coordinates`);
      }
      // Case 3: Has both but they're different (sync them)
      else if (
        request.destinationCoordinates &&
        request.coordinates &&
        (request.destinationCoordinates.lat !== request.coordinates.lat ||
          request.destinationCoordinates.lng !== request.coordinates.lng)
      ) {
        // Use destinationCoordinates as the source of truth
        (request as any).coordinates = request.destinationCoordinates;
        needsUpdate = true;
        console.log(
          `🔄 Request ${request._id}: Syncing coordinates to match destinationCoordinates`,
        );
      }
      // Case 4: Has neither - skip (no coordinates to add)
      else if (!request.destinationCoordinates && !request.coordinates) {
        skipped++;
        continue;
      }
      // Case 5: Both exist and match - no update needed
      else {
        skipped++;
        continue;
      }

      if (needsUpdate) {
        request.markModified('coordinates');
        request.markModified('destinationCoordinates');
        await request.save();
        updated++;
      }

      if ((updated + skipped) % 100 === 0) {
        console.log(`Progress: ${updated} updated, ${skipped} skipped...`);
      }
    } catch (error) {
      console.error(`❌ Error processing request ${request._id}:`, error);
      errors++;
    }
  }

  console.log('\n📊 Migration Summary:');
  console.log(`   ✅ Updated: ${updated}`);
  console.log(`   ⏭️  Skipped: ${skipped}`);
  console.log(`   ❌ Errors: ${errors}`);
  console.log(`   📝 Total: ${requests.length}\n`);
}

