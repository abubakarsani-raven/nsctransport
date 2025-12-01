/**
 * Script to add coordinates to existing vehicle requests via API endpoint
 * 
 * Usage:
 * 1. Set your API base URL and JWT token
 * 2. Provide request IDs and coordinates in the requests array
 * 3. Run: ts-node -r tsconfig-paths/register scripts/add-coordinates-via-api.ts
 * 
 * Or use the batch endpoint for multiple requests
 */

const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000';
const JWT_TOKEN = process.env.JWT_TOKEN || '';

// Example: Add coordinates for specific requests
const requests = [
  {
    requestId: 'REQUEST_ID_1',
    coordinates: { lat: 9.0579, lng: 7.4951 }, // Abuja coordinates
  },
  {
    requestId: 'REQUEST_ID_2',
    coordinates: { lat: 6.5244, lng: 3.3792 }, // Lagos coordinates
  },
  // Add more requests as needed
];

async function addCoordinates() {
  if (!JWT_TOKEN) {
    console.error('❌ Error: JWT_TOKEN environment variable is required');
    console.log('Please set JWT_TOKEN=your_token_here');
    process.exit(1);
  }

  console.log('🚀 Starting to add coordinates to vehicle requests...\n');
  console.log(`Using API: ${API_BASE_URL}\n`);

  // Use batch endpoint for multiple requests
  if (requests.length > 1) {
    try {
      const response = await fetch(`${API_BASE_URL}/requests/vehicle/batch-add-coordinates`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${JWT_TOKEN}`,
        },
        body: JSON.stringify({ requests }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(JSON.stringify(error));
      }

      const result = await response.json();
      console.log('📊 Batch Update Results:');
      console.log(`   ✅ Success: ${result.success}`);
      console.log(`   ❌ Failed: ${result.failed}`);
      if (result.errors && result.errors.length > 0) {
        console.log('\n❌ Errors:');
        result.errors.forEach((error: any) => {
          console.log(`   - Request ${error.requestId}: ${error.error}`);
        });
      }
    } catch (error) {
      console.error('❌ Error adding coordinates:', error);
      process.exit(1);
    }
  } else if (requests.length === 1) {
    // Use single endpoint for one request
    try {
      const request = requests[0];
      const response = await fetch(`${API_BASE_URL}/requests/vehicle/add-coordinates`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${JWT_TOKEN}`,
        },
        body: JSON.stringify({
          requestId: request.requestId,
          coordinates: request.coordinates,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(JSON.stringify(error));
      }

      const result = await response.json();
      console.log('✅ Successfully added coordinates to request:', result._id);
      console.log('Coordinates:', result.coordinates);
    } catch (error) {
      console.error('❌ Error adding coordinates:', error);
      process.exit(1);
    }
  } else {
    console.log('⚠️  No requests to process. Please add request IDs and coordinates to the script.');
  }
}

// Run the script
addCoordinates();

