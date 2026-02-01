# AfiCare Flutter App - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Install Flutter
```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install
# Add Flutter to your PATH
flutter doctor  # Check installation
```

### Step 2: Setup the App
```bash
cd aficare_flutter
flutter pub get  # Install dependencies
```

### Step 3: Run the App
```bash
# Web (fastest for testing)
flutter run -d chrome

# Android (requires Android Studio)
flutter run -d android

# iOS (requires Mac + Xcode)
flutter run -d ios
```

## 📱 Demo Accounts

| Role | Email | Password | MediLink ID |
|------|-------|----------|-------------|
| Patient | patient@demo.com | demo123 | ML-NBO-DEMO1 |
| Doctor | doctor@demo.com | demo123 | - |
| Admin | admin@demo.com | demo123 | - |

## 🔧 Connect to Backend

### Option 1: Use Local Backend
1. Start the Streamlit backend:
   ```bash
   cd ../aficare-agent
   python deploy_aficare.py
   ```
2. The Flutter app will automatically connect to `http://localhost:8502`

### Option 2: Use Deployed Backend
1. Deploy your backend to Railway.app or similar
2. Update `lib/services/medical_ai_service.dart`:
   ```dart
   static const String backendUrl = 'https://your-app.railway.app';
   ```

## 🌐 Build for Production

```bash
# Web App (PWA)
flutter build web --release

# Android APK
flutter build apk --release

# iOS (Mac only)
flutter build ios --release
```

## 📦 Deploy

### Web App (FREE)
```bash
# Build
flutter build web

# Deploy to Vercel
cd build/web
npx vercel

# Or deploy to Netlify (drag & drop build/web folder)
```

### Android App
- **Direct**: Share `build/app/outputs/flutter-apk/app-release.apk`
- **Play Store**: Upload APK to Google Play Console

### iOS App
- **App Store**: Upload via Xcode to App Store Connect

## 🆘 Troubleshooting

### Flutter Issues
```bash
flutter clean
flutter pub get
flutter doctor  # Check for issues
```

### Android Build Issues
- Install Android Studio
- Accept Android licenses: `flutter doctor --android-licenses`
- Update Android SDK

### iOS Build Issues (Mac only)
- Install Xcode from App Store
- Run: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`

## ✨ Features

- **Patient Dashboard**: Complete health records
- **Provider Interface**: QR scanner, AI consultations
- **Admin Panel**: User management
- **Offline Mode**: Works without internet
- **AI Integration**: Medical diagnosis and triage
- **QR Sharing**: Secure record sharing
- **PWA**: Installable web app

## 🌍 Ready to Deploy!

Your AfiCare Flutter app is ready for production deployment. It works standalone or with the Streamlit backend for enhanced AI features.

**Happy coding! 🎉**