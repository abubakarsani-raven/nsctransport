# Coordinates Migration - Complete

## ✅ Migration Status

The coordinates migration has been successfully set up and run. Here's what was accomplished:

### 1. Database Migration Script
- ✅ Created migration script: `src/database/migrations/add-coordinates-to-requests.ts`
- ✅ Created runner script: `src/database/migrations/run-add-coordinates.ts`
- ✅ Added npm script: `npm run migrate:add-coordinates`

### 2. API Endpoints
- ✅ Created temporary endpoint: `PATCH /requests/vehicle/add-coordinates`
- ✅ Created batch endpoint: `PATCH /requests/vehicle/batch-add-coordinates`
- ✅ Both endpoints require ADMIN or TRANSPORT_OFFICER role

### 3. Automatic Synchronization
- ✅ When creating requests with `destinationCoordinates`, `coordinates` is automatically set
- ✅ When updating requests, both fields are synchronized
- ✅ Distance calculation uses either field

### 4. Migration Results
- **Total requests found**: 5
- **Updated**: 0
- **Skipped**: 5
- **Errors**: 0

**Note**: All requests were skipped because they either:
- Already have both `coordinates` and `destinationCoordinates` set and matching
- Don't have `destinationCoordinates` to copy from

## Next Steps

### Option 1: Add Coordinates Manually via API

If you have specific coordinates for requests, use the API endpoint:

```bash
# 1. Get your JWT token
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-email@example.com",
    "password": "your-password"
  }'

# 2. Add coordinates to a request
curl -X PATCH http://localhost:3000/requests/vehicle/add-coordinates \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "requestId": "REQUEST_ID_HERE",
    "coordinates": {
      "lat": 9.0579,
      "lng": 7.4951
    }
  }'
```

### Option 2: Geocode Destinations Automatically

If you want to automatically geocode destination addresses:

```bash
# Make sure GOOGLE_MAPS_API_KEY is set in your .env file
# Then run:
ts-node -r tsconfig-paths/register scripts/add-coordinates-from-destinations.ts
```

This will:
- Find all requests without coordinates
- Geocode their destination addresses
- Update both `coordinates` and `destinationCoordinates` fields

### Option 3: Batch Update Multiple Requests

```bash
curl -X PATCH http://localhost:3000/requests/vehicle/batch-add-coordinates \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "requests": [
      {
        "requestId": "REQUEST_ID_1",
        "coordinates": {"lat": 9.0579, "lng": 7.4951}
      },
      {
        "requestId": "REQUEST_ID_2",
        "coordinates": {"lat": 6.5244, "lng": 3.3792}
      }
    ]
  }'
```

## Files Created

1. **Migration Scripts**:
   - `backend/src/database/migrations/add-coordinates-to-requests.ts`
   - `backend/src/database/migrations/run-add-coordinates.ts`

2. **API Scripts**:
   - `backend/scripts/add-coordinates-via-api.ts`
   - `backend/scripts/add-coordinates-from-destinations.ts`

3. **Documentation**:
   - `backend/COORDINATES_ENDPOINT_USAGE.md`
   - `backend/COORDINATES_MIGRATION_COMPLETE.md` (this file)

## Testing

To test the endpoints, you can use the curl commands in `COORDINATES_ENDPOINT_USAGE.md` or run the migration script again:

```bash
npm run migrate:add-coordinates
```

## Cleanup (After Migration)

Once all requests have coordinates, you can:

1. Remove the temporary endpoints from `vehicle-request.controller.ts`
2. Remove the temporary methods from `vehicle-request.service.ts`
3. Remove the migration scripts (optional, you may want to keep them for reference)
4. Update or remove this documentation

## Common Coordinate Examples (Nigeria)

- **Lagos**: `{"lat": 6.5244, "lng": 3.3792}`
- **Abuja**: `{"lat": 9.0579, "lng": 7.4951}`
- **Kano**: `{"lat": 12.0022, "lng": 8.5919}`
- **Port Harcourt**: `{"lat": 4.8156, "lng": 7.0498}`
- **Ibadan**: `{"lat": 7.3775, "lng": 3.9470}`

