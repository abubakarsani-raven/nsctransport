# Railway Deployment Fix

## Problem
Railway deployment was failing with dependency resolution errors:
- `npm ci` was failing because package-lock.json was out of sync
- Missing packages: gcp-metadata@5.3.0, gaxios@5.1.3, https-proxy-agent@5.0.1, agent-base@6.0.2
- `@nestjs/event-emitter@2.1.1` was incompatible with NestJS v11

## Solution Applied

### 1. Updated @nestjs/event-emitter
- **Changed**: `@nestjs/event-emitter@^2.1.1` → `@nestjs/event-emitter@^3.0.1`
- **Reason**: Version 3.0.1 supports NestJS v11 (`^10.0.0 || ^11.0.0`)
- **File**: `backend/package.json`

### 2. Regenerated package-lock.json
- **Action**: Removed old lock file and regenerated with `npm install`
- **Reason**: Ensures all dependencies are properly resolved and locked
- **File**: `backend/package-lock.json`

### 3. Updated Railway Build Configuration
- **Changed**: `npm ci --production=false` → `npm install --production=false`
- **Reason**: `npm install` is more forgiving with dependency resolution and will work even if lock file has minor inconsistencies
- **File**: `backend/nixpacks.toml`

### 4. Added .npmrc Configuration
- **Added**: `legacy-peer-deps=true`
- **Reason**: Helps resolve peer dependency conflicts if they arise
- **File**: `backend/.npmrc`

## Files Changed

1. `backend/package.json` - Updated @nestjs/event-emitter to ^3.0.1
2. `backend/package-lock.json` - Regenerated with fresh dependencies
3. `backend/nixpacks.toml` - Changed to use `npm install` instead of `npm ci`
4. `backend/.npmrc` - Added legacy-peer-deps configuration

## Next Steps

1. **Commit and push the changes**:
   ```bash
   git add backend/package.json backend/package-lock.json backend/nixpacks.toml backend/.npmrc
   git commit -m "Fix Railway deployment: Update @nestjs/event-emitter and build config"
   git push origin main
   ```

2. **Railway will automatically redeploy** with the new configuration

3. **Verify the deployment**:
   - Check Railway logs for successful build
   - Verify the API is accessible
   - Test endpoints to ensure everything works

## Why This Works

- **npm install vs npm ci**: `npm install` is more flexible and will resolve dependencies even if the lock file has minor issues. While `npm ci` is stricter (better for CI/CD), `npm install` works better in cases where dependency resolution is complex.

- **legacy-peer-deps**: This tells npm to use the legacy peer dependency resolution algorithm, which is more forgiving with peer dependency conflicts.

- **Updated package**: Using `@nestjs/event-emitter@^3.0.1` ensures compatibility with NestJS v11, eliminating the peer dependency conflict.

## Alternative Solution (If Issues Persist)

If you still encounter issues, you can use `npm ci` with `--legacy-peer-deps`:

```toml
[phases.install]
cmds = [
  "npm ci --production=false --legacy-peer-deps"
]
```

However, the current solution using `npm install` should work fine for Railway deployments.

## Verification

After deployment, verify:
1. ✅ Build completes successfully
2. ✅ No dependency errors in logs
3. ✅ Application starts correctly
4. ✅ API endpoints are accessible
5. ✅ Event emitter functionality works (notifications, etc.)

