# 🏥 AfiCare - Quick Start Guide

## 🚀 Start the App (Choose One Method)

### Method 1: Double-Click (Windows)
```
Double-click: START_AFICARE.bat
```

### Method 2: Python Script (All Platforms)
```bash
cd aficare-agent
python run_aficare.py
```

### Method 3: Simple Starter
```bash
cd aficare-agent
python start_dev_app.py
```

## 📱 Access the App

After starting, open your browser:
- **Local**: http://localhost:8505
- **Mobile**: http://192.168.100.5:8505

## 👤 Demo Accounts

| Role | Email | Password |
|------|-------|----------|
| Patient | patient@demo.com | demo123 |
| Doctor | doctor@demo.com | demo123 |
| Admin | admin@demo.com | demo123 |

## 🔧 Troubleshooting

### App Won't Start?
```bash
python diagnose_issues.py
```
This will show exactly what's wrong.

### Port Already in Use?
The scripts automatically find an available port (8501-8510).

### Import Errors?
```bash
pip install -r requirements.txt
```

## ✅ What's Fixed

- ✅ Port conflict issues resolved
- ✅ LLM graceful fallback added
- ✅ JSON loading errors handled
- ✅ Automatic process cleanup
- ✅ Better error messages

## 📊 Features Available

- ✅ Patient consultations
- ✅ AI-powered triage
- ✅ Symptom analysis
- ✅ Condition matching
- ✅ Treatment recommendations
- ✅ Medical knowledge base
- ✅ System status monitoring

## 🌍 Deploy Globally

When ready for internet access:
```bash
python deploy_global_simple.py
```

## 📱 Mobile Testing

1. Make sure phone is on same WiFi
2. Open browser on phone
3. Go to: http://192.168.100.5:8505
4. Login with demo account
5. Test all features

## 🆘 Need Help?

1. Run diagnostics: `python diagnose_issues.py`
2. Check logs: `logs/aficare_*.log`
3. Read: `CRASH_FIX_GUIDE.md`

---

**Status**: ✅ Ready to use
**Last Updated**: 2026-03-04
