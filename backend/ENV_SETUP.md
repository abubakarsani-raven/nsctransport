# Environment Variables Setup

## Required Environment Variables

Create a `.env` file in the `backend/` directory with the following variables:

```env
# Database Configuration
MONGODB_URI=mongodb://localhost:27017/transport_management

# JWT Configuration
JWT_SECRET=your-secret-key-change-in-production
JWT_EXPIRES_IN=7d

# Google Maps API
GOOGLE_MAPS_API_KEY=your-google-maps-api-key

# Firebase Configuration
# Option 1: Use file path (recommended for development)
FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json

# Option 2: Use JSON string (recommended for production/cloud)
# FIREBASE_CREDENTIALS='{"type":"service_account","project_id":"your-project-id",...}'
```

## Getting Firebase Service Account Credentials

See `FIREBASE_SETUP.md` for detailed instructions.

### Quick Steps:
1. Go to Firebase Console → Your Project → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Download the JSON file
4. Save it as `backend/config/firebase-service-account.json`
5. Add to `.env`: `FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json`

