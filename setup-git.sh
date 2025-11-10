#!/bin/bash

# Setup script for initializing git repository and preparing for deployment

echo "🚀 Setting up git repository for deployment..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install git first."
    exit 1
fi

# Initialize git repository
if [ ! -d .git ]; then
    echo "📦 Initializing git repository..."
    git init
    git branch -M main
    echo "✅ Git repository initialized"
else
    echo "✅ Git repository already initialized"
fi

# Check for Firebase service account file
if [ -f "backend/config/firebase-service-account.json" ]; then
    echo "⚠️  WARNING: Firebase service account file found!"
    echo "   This file should NOT be committed to git."
    echo "   It should be added as FIREBASE_CREDENTIALS environment variable in Railway."
    echo "   The file is already in .gitignore and will not be committed."
fi

# Check for .env files
if [ -f "backend/.env" ] || [ -f "admin_web/.env.local" ]; then
    echo "⚠️  WARNING: .env files found!"
    echo "   These files should NOT be committed to git."
    echo "   Environment variables should be set in Railway and Vercel."
    echo "   .env files are already in .gitignore and will not be committed."
fi

# Show what will be committed
echo ""
echo "📋 Files that will be committed:"
git status --short 2>/dev/null || echo "   (Run 'git add .' to see files)"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Create a new repository on GitHub (don't initialize with README)"
echo "2. Run the following commands:"
echo "   git add ."
echo "   git commit -m 'Initial commit - ready for deployment'"
echo "   git remote add origin https://github.com/yourusername/nsctranspot.git"
echo "   git push -u origin main"
echo ""
echo "3. Follow the DEPLOYMENT.md guide to deploy to Railway and Vercel"
echo ""

