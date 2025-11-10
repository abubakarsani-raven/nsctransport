# Firebase Setup Guide for Backend

This guide explains how to get Firebase service account credentials and configure them in the backend.

## Step 1: Get Firebase Service Account Key

### Option A: From Firebase Console (Recommended)

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Select your project: **nova-25aa2** (or your project name)

2. **Navigate to Project Settings**
   - Click the gear icon ⚙️ next to "Project Overview"
   - Select "Project settings"

3. **Go to Service Accounts Tab**
   - Click on the "Service accounts" tab
   - You'll see options for Firebase Admin SDK

4. **Generate New Private Key**
   - Click "Generate new private key" button
   - A dialog will appear warning you to keep the key secure
   - Click "Generate key"
   - A JSON file will be downloaded (e.g., `nova-25aa2-firebase-adminsdk-xxxxx.json`)

5. **Save the JSON File**
   - Save this file in a secure location
   - **Recommended location**: `backend/config/firebase-service-account.json`
   - **IMPORTANT**: Add this file to `.gitignore` to avoid committing it to version control

## Step 2: Configure Backend .env File

You have **two options** to configure the credentials:

### Option 1: Using File Path (Recommended for Development)

1. **Place the JSON file in backend directory**
   ```
   backend/
   ├── config/
   │   └── firebase-service-account.json  (your downloaded file)
   ├── .env
   └── ...
   ```

2. **Add to backend/.env file**:
   ```env
   FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json
   ```

   Or if you placed it in the root:
   ```env
   FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
   ```

### Option 2: Using JSON String (Recommended for Production/Cloud)

1. **Copy the entire JSON content** from the downloaded file

2. **Add to backend/.env file** as a single line (or use proper JSON escaping):
   ```env
   FIREBASE_CREDENTIALS='{"type":"service_account","project_id":"nova-25aa2","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}'
   ```

   **Note**: For multi-line JSON in .env, you may need to:
   - Remove all newlines and escape quotes properly
   - Or use a tool to convert JSON to a single-line string

## Step 3: Update .gitignore

Make sure your `backend/.gitignore` includes:
```
# Firebase service account
firebase-service-account.json
config/firebase-service-account.json
*.json
!package.json
!package-lock.json
!tsconfig.json
```

## Step 4: Verify Configuration

1. **Start your backend server**:
   ```bash
   cd backend
   npm run start:dev
   ```

2. **Check the logs** for:
   - ✅ `Firebase Admin initialized with service account file` (if using file path)
   - ✅ `Firebase Admin initialized with credentials from environment` (if using JSON string)
   - ❌ `Firebase credentials not found. Push notifications will be disabled.` (if not configured)

## Troubleshooting

### Error: "Cannot find module"
- Make sure the file path in `FIREBASE_SERVICE_ACCOUNT_PATH` is correct
- Use relative path from the backend directory
- Check that the file exists

### Error: "Invalid credentials"
- Verify the JSON file is valid
- Make sure you downloaded the correct service account key
- Check that the project ID matches your Firebase project

### Error: "Permission denied"
- Ensure the service account has the necessary permissions
- In Firebase Console, make sure the service account has "Firebase Cloud Messaging API" enabled
- Check IAM permissions in Google Cloud Console if needed

## Security Best Practices

1. **Never commit** the service account JSON file to version control
2. **Use environment variables** in production (preferably FIREBASE_CREDENTIALS)
3. **Restrict file permissions** on the service account file (chmod 600)
4. **Rotate keys** periodically for security
5. **Use different keys** for development and production

## Example .env File

```env
# Database
MONGODB_URI=mongodb://localhost:27017/transport_management

# JWT
JWT_SECRET=your-secret-key-change-in-production
JWT_EXPIRES_IN=7d

# Google Maps
GOOGLE_MAPS_API_KEY=your-google-maps-api-key

# Firebase (choose one option)
# Option 1: File path
FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json

# Option 2: JSON string (uncomment and use this for production)
# FIREBASE_CREDENTIALS='{"type":"service_account",...}'
```

## Next Steps

After configuring Firebase credentials:
1. Restart your backend server
2. Test FCM by creating a request and checking if participants receive push notifications
3. Verify device tokens are being registered when users log in
4. Check backend logs for FCM initialization and notification sending

