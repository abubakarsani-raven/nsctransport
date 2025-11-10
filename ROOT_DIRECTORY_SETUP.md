# Where to Set Root Directory

This guide shows you exactly where to set the root directory in Railway and Vercel.

## 🚂 Railway - Backend Root Directory

### Step-by-Step Instructions:

1. **After creating your Railway project** from GitHub:
   - Railway will create a service for your repository
   - You'll see your project dashboard

2. **Navigate to Service Settings**:
   - Click on your service (the one that shows your repository name)
   - Click on the **"Settings"** tab (at the top of the service page)
   - Or click the **three dots (⋯)** menu next to your service → **"Settings"**

3. **Find Root Directory Setting**:
   - Scroll down to the **"Source"** section
   - Look for **"Root Directory"** field
   - It might show as empty or show `/` by default

4. **Set Root Directory**:
   - Click on the **"Root Directory"** field
   - Enter: `backend` (without quotes, just the word: backend)
   - Click **"Save"** or the checkmark

5. **Verify**:
   - Railway will automatically redeploy
   - Check the build logs to confirm it's using the `backend` directory
   - You should see it running `npm install` from the backend folder

### Visual Guide (Railway Interface):

```
Railway Dashboard
└── Your Project
    └── Your Service (repository name)
        ├── Deployments (tab)
        ├── Metrics (tab)
        ├── Settings (tab) ← CLICK HERE
        │   ├── General
        │   ├── Source
        │   │   └── Root Directory: [backend] ← SET HERE
        │   ├── Deploy
        │   └── Variables
        └── Logs (tab)
```

### Alternative Method (if you don't see Root Directory):

1. Click on your service
2. Click on **"Settings"** tab
3. Look for **"Service Settings"** or **"Deploy Settings"**
4. Find **"Working Directory"** or **"Root Directory"**
5. Set it to: `backend`

### If Root Directory Option is Not Visible:

Sometimes Railway auto-detects the structure. If you don't see the option:

1. Go to your service → **Settings**
2. Look for **"Deploy"** section
3. Check **"Build Command"** - it should run from the backend directory
4. You can also set it via Railway CLI:
   ```bash
   railway variables set RAILWAY_ROOT_DIRECTORY=backend
   ```

---

## ▲ Vercel - Admin Web Root Directory

### Step-by-Step Instructions:

1. **After importing your GitHub repository**:
   - Vercel will show you the "Configure Project" page
   - This is where you set up your project before first deployment

2. **Find Root Directory Setting**:
   - Look for the **"Root Directory"** section
   - It might be collapsed under **"Advanced"** or **"Build and Output Settings"**
   - Click **"Edit"** next to Root Directory

3. **Set Root Directory**:
   - Click the **"Edit"** button
   - A dropdown or input field will appear
   - Select or type: `admin_web`
   - Click **"Save"** or **"Continue"**

4. **After Initial Setup** (if you need to change it later):
   - Go to your project dashboard
   - Click on **"Settings"** tab
   - Click on **"General"** in the left sidebar
   - Scroll to **"Root Directory"** section
   - Click **"Edit"**
   - Change to: `admin_web`
   - Click **"Save"**

### Visual Guide (Vercel Interface):

#### During Initial Setup:
```
Vercel Import Project
└── Configure Project
    ├── Project Name
    ├── Framework Preset: Next.js
    ├── Root Directory: [Edit] ← CLICK HERE
    │   └── Enter: admin_web
    ├── Build Command: npm run build
    ├── Output Directory: .next
    └── Install Command: npm install
```

#### After Setup (Settings):
```
Vercel Dashboard
└── Your Project
    ├── Overview (tab)
    ├── Deployments (tab)
    ├── Analytics (tab)
    ├── Settings (tab) ← CLICK HERE
    │   ├── General ← CLICK HERE
    │   │   ├── Project Name
    │   │   ├── Framework
    │   │   └── Root Directory: [Edit] ← SET HERE
    │   ├── Environment Variables
    │   ├── Domains
    │   └── Git
    └── Team (tab)
```

### Detailed Steps for Vercel:

#### Option 1: During Initial Import (Recommended)

1. Go to [vercel.com](https://vercel.com)
2. Click **"Add New..."** → **"Project"**
3. Import your GitHub repository
4. On the **"Configure Project"** page:
   - **Framework Preset**: Should auto-detect as "Next.js"
   - Find **"Root Directory"** (might be under "Advanced" or a gear icon)
   - Click **"Edit"** or the folder icon
   - Select or type: `admin_web`
   - Verify:
     - **Build Command**: `npm run build` (or `cd admin_web && npm run build`)
     - **Output Directory**: `.next`
     - **Install Command**: `npm install` (or `cd admin_web && npm install`)
5. Click **"Deploy"**

#### Option 2: After Project Creation

1. Go to your Vercel project dashboard
2. Click **"Settings"** tab (top navigation)
3. Click **"General"** (left sidebar)
4. Scroll down to **"Root Directory"** section
5. Click **"Edit"** button
6. Change to: `admin_web`
7. Click **"Save"**
8. Vercel will trigger a new deployment

### Alternative: Using vercel.json

The `admin_web/vercel.json` file we created should help, but Vercel still needs to know the root directory. The `vercel.json` configures the build, but the root directory tells Vercel which folder to use as the project root.

---

## ✅ Verification

### Railway Verification:

After setting root directory to `backend`:
1. Check the deployment logs
2. You should see: `Installing dependencies...` followed by npm commands
3. The build should run `npm run build` from the backend directory
4. If you see errors about `package.json` not found, the root directory is wrong

### Vercel Verification:

After setting root directory to `admin_web`:
1. Check the build logs
2. You should see: `Installing dependencies...` from the admin_web directory
3. The build should detect Next.js and run the build command
4. If you see errors about `next.config.ts` not found, the root directory is wrong

---

## 🆘 Troubleshooting

### Railway: Can't Find Root Directory Setting

**Solution 1**: Update via Railway Dashboard
- Go to Service → Settings → Source
- Look for "Root Directory" or "Working Directory"

**Solution 2**: Use Railway CLI
```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Link your project
railway link

# Set root directory
railway variables set RAILWAY_SERVICE_ROOT=backend
```

**Solution 3**: Use railway.json (if supported)
- Create `railway.json` in the root with:
```json
{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "cd backend && npm run start:prod",
    "restartPolicyType": "ON_FAILURE"
  }
}
```

### Vercel: Root Directory Not Working

**Solution 1**: Check vercel.json
- Ensure `admin_web/vercel.json` exists
- Verify the build commands are correct

**Solution 2**: Use Vercel CLI
```bash
# Install Vercel CLI
npm i -g vercel

# Link your project
vercel link

# Set root directory in project settings via dashboard
```

**Solution 3**: Move vercel.json to root (not recommended, but works)
- Move `admin_web/vercel.json` to root as `vercel.json`
- Update paths in the config to point to `admin_web/`

---

## 📝 Quick Reference

### Railway (Backend)
- **Location**: Service → Settings → Source → Root Directory
- **Value**: `backend`
- **Alternative**: Service → Settings → Deploy → Working Directory

### Vercel (Admin Web)
- **Location**: Project → Settings → General → Root Directory
- **Value**: `admin_web`
- **Alternative**: Configure Project → Advanced → Root Directory

---

## 🎯 Summary

1. **Railway**: Go to your service → Settings → Source → Set Root Directory to `backend`
2. **Vercel**: Go to your project → Settings → General → Set Root Directory to `admin_web`

Both platforms will automatically redeploy after you change the root directory setting.

