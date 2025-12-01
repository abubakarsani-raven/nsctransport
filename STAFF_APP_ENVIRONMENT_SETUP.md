# Staff App Environment Configuration - Quick Start

## ✅ What Was Changed

1. **Added `flutter_dotenv` package** - For environment variable support
2. **Created `ApiConfig` class** - Centralized API URL configuration
3. **Updated `api_service.dart`** - Now uses `ApiConfig.baseUrl`
4. **Updated `websocket_service.dart`** - Now uses `ApiConfig.baseUrl`
5. **Updated `main.dart`** - Loads environment files on startup
6. **Created environment files** - `.env` and `.env.production` examples

## 🚀 Quick Setup

### Step 1: Install Dependencies

```bash
cd staff_app
flutter pub get
```

### Step 2: Create Environment Files

**For Development:**
```bash
# Create .env file
echo "API_BASE_URL=http://localhost:3000" > staff_app/.env
```

**For Production:**
```bash
# Create .env.production file
echo "API_BASE_URL=https://nsctransport-production.up.railway.app" > staff_app/.env.production
```

### Step 3: Verify pubspec.yaml

Make sure `pubspec.yaml` includes:

```yaml
assets:
  - .env
  - .env.production
```

## 📱 How It Works

### Development (Debug Build)
- Uses `.env` file
- API URL: `http://localhost:3000` (or from `.env`)
- Android emulator automatically uses `10.0.2.2` instead of `localhost`

### Production (Release Build)
- Uses `.env.production` file
- API URL: `https://nsctransport-production.up.railway.app` (or from `.env.production`)

## 🔧 Configuration

### Local Development

Create `staff_app/.env`:
```env
API_BASE_URL=http://localhost:3000
```

### Production

Create `staff_app/.env.production`:
```env
API_BASE_URL=https://nsctransport-production.up.railway.app
```

### Physical Device Testing

For physical devices, use your computer's IP:
```env
API_BASE_URL=http://192.168.1.100:3000
```

Find your IP:
- Mac/Linux: `ifconfig | grep inet`
- Windows: `ipconfig`

## 📝 Files Modified

1. `staff_app/pubspec.yaml` - Added `flutter_dotenv` and environment files as assets
2. `staff_app/lib/config/api_config.dart` - New file for API configuration
3. `staff_app/lib/services/api_service.dart` - Updated to use `ApiConfig`
4. `staff_app/lib/services/websocket_service.dart` - Updated to use `ApiConfig`
5. `staff_app/lib/main.dart` - Added environment file loading
6. `staff_app/env.example` - Example development environment file
7. `staff_app/env.production.example` - Example production environment file

## 🎯 Next Steps

1. **Install dependencies**: `flutter pub get`
2. **Create .env files**: Copy from examples or create manually
3. **Test locally**: Run `flutter run` and verify it connects to localhost
4. **Test production**: Build release and verify it connects to Railway

## 📚 Documentation

See `staff_app/STAFF_APP_ENV_SETUP.md` for detailed documentation.

## ⚠️ Important Notes

- **Never commit** `.env` or `.env.production` files to git
- Always use `https://` for production URLs
- Android emulator automatically converts `localhost` to `10.0.2.2`
- Environment files are loaded at app startup
- Changes require app restart

## 🔍 Verification

After setup, check the console logs:
- Development: `Loaded development environment variables`
- Production: `Loaded production environment variables`
- API URL: `API Base URL: http://localhost:3000` (or your configured URL)

## 🆘 Troubleshooting

### Package not found error
**Solution**: Run `flutter pub get`

### Environment file not found
**Solution**: Create `.env` or `.env.production` file in `staff_app/` directory

### Still using localhost in production
**Solution**: Make sure you're building in release mode: `flutter build --release`

### Android emulator can't connect
**Solution**: The code automatically handles this. Make sure your backend is running on `localhost:3000`






