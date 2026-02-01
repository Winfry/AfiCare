# AfiCare MediLink - Flutter Mobile App

Patient-Owned Healthcare Records for Africa - 100% FREE

## 🚀 Features

- **Cross-Platform**: Single codebase for iOS, Android, and Web
- **Patient-Owned Records**: Unique MediLink IDs with full data ownership
- **QR Code Sharing**: Secure medical record sharing with healthcare providers
- **Offline-First**: Works completely offline with local AI
- **AI-Powered Consultations**: Rule-based medical AI with backend integration
- **Real-time Sync**: Optional cloud sync with Supabase
- **Maternal Health**: Comprehensive antenatal and postpartum care tracking
- **Women's Health**: PCOS, endometriosis, and reproductive health management

## 📱 Screenshots

| Patient Dashboard | Provider Interface | AI Consultation |
|-------------------|-------------------|-----------------|
| Health records, vital signs, medications | QR scanner, patient access | Symptom analysis, triage |

## 🛠 Getting Started

### Prerequisites

1. **Install Flutter** (FREE)
   ```bash
   # Download from https://flutter.dev/docs/get-started/install
   flutter doctor  # Verify installation
   ```

2. **Set up Backend Connection** (Optional)
   - Update `lib/services/medical_ai_service.dart`
   - Change `backendUrl` to your deployed AfiCare backend
   - App works offline if backend unavailable

3. **Configure Supabase** (Optional - for cloud sync)
   - Go to https://supabase.com (FREE - 50,000 users/month)
   - Create project and copy credentials to `lib/config/supabase_config.dart`

### Quick Start

```bash
# Clone and setup
cd aficare_flutter
flutter pub get

# Run on web (fastest for development)
flutter run -d chrome

# Run on Android
flutter run -d android

# Run on iOS (requires Mac)
flutter run -d ios
```

## 🏗 Build for Production

```bash
# Web app (PWA)
flutter build web

# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires Mac + Xcode)
flutter build ios --release
```

## 🌐 Free Deployment Options

### 1. Web App (Vercel - FREE)
```bash
flutter build web
cd build/web
npx vercel
```

### 2. Android APK (GitHub Releases - FREE)
```bash
flutter build apk --release
# Upload build/app/outputs/flutter-apk/app-release.apk to GitHub Releases
```

### 3. Progressive Web App (PWA)
The web build is automatically a PWA - users can install it on any device!

## 📊 Demo Accounts

| Role | Email | Password | MediLink ID |
|------|-------|----------|-------------|
| Patient | patient@demo.com | demo123 | ML-NBO-DEMO1 |
| Doctor | doctor@demo.com | demo123 | - |
| Admin | admin@demo.com | demo123 | - |

## 🏗 Architecture

### State Management
- **Provider**: For reactive state management
- **Hive**: Local storage for offline functionality
- **Supabase**: Optional cloud sync and authentication

### Key Components
```
lib/
├── main.dart                    # App entry point
├── config/supabase_config.dart  # Cloud configuration
├── models/                      # Data models
├── providers/                   # State management
├── screens/                     # UI screens
│   ├── patient/                 # Patient interface
│   ├── provider/                # Healthcare provider interface
│   └── admin/                   # Admin dashboard
├── services/                    # Business logic
│   ├── medical_ai_service.dart  # AI consultation
│   └── hybrid_ai_service.dart   # Backend integration
└── utils/                       # Utilities and themes
```

## 🤖 AI Integration

### Local AI (Always Available)
- Rule-based medical diagnosis
- Symptom analysis and triage
- Treatment recommendations
- Works completely offline

### Backend AI (Optional)
- Connects to AfiCare Streamlit backend
- Advanced LangChain/LlamaIndex integration
- Groq Cloud or Ollama local LLM support
- Graceful fallback to local AI

## 🔒 Security Features

- **Encrypted Storage**: All local data encrypted
- **Temporary Access**: Time-limited sharing codes
- **Audit Logging**: Complete access history
- **Granular Permissions**: Control what data is shared
- **QR Code Security**: Encrypted patient data in QR codes

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Ready | APK and Play Store ready |
| iOS | ✅ Ready | App Store ready (requires Mac) |
| Web | ✅ Ready | PWA with offline support |
| Desktop | 🔄 Planned | Windows, macOS, Linux |

## 🆓 Free Tier Limits

| Service | Free Tier | Sufficient For |
|---------|-----------|----------------|
| Supabase Database | 500 MB | 10,000+ patients |
| Supabase Storage | 1 GB | Medical documents |
| Supabase Auth | Unlimited | All users |
| Vercel Hosting | Unlimited | Global deployment |
| Flutter | Free | All platforms |

## 🚀 Deployment Guide

### 1. Google Play Store
1. Build: `flutter build appbundle --release`
2. Create Google Play Console account ($25 one-time)
3. Upload and publish

### 2. Apple App Store
1. Build: `flutter build ios --release`
2. Create Apple Developer account ($99/year)
3. Upload via Xcode and publish

### 3. Web Deployment
Deploy `build/web` to:
- **Vercel**: `npx vercel`
- **Netlify**: Drag and drop
- **Firebase**: `firebase deploy`
- **GitHub Pages**: Push to gh-pages branch

## 🔧 Troubleshooting

### Common Issues

**Build Errors:**
```bash
flutter clean
flutter pub get
flutter run
```

**Android Issues:**
- Update Android SDK
- Check Java 11+ installation
- Verify `android/app/build.gradle`

**iOS Issues:**
- Update Xcode
- Run `pod install` in `ios/` directory
- Check iOS deployment target

**Backend Connection:**
- App automatically falls back to offline mode
- Check backend URL in service files
- Verify network connectivity

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open Pull Request

## 📄 License

MIT License - Free for personal and commercial use

## 🆘 Support

- **GitHub Issues**: Report bugs and request features
- **Documentation**: Check README and code comments
- **Demo**: Use demo accounts for testing
- **Community**: Join discussions in GitHub Discussions

---

**Made with ❤️ for African Healthcare**

*Empowering patients with complete ownership of their medical records*
