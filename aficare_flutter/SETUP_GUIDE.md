# AfiCare MediLink - Complete Setup Guide (100% FREE)

## Step 1: Install Flutter (5 minutes)

### Windows
```powershell
# Option A: Download directly
# Go to https://flutter.dev/docs/get-started/install/windows
# Download and extract to C:\flutter
# Add C:\flutter\bin to your PATH

# Option B: Using Chocolatey
choco install flutter

# Verify installation
flutter doctor
```

### What you need:
- Flutter SDK (FREE)
- Android Studio (FREE) - for Android builds
- VS Code (FREE) - recommended editor
- Chrome (FREE) - for web development

## Step 2: Set Up Supabase (5 minutes)

1. **Create Account**
   - Go to https://supabase.com
   - Sign up with GitHub (FREE)

2. **Create Project**
   - Click "New Project"
   - Name: `aficare-medilink`
   - Database Password: (save this!)
   - Region: Choose closest to you
   - Click "Create"

3. **Set Up Database**
   - Go to SQL Editor
   - Copy contents of `supabase/schema.sql`
   - Click "Run"

4. **Get API Keys**
   - Go to Settings → API
   - Copy:
     - Project URL: `https://xxxxx.supabase.co`
     - anon public key: `eyJhbGciOiJ...`

5. **Update Config**
   - Open `lib/config/supabase_config.dart`
   - Replace the placeholders with your keys

## Step 3: Run the App

```bash
# Navigate to project
cd aficare_flutter

# Get dependencies
flutter pub get

# Run on web browser
flutter run -d chrome

# Run on Android device/emulator
flutter run -d android
```

## Step 4: Deploy Web App to Vercel (FREE)

```bash
# Build web version
flutter build web

# Install Vercel CLI
npm install -g vercel

# Deploy
cd build/web
vercel

# Follow prompts - your app will be live at a .vercel.app URL!
```

## Step 5: Build Android APK

```bash
# Build release APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk

# Share via:
# - WhatsApp/Telegram
# - Email
# - GitHub Releases
# - Your website
```

## Step 6: Distribute Your App (FREE)

### Option A: Direct APK Download
1. Upload APK to your website
2. Users download and install directly
3. Cost: $0

### Option B: GitHub Releases
1. Create a GitHub repository
2. Go to Releases → Create Release
3. Upload APK as asset
4. Share the download link
5. Cost: $0

### Option C: F-Droid (Open Source Store)
1. Submit to F-Droid
2. Reaches Android users who prefer open-source
3. Cost: $0

### Option D: Google Play Store
1. One-time $25 fee
2. Reaches millions of users
3. Required for wide distribution

## Complete Free Stack

| Component | Service | Cost |
|-----------|---------|------|
| Mobile App | Flutter | $0 |
| Database | Supabase Free | $0 |
| Auth | Supabase Auth | $0 |
| Web Hosting | Vercel | $0 |
| APK Hosting | GitHub | $0 |
| **TOTAL** | | **$0** |

## Supabase Free Tier Limits

- 500 MB Database
- 1 GB File Storage
- 2 GB Bandwidth
- 50,000 Monthly Active Users
- Unlimited API Requests

This is MORE than enough for:
- Thousands of patients
- Hundreds of healthcare providers
- Years of medical records

## Troubleshooting

### Flutter not found
```bash
# Add to PATH (Windows)
setx PATH "%PATH%;C:\flutter\bin"

# Restart terminal
```

### Android SDK not found
```bash
# Install Android Studio
# Open Android Studio → SDK Manager
# Install Android SDK
flutter config --android-sdk "C:\Users\YOU\AppData\Local\Android\Sdk"
```

### Supabase connection failed
1. Check your internet connection
2. Verify API keys in `supabase_config.dart`
3. Check Supabase dashboard for errors

## Need Help?

- Flutter docs: https://flutter.dev/docs
- Supabase docs: https://supabase.com/docs
- GitHub Issues: Create an issue in the repo

---

**Total Cost: $0**
**Time to Deploy: ~30 minutes**
**Users Supported: 50,000/month FREE**
