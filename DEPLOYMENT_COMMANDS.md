# AfiCare MediLink - Deployment Commands

## 🚀 Quick Start Commands

### From the aficare-agent directory:

```bash
# Option 1: Use the Python deployment script
python deploy_aficare.py

# Option 2: Use the Windows batch file
start_aficare.bat

# Option 3: Direct Streamlit command
streamlit run medilink_simple.py --server.port 8502
```

### From the root directory:

```bash
# Use the comprehensive deployment script
python deploy_both_apps.py
```

## 📱 Flutter App Commands

```bash
cd aficare_flutter

# Install dependencies
flutter pub get

# Run on web (fastest)
flutter run -d chrome

# Run on Android
flutter run -d android

# Build for production
flutter build web --release
flutter build apk --release
```

## 🔧 If You Get Errors

### Backend Issues:
```bash
cd aficare-agent
pip install -r requirements.txt
python test_full_ai_agent.py  # Test the AI
streamlit run medilink_simple.py --server.port 8503  # Try different port
```

### Flutter Issues:
```bash
cd aficare_flutter
flutter clean
flutter pub get
flutter doctor  # Check for issues
```

## 🌐 Access Your Apps

- **Streamlit Backend**: http://localhost:8502
- **Flutter Web**: http://localhost:3000 (when running flutter run -d chrome)

## 📱 Demo Accounts

- **Patient**: patient@demo.com / demo123
- **Doctor**: doctor@demo.com / demo123  
- **Admin**: admin@demo.com / demo123

## 🎉 You're Ready!

Both your Streamlit backend and Flutter mobile app are ready to deploy!