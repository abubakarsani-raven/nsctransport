# Staff App Environment Configuration

This guide explains how to configure the Staff App to work with both local development and production (Railway) backend.

## Overview

The Staff App now supports environment-based configuration:
- **Development**: Uses `localhost` (or your computer's IP for physical devices)
- **Production**: Uses Railway URL (`https://nsctransport-production.up.railway.app`)

## Setup

### 1. Install Dependencies

First, install the new dependency:

```bash
cd staff_app
flutter pub get
```

### 2. Create Environment Files

#### For Local Development

Create `.env` file in the `staff_app` directory:

```bash
# Copy the example file
cp env.example .env
```

Or create `.env` manually with:

```env
API_BASE_URL=http://localhost:3000
```

#### For Production Builds

Create `.env.production` file:

```bash
# Copy the example file
cp env.production.example .env.production
```

Or create `.env.production` manually with:

```env
API_BASE_URL=https://nsctransport-production.up.railway.app
```

### 3. Update pubspec.yaml

The `pubspec.yaml` has been updated to include the environment files as assets:

```yaml
assets:
  - .env
  - .env.production
```

Make sure these files are listed in your `pubspec.yaml`.

## How It Works

### Development Mode (Debug Builds)

- Loads `.env` file
- Uses `API_BASE_URL` from `.env` if set
- Falls back to `localhost` if `.env` is not found
- Automatically converts `localhost` to `10.0.2.2` for Android emulator

### Production Mode (Release Builds)

- Loads `.env.production` file
- Uses `API_BASE_URL` from `.env.production` if set
- Falls back to Railway URL if `.env.production` is not found

## Platform-Specific Behavior

### Android Emulator
- `localhost` is automatically converted to `10.0.2.2`
- This allows the emulator to access your development server

### iOS Simulator
- Uses `localhost` directly
- No special configuration needed

### Physical Devices
- For development, you may need to use your computer's IP address
- Example: `http://192.168.1.100:3000`
- Find your IP: `ifconfig` (Mac/Linux) or `ipconfig` (Windows)

### Web
- Uses `localhost` directly
- Works with your local development server

## Building for Production

### Debug Build (Development)

```bash
flutter run
# or
flutter run --debug
```

Uses `.env` file → `http://localhost:3000` (or your configured URL)

### Release Build (Production)

```bash
flutter build apk --release
# or
flutter build ios --release
# or
flutter build web --release
```

Uses `.env.production` file → `https://nsctransport-production.up.railway.app`

## Testing

### Test Local Development

1. Make sure your backend is running on `http://localhost:3000`
2. Create `.env` file with `API_BASE_URL=http://localhost:3000`
3. Run the app: `flutter run`
4. Check the console for: `Loaded development environment variables`
5. Verify API calls work

### Test Production

1. Create `.env.production` file with Railway URL
2. Build release: `flutter build apk --release`
3. Install and run the app
4. Verify it connects to Railway backend

## Troubleshooting

### Error: "Error loading environment variables"

**Solution**: 
- Make sure `.env` or `.env.production` file exists
- Check that the file is listed in `pubspec.yaml` assets
- Verify the file format is correct (no spaces around `=`)

### App Still Using Localhost in Production

**Solution**:
- Make sure you're building in release mode: `flutter build --release`
- Verify `.env.production` file exists and has the correct URL
- Check that `pubspec.yaml` includes `.env.production` in assets

### Android Emulator Can't Connect

**Solution**:
- The code automatically converts `localhost` to `10.0.2.2` for Android
- If using a custom IP, make sure it's accessible from the emulator
- Check that your development server allows connections from the emulator

### Physical Device Can't Connect

**Solution**:
- Use your computer's IP address instead of `localhost`
- Example: `API_BASE_URL=http://192.168.1.100:3000`
- Make sure your device and computer are on the same network
- Check firewall settings

### WebSocket Connection Fails

**Solution**:
- WebSocket uses the same URL as the API
- For production, make sure the Railway backend supports WebSockets
- Check that the URL uses `https://` (not `http://`) for production

## Environment Files

### .env (Development)

```env
API_BASE_URL=http://localhost:3000
```

### .env.production (Production)

```env
API_BASE_URL=https://nsctransport-production.up.railway.app
```

## Git Configuration

### .gitignore

Make sure `.env` and `.env.production` are in `.gitignore`:

```
.env
.env.production
```

### Example Files

Commit the example files to git:
- `env.example`
- `env.production.example`

These serve as templates for other developers.

## Quick Reference

### Development
```bash
# Create .env file
echo "API_BASE_URL=http://localhost:3000" > .env

# Run app
flutter run
```

### Production
```bash
# Create .env.production file
echo "API_BASE_URL=https://nsctransport-production.up.railway.app" > .env.production

# Build release
flutter build apk --release
```

## Notes

- Environment files are loaded at app startup
- Changes to `.env` files require app restart
- Production builds automatically use `.env.production`
- Debug builds automatically use `.env`
- The API URL is logged to console on startup (check debug output)

## Related Files

- `lib/config/api_config.dart` - API configuration logic
- `lib/services/api_service.dart` - Uses `ApiConfig.baseUrl`
- `lib/services/websocket_service.dart` - Uses `ApiConfig.baseUrl`
- `lib/main.dart` - Loads environment files

## Support

For issues or questions:
1. Check the console logs for environment loading messages
2. Verify environment files are in the correct location
3. Check `pubspec.yaml` includes the environment files as assets
4. Verify the API URL format is correct

