#!/usr/bin/env python3
"""
AfiCare - Simple Global Deployment
Windows-compatible global deployment setup
"""

import os
import subprocess
import sys
import json
from pathlib import Path

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def create_railway_config():
    """Create Railway.app deployment config"""
    print("Creating Railway.app configuration...")
    
    # railway.toml
    railway_config = """[build]
builder = "NIXPACKS"

[deploy]
healthcheckPath = "/"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"

[env]
PORT = "8080"
STREAMLIT_SERVER_PORT = "8080"
STREAMLIT_SERVER_ADDRESS = "0.0.0.0"
STREAMLIT_SERVER_HEADLESS = "true"
"""
    
    with open("railway.toml", "w", encoding='utf-8') as f:
        f.write(railway_config)
    
    # Procfile for Railway
    procfile = "web: streamlit run medilink_simple.py --server.port $PORT --server.address 0.0.0.0 --server.headless true"
    
    with open("Procfile", "w", encoding='utf-8') as f:
        f.write(procfile)
    
    print("Railway.app config created successfully")

def create_render_config():
    """Create Render.com deployment config"""
    print("Creating Render.com configuration...")
    
    render_config = """services:
  - type: web
    name: aficare-medilink
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: streamlit run medilink_simple.py --server.port $PORT --server.address 0.0.0.0 --server.headless true
    envVars:
      - key: STREAMLIT_SERVER_PORT
        value: $PORT
"""
    
    with open("render.yaml", "w", encoding='utf-8') as f:
        f.write(render_config)
    
    print("Render.com config created successfully")

def create_deployment_guide():
    """Create deployment guide without Unicode characters"""
    print("Creating deployment guide...")
    
    guide = """# AfiCare MediLink - Global Deployment Guide

## DEPLOY YOUR HEALTHCARE SYSTEM GLOBALLY (FREE)

### RAILWAY.APP DEPLOYMENT (RECOMMENDED - FREE)

1. Create Account:
   - Go to https://railway.app
   - Sign up with GitHub (free)

2. Deploy:
   - Push your code to GitHub
   - In Railway: New Project -> Deploy from GitHub
   - Select your repository
   - Railway auto-deploys using railway.toml config

3. Your Global URL:
   - https://your-app.railway.app
   - Accessible from anywhere in the world
   - HTTPS enabled automatically

### RENDER.COM DEPLOYMENT (ALTERNATIVE - FREE)

1. Create Account:
   - Go to https://render.com
   - Sign up with GitHub (free)

2. Deploy:
   - Connect GitHub repository
   - Render uses render.yaml config
   - Auto-deploys on code changes

3. Your Global URL:
   - https://your-app.onrender.com
   - Global access with HTTPS

### MOBILE APP DISTRIBUTION

#### Android APK (Direct Distribution - FREE)
- Build: flutter build apk --release
- Share APK file directly
- Upload to Google Drive for download
- No app store needed

#### Google Play Store (Optional - $25 one-time)
- Upload APK to Google Play Console
- Complete store listing
- Submit for review

### COST BREAKDOWN

100% FREE Option:
- Railway.app: 500 hours/month FREE
- Direct APK distribution: FREE
- Total: $0/month

Premium Option:
- Railway Pro: $5/month (unlimited)
- Google Play Store: $25 one-time
- Total: ~$5-10/month

### QUICK DEPLOYMENT STEPS

1. Prepare Code:
   git add .
   git commit -m "Ready for deployment"
   git push origin main

2. Deploy to Railway:
   - Go to railway.app
   - New Project -> Deploy from GitHub
   - Select repository
   - Wait for deployment (5-10 minutes)

3. Test Global Access:
   - Visit your Railway URL
   - Test from different devices/networks
   - Verify all features work

### SUCCESS CRITERIA

After deployment, your system will be:
- Accessible from anywhere in the world
- Available 24/7 on any device
- Secure with HTTPS encryption
- Installable as mobile app
- Scalable for thousands of users

### GLOBAL FEATURES

- Multi-device access: Phone, tablet, computer
- Offline capability: PWA works offline
- Real-time sync: Data syncs across devices
- Secure: HTTPS encryption, patient data protection
- Fast: Global CDN for fast loading worldwide

Your AfiCare MediLink system will be a professional, globally accessible healthcare platform!
"""
    
    with open("GLOBAL_DEPLOYMENT_GUIDE.md", "w", encoding='utf-8') as f:
        f.write(guide)
    
    print("Deployment guide created successfully")

def create_quick_deploy_scripts():
    """Create quick deployment scripts"""
    print("Creating deployment scripts...")
    
    # Railway deployment script
    railway_script = """@echo off
echo AfiCare - Railway Deployment
echo.
echo This will help you deploy to Railway.app (FREE)
echo.
echo STEPS:
echo 1. Go to https://railway.app
echo 2. Sign up with GitHub
echo 3. New Project - Deploy from GitHub
echo 4. Select your AfiCare repository
echo 5. Railway will auto-deploy using railway.toml
echo.
echo Your app will be live at: https://your-app.railway.app
echo.
pause
"""
    
    with open("deploy_railway.bat", "w", encoding='utf-8') as f:
        f.write(railway_script)
    
    # Git preparation script
    git_script = """@echo off
echo AfiCare - Prepare for Deployment
echo.
echo Preparing your code for deployment...
echo.

git add .
git commit -m "AfiCare MediLink - Ready for global deployment"
git push origin main

echo.
echo Code prepared for deployment!
echo.
echo NEXT STEPS:
echo 1. Go to https://railway.app
echo 2. Deploy from GitHub
echo 3. Your app will be globally accessible!
echo.
pause
"""
    
    with open("prepare_deployment.bat", "w", encoding='utf-8') as f:
        f.write(git_script)
    
    print("Deployment scripts created successfully")

def setup_flutter_for_global():
    """Setup Flutter for global deployment"""
    print("Setting up Flutter for global deployment...")
    
    flutter_dir = Path("../aficare_flutter")
    
    if flutter_dir.exists():
        # Create vercel.json for Flutter web deployment
        vercel_config = {
            "version": 2,
            "name": "aficare-flutter",
            "builds": [
                {
                    "src": "build/web/**",
                    "use": "@vercel/static"
                }
            ],
            "routes": [
                {
                    "src": "/(.*)",
                    "dest": "/build/web/$1"
                }
            ]
        }
        
        with open(flutter_dir / "vercel.json", "w", encoding='utf-8') as f:
            json.dump(vercel_config, f, indent=2)
        
        print("Flutter web deployment config created successfully")
    else:
        print("Flutter directory not found, skipping Flutter setup")

def main():
    print_header("AfiCare Global Deployment Setup")
    print("Setting up FREE global deployment for your healthcare system")
    
    try:
        # Create deployment configurations
        create_railway_config()
        create_render_config()
        
        # Setup Flutter
        setup_flutter_for_global()
        
        # Create guides and scripts
        create_deployment_guide()
        create_quick_deploy_scripts()
        
        print_header("GLOBAL DEPLOYMENT READY!")
        
        print("Railway.app configuration created")
        print("Render.com configuration created")
        print("Flutter web deployment config created")
        print("Deployment guide created")
        print("Quick deployment scripts created")
        print()
        print("NEXT STEPS:")
        print("1. Read: GLOBAL_DEPLOYMENT_GUIDE.md")
        print("2. Run: prepare_deployment.bat (prepare code)")
        print("3. Go to https://railway.app and deploy")
        print("4. Your app will be globally accessible!")
        print()
        print("GLOBAL URLS (after deployment):")
        print("PWA: https://your-app.railway.app")
        print("Flutter Web: https://your-flutter.vercel.app")
        print()
        print("COST: 100% FREE using free tiers!")
        print()
        print("Your healthcare system will be accessible")
        print("from anywhere in the world, 24/7!")
        
        return True
        
    except Exception as e:
        print(f"\nSetup failed: {e}")
        return False

if __name__ == "__main__":
    success = main()
    
    if success:
        print("\nReady for global deployment!")
    else:
        print("\nSetup failed - check errors above")
    
    input("\nPress Enter to exit...")
    sys.exit(0 if success else 1)