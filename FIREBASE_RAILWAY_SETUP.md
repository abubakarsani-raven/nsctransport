# Firebase Setup for Railway Deployment

## Problem
When deploying to Railway, you might see this error:
```
Firebase service account file not found at: /app/config/firebase-service-account.json
Push notifications will be disabled
```

This happens because Railway doesn't have access to local files. You need to use environment variables instead.

## Solution: Use FIREBASE_CREDENTIALS Environment Variable

### Step 1: Get Firebase Service Account JSON

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** → **Service Accounts** tab
4. Click **"Generate new private key"**
5. Download the JSON file (e.g., `your-project-firebase-adminsdk-xxxxx.json`)

### Step 2: Convert JSON to Single Line String

You have two options:

#### Option A: Copy JSON Content (Recommended)

1. Open the downloaded JSON file in a text editor
2. Copy the **entire content** of the JSON file
3. Remove all line breaks and format as a single line
4. Escape any quotes if needed (though usually not necessary)

Example format:
```json
{"type":"service_account","project_id":"your-project-id","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"..."}
```

#### Option B: Use Online Tool

1. Go to a JSON minifier tool (e.g., https://www.jsonformatter.org/json-minify)
2. Paste your JSON file content
3. Click "Minify" to convert to single line
4. Copy the minified JSON

### Step 3: Set FIREBASE_CREDENTIALS in Railway

1. Go to your Railway project dashboard
2. Click on your backend service
3. Go to **Variables** tab
4. Click **"+ New Variable"**
5. Set:
   - **Variable Name**: `FIREBASE_CREDENTIALS`
   - **Value**: Paste the entire JSON as a single line (from Step 2)
6. Click **"Add"**
7. Railway will automatically redeploy

### Step 4: Verify

After deployment, check the Railway logs. You should see:
```
Firebase Admin initialized with credentials from FIREBASE_CREDENTIALS environment variable
```

Instead of:
```
Firebase service account file not found
```

## Important Notes

### ✅ DO:
- Use `FIREBASE_CREDENTIALS` environment variable in Railway
- Copy the entire JSON content as a single line
- Keep the JSON properly formatted (valid JSON syntax)
- Test push notifications after deployment

### ❌ DON'T:
- Don't set `FIREBASE_SERVICE_ACCOUNT_PATH` in Railway (only for local development)
- Don't commit the Firebase service account JSON file to git
- Don't use file paths in cloud deployments
- Don't break the JSON syntax when converting to single line

## Troubleshooting

### Error: "Failed to parse FIREBASE_CREDENTIALS JSON"

**Solution**: 
- Verify the JSON is valid (use a JSON validator)
- Ensure it's a single line (no line breaks except in private_key)
- Check that all quotes are properly escaped if needed
- Make sure you copied the entire JSON content

### Error: "Firebase credentials not found"

**Solution**:
- Verify `FIREBASE_CREDENTIALS` is set in Railway Variables
- Check that the variable name is exactly `FIREBASE_CREDENTIALS` (case-sensitive)
- Ensure Railway has redeployed after setting the variable
- Check Railway logs for detailed error messages

### Push Notifications Not Working

**Solution**:
1. Verify Firebase is initialized (check logs for "Firebase Admin initialized")
2. Check that device tokens are being registered
3. Verify FCM service is being called
4. Check Firebase Console for delivery reports
5. Ensure Firebase project has FCM enabled

## Local Development vs Production

### Local Development
```env
# Use file path
FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json
```

### Production (Railway)
```env
# Use JSON string (single line)
FIREBASE_CREDENTIALS={"type":"service_account",...}
```

## Security Best Practices

1. **Never commit** Firebase service account JSON to git
2. **Rotate keys** periodically for security
3. **Use different keys** for development and production
4. **Restrict Firebase permissions** to only what's needed
5. **Monitor Firebase usage** in Firebase Console
6. **Keep credentials secure** - only set in Railway Variables (encrypted)

## Quick Reference

```bash
# Get Firebase credentials
1. Firebase Console → Project Settings → Service Accounts
2. Generate new private key
3. Download JSON file

# Convert to single line (optional)
# Use JSON minifier or manually remove line breaks

# Set in Railway
Railway Dashboard → Your Service → Variables → + New Variable
Name: FIREBASE_CREDENTIALS
Value: [paste entire JSON as single line]

# Verify
Check Railway logs for "Firebase Admin initialized"
```

## Example JSON Structure

Your `FIREBASE_CREDENTIALS` should look like this (all on one line):

```json
{"type":"service_account","project_id":"your-project-id","private_key_id":"abc123","private_key":"-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk@your-project.iam.gserviceaccount.com","client_id":"123456789","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk%40your-project.iam.gserviceaccount.com"}
```

Note: The `private_key` field will contain `\n` characters (newlines) which is normal and required.

