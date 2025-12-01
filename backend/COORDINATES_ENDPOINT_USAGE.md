# Coordinates Endpoint Usage Guide

This document provides curl commands for adding coordinates to vehicle requests.

## Prerequisites

1. You need a valid JWT token from authentication
2. Your user must have `ADMIN` or `TRANSPORT_OFFICER` role
3. The backend server should be running (default: http://localhost:3000)

## Getting Your Auth Token

First, authenticate and get your token:

```bash
# Login to get JWT token
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-email@example.com",
    "password": "your-password"
  }'
```

Copy the `access_token` from the response.

## Endpoints

### 1. Add Coordinates to a Single Vehicle Request

**Endpoint:** `PATCH /requests/vehicle/add-coordinates`

**Description:** Adds coordinates to a single existing vehicle request. This will automatically set both `coordinates` and `destinationCoordinates` fields to the same value.

**Request Body:**
```json
{
  "requestId": "vehicle-request-id-here",
  "coordinates": {
    "lat": 9.0579,
    "lng": 7.4951
  }
}
```

**curl Command:**
```bash
curl -X PATCH http://localhost:3000/requests/vehicle/add-coordinates \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -d '{
    "requestId": "65a1b2c3d4e5f6a7b8c9d0e1",
    "coordinates": {
      "lat": 9.0579,
      "lng": 7.4951
    }
  }'
```

**Example with real values:**
```bash
curl -X PATCH http://localhost:3000/requests/vehicle/add-coordinates \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -d '{
    "requestId": "65a1b2c3d4e5f6a7b8c9d0e1",
    "coordinates": {
      "lat": 9.0579,
      "lng": 7.4951
    }
  }'
```

**Success Response:**
```json
{
  "_id": "65a1b2c3d4e5f6a7b8c9d0e1",
  "requesterId": "...",
  "destination": "Abuja",
  "coordinates": {
    "lat": 9.0579,
    "lng": 7.4951
  },
  "destinationCoordinates": {
    "lat": 9.0579,
    "lng": 7.4951
  },
  ...
}
```

**Note:** This endpoint automatically sets both `coordinates` and `destinationCoordinates` to the same value, ensuring consistency.

### 2. Batch Add Coordinates to Multiple Vehicle Requests

**Endpoint:** `PATCH /requests/vehicle/batch-add-coordinates`

**Description:** Adds coordinates to multiple vehicle requests in a single request.

**Request Body:**
```json
{
  "requests": [
    {
      "requestId": "65a1b2c3d4e5f6a7b8c9d0e1",
      "coordinates": {
        "lat": 9.0579,
        "lng": 7.4951
      }
    },
    {
      "requestId": "65a1b2c3d4e5f6a7b8c9d0e2",
      "coordinates": {
        "lat": 6.5244,
        "lng": 3.3792
      }
    }
  ]
}
```

**curl Command:**
```bash
curl -X PATCH http://localhost:3000/requests/vehicle/batch-add-coordinates \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -d '{
    "requests": [
      {
        "requestId": "65a1b2c3d4e5f6a7b8c9d0e1",
        "coordinates": {
          "lat": 9.0579,
          "lng": 7.4951
        }
      },
      {
        "requestId": "65a1b2c3d4e5f6a7b8c9d0e2",
        "coordinates": {
          "lat": 6.5244,
          "lng": 3.3792
        }
      }
    ]
  }'
```

**Success Response:**
```json
{
  "success": 2,
  "failed": 0,
  "errors": []
}
```

**Partial Success Response:**
```json
{
  "success": 1,
  "failed": 1,
  "errors": [
    {
      "requestId": "65a1b2c3d4e5f6a7b8c9d0e2",
      "error": "Vehicle request not found"
    }
  ]
}
```

## Updating Coordinates via Update Endpoint

You can also update coordinates when updating a vehicle request (when the request is in "needs_correction" or "rejected" status). When you update `destinationCoordinates` or `coordinates`, both fields will be automatically synchronized:

**Endpoint:** `PUT /requests/vehicle/:id`

**curl Command (using destinationCoordinates - recommended):**
```bash
curl -X PUT http://localhost:3000/requests/vehicle/65a1b2c3d4e5f6a7b8c9d0e1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -d '{
    "destinationCoordinates": {
      "lat": 9.0579,
      "lng": 7.4951
    },
    "destination": "Updated Destination"
  }'
```

**Or using coordinates:**
```bash
curl -X PUT http://localhost:3000/requests/vehicle/65a1b2c3d4e5f6a7b8c9d0e1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -d '{
    "coordinates": {
      "lat": 9.0579,
      "lng": 7.4951
    },
    "destination": "Updated Destination"
  }'
```

**Note:** Both `destinationCoordinates` and `coordinates` will be set to the same value automatically.

## Creating a New Vehicle Request with Coordinates

When creating a new vehicle request, you can include `destinationCoordinates` and it will automatically be saved to both `destinationCoordinates` and `coordinates` fields:

**Endpoint:** `POST /requests/vehicle`

**curl Command (Recommended - using destinationCoordinates):**
```bash
curl -X POST http://localhost:3000/requests/vehicle \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -d '{
    "originOffice": "65a1b2c3d4e5f6a7b8c9d0e1",
    "destination": "Abuja",
    "destinationCoordinates": {
      "lat": 9.0579,
      "lng": 7.4951
    },
    "startDate": "2024-12-20T10:00:00Z",
    "endDate": "2024-12-20T18:00:00Z",
    "purpose": "Meeting",
    "passengerCount": 2
  }'
```

**Note:** When you provide `destinationCoordinates`, it automatically sets the `coordinates` field to the same value. Alternatively, you can provide only `coordinates` and it will set both fields.

## Creating a New Vehicle with Coordinates

When creating a new vehicle, you can include officeLocation coordinates:

**Endpoint:** `POST /vehicles`

**curl Command:**
```bash
curl -X POST http://localhost:3000/vehicles \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -d '{
    "plateNumber": "ABC-123",
    "make": "Toyota",
    "model": "Camry",
    "year": 2023,
    "capacity": 5,
    "officeLocation": {
      "lat": 9.0579,
      "lng": 7.4951
    }
  }'
```

## Using Environment Variables

For production or different environments, you can use environment variables:

```bash
# Set your base URL
export API_BASE_URL="http://localhost:3000"
export JWT_TOKEN="your-jwt-token-here"

# Then use in curl commands
curl -X PATCH ${API_BASE_URL}/requests/vehicle/add-coordinates \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -d '{
    "requestId": "65a1b2c3d4e5f6a7b8c9d0e1",
    "coordinates": {
      "lat": 9.0579,
      "lng": 7.4951
    }
  }'
```

## Common Coordinate Examples (Nigeria)

- **Lagos**: `{"lat": 6.5244, "lng": 3.3792}`
- **Abuja**: `{"lat": 9.0579, "lng": 7.4951}`
- **Kano**: `{"lat": 12.0022, "lng": 8.5919}`
- **Port Harcourt**: `{"lat": 4.8156, "lng": 7.0498}`
- **Ibadan**: `{"lat": 7.3775, "lng": 3.9470}`

## Error Handling

### Invalid Request ID
```json
{
  "statusCode": 404,
  "message": "Vehicle request not found",
  "error": "Not Found"
}
```

### Missing Authorization
```json
{
  "statusCode": 401,
  "message": "Unauthorized"
}
```

### Insufficient Permissions
```json
{
  "statusCode": 403,
  "message": "Forbidden resource"
}
```

### Invalid Coordinates Format
```json
{
  "statusCode": 400,
  "message": ["coordinates.lat must be a number", "coordinates.lng must be a number"]
}
```

## Notes

- These endpoints are **TEMPORARY** and should be removed after migration is complete
- The `coordinates` field is automatically synchronized with `destinationCoordinates`
- When creating or updating requests:
  - If you provide `destinationCoordinates`, it automatically sets `coordinates` to the same value
  - If you provide only `coordinates`, it automatically sets `destinationCoordinates` to the same value
  - This ensures both fields always have the destination coordinates
- Coordinates should be in decimal degrees format (WGS84)
- Latitude range: -90 to 90
- Longitude range: -180 to 180
- The temporary endpoints require ADMIN or TRANSPORT_OFFICER role

## Migration Scripts

### Option 1: Database Migration Script (Recommended)

Run the migration script to automatically sync coordinates for all existing requests:

```bash
cd backend
npm run migrate:add-coordinates
```

This script will:
- Find all vehicle requests
- For requests with `destinationCoordinates` but no `coordinates`, set `coordinates` to match
- For requests with `coordinates` but no `destinationCoordinates`, set `destinationCoordinates` to match
- Sync both fields if they're different

### Option 2: API Endpoint Script

If you have specific request IDs and coordinates, you can use the API script:

```bash
# Set your JWT token
export JWT_TOKEN="your-jwt-token-here"
export API_BASE_URL="http://localhost:3000"

# Edit the script to add your request IDs and coordinates
ts-node -r tsconfig-paths/register scripts/add-coordinates-via-api.ts
```

### Option 3: Geocode Destinations (Requires Google Maps API Key)

If you want to automatically geocode destination addresses:

```bash
# Make sure GOOGLE_MAPS_API_KEY is set
export GOOGLE_MAPS_API_KEY="your-api-key"

# Run the geocoding script
ts-node -r tsconfig-paths/register scripts/add-coordinates-from-destinations.ts
```

## Cleanup

After migration is complete, remember to:
1. Remove the temporary endpoints from the controller
2. Remove the temporary methods from the service
3. Update this documentation or remove it

