import { Model } from 'mongoose';
import { VehicleRequestDocument } from '../../requests/vehicle/schemas/vehicle-request.schema';

/**
 * Migration script to clean up invalid correctionHistory entries
 * 
 * This script:
 * 1. Finds all requests with correctionHistory
 * 2. Removes entries with invalid or missing requestedBy field
 * 3. Saves the cleaned requests
 */
export async function cleanupCorrectionHistory(
  requestModel: Model<VehicleRequestDocument>,
): Promise<void> {
  console.log('🧹 Starting correction history cleanup...\n');

  // Find all requests with correctionHistory
  const requests = await requestModel
    .find({
      correctionHistory: { $exists: true, $ne: [] },
    })
    .exec();

  console.log(`Found ${requests.length} requests with correction history\n`);

  let cleaned = 0;
  let totalRemoved = 0;
  let errors = 0;

  for (const request of requests) {
    try {
      if (!request.correctionHistory || request.correctionHistory.length === 0) {
        continue;
      }

      const originalLength = request.correctionHistory.length;
      
      // Filter out invalid entries
      const validEntries = request.correctionHistory.filter((entry: any) => {
        if (!entry) {
          return false;
        }

        // Check if requestedBy is valid
        const requestedBy = entry.requestedBy;
        
        // If requestedBy is undefined, null, or empty, remove the entry
        if (!requestedBy) {
          return false;
        }

        // If it's an object (populated), check if it has _id
        if (typeof requestedBy === 'object' && requestedBy !== null) {
          // Check if it's a valid populated object with _id
          if (requestedBy._id !== undefined && requestedBy._id !== null) {
            return true;
          }
          // If it has id instead of _id
          if (requestedBy.id !== undefined && requestedBy.id !== null) {
            return true;
          }
          // If it's an empty object
          return false;
        }

        // If it's a string, check if it's not empty
        if (typeof requestedBy === 'string') {
          return requestedBy.trim().length > 0;
        }

        // If it's a number (ObjectId as number - shouldn't happen but handle it)
        if (typeof requestedBy === 'number') {
          return true;
        }

        // Otherwise, it's invalid
        return false;
      });

      // If we removed any entries, update the request
      if (validEntries.length < originalLength) {
        const removedCount = originalLength - validEntries.length;
        request.correctionHistory = validEntries;
        request.markModified('correctionHistory');
        
        await request.save();
        
        cleaned++;
        totalRemoved += removedCount;
        
        console.log(
          `✅ Request ${request._id}: Removed ${removedCount} invalid entry/entries (${originalLength} → ${validEntries.length})`,
        );
      }
    } catch (error) {
      errors++;
      console.error(`❌ Error cleaning request ${request._id}:`, error);
    }
  }

  console.log('\n📊 Cleanup Summary:');
  console.log(`   Requests cleaned: ${cleaned}`);
  console.log(`   Total invalid entries removed: ${totalRemoved}`);
  console.log(`   Errors: ${errors}`);
  console.log('\n✅ Correction history cleanup completed!');
}





