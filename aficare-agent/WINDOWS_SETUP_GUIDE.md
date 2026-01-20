# 🏥 AfiCare MediLink - Windows Setup Guide

## 🚨 Windows Port Permission Issue - SOLVED!

If you're getting `PermissionError: [WinError 10013]` when trying to run Streamlit, this guide will fix it.

---

## 🎯 **QUICK START (Choose One)**

### **Option 1: Python Launcher (Recommended)**
```bash
cd aficare-agent
python launch_medilink.py
```

### **Option 2: Quick Start (Simple)**
```bash
cd aficare-agent
python quick_start.py
```

### **Option 3: Batch File (Windows)**
```cmd
cd aficare-agent
run_medilink_windows.bat
```

### **Option 4: Manual Port (If others fail)**
```bash
# Try these one by one:
streamlit run medilink_simple.py --server.port 8090
streamlit run medilink_simple.py --server.port 9000
streamlit run medilink_simple.py --server.port 7000
```

---

## 🔧 **Manual Port Selection**

If the automatic launchers don't work, try these ports manually:

```bash
# Try these ports one by one until one works:
streamlit run medilink_simple.py --server.port 8080
streamlit run medilink_simple.py --server.port 8090  
streamlit run medilink_simple.py --server.port 9000
streamlit run medilink_simple.py --server.port 3000
streamlit run medilink_simple.py --server.port 5000
```

---

## 🎮 **Demo Accounts**

Once the app starts, use these accounts to test:

### **👤 Patient Account**
- **Username:** `patient_demo` or `ML-NBO-DEMO1`
- **Password:** `demo123`
- **Features:** View health records, share with hospitals, generate access codes

### **👨‍⚕️ Doctor Account**
- **Username:** `dr_demo`
- **Password:** `demo123`
- **Features:** Access patient records, create consultations, AI diagnosis

### **👩‍⚕️ Nurse Account**
- **Username:** `nurse_demo`
- **Password:** `demo123`
- **Features:** Patient access, basic consultations, vital signs

### **⚙️ Admin Account**
- **Username:** `admin_demo`
- **Password:** `demo123`
- **Features:** User management, hospital analytics, system settings

---

## 🌐 **What You'll See**

### **Patient Interface:**
- 📋 **MediLink ID:** ML-NBO-DEMO1 (your unique health ID)
- 📊 **Health Summary:** View all your medical visits
- 🏥 **Visit History:** Complete medical history across hospitals
- 🔐 **Share Records:** Generate codes/QR to share with doctors
- ⚙️ **Privacy Settings:** Control who sees your data

### **Doctor Interface:**
- 🔍 **Patient Access:** Enter MediLink ID or access code
- 👥 **Patient List:** See your recent patients
- 📋 **New Consultation:** AI-powered diagnosis and treatment
- 📊 **Statistics:** Your consultation metrics

### **Admin Interface:**
- 👥 **User Management:** Add doctors, nurses, staff
- 📊 **Analytics:** Hospital-wide statistics
- 🔒 **Security:** Access logs and audit trails
- ⚙️ **Settings:** Hospital configuration

---

## 🎯 **Key Features to Test**

### **1. Patient-Owned Records**
1. Login as patient (`patient_demo`)
2. See your MediLink ID: `ML-NBO-DEMO1`
3. Generate access code in "Share with Hospital" tab
4. Logout and login as doctor
5. Use the access code to view patient records

### **2. AI Medical Consultation**
1. Login as doctor (`dr_demo`)
2. Go to "New Consultation" tab
3. Enter patient MediLink ID: `ML-NBO-DEMO1`
4. Fill symptoms (fever, headache, etc.)
5. Click "Analyze with AI" - see malaria diagnosis!

### **3. Hospital-Wide Access**
1. Any doctor can access any patient's records
2. Complete medical history from all hospitals
3. Real-time updates across the system

---

## 🚨 **Troubleshooting**

### **Still Getting Port Errors?**

**Solution 1: Run as Administrator**
```cmd
# Right-click Command Prompt → "Run as Administrator"
cd C:\path\to\your\aficare-agent
python launch_medilink.py
```

**Solution 2: Check Windows Firewall**
1. Open Windows Defender Firewall
2. Click "Allow an app through firewall"
3. Add Python.exe and streamlit

**Solution 3: Use Different Network Interface**
```bash
streamlit run medilink_simple.py --server.port 8080 --server.address 127.0.0.1
```

**Solution 4: Kill Existing Processes**
```cmd
# Kill any existing streamlit processes
taskkill /f /im python.exe
# Then try again
python launch_medilink.py
```

---

## 📱 **Mobile Testing**

The app works on mobile browsers too!

1. Start the app on your computer
2. Find your computer's IP address: `ipconfig`
3. On your phone, go to: `http://YOUR_IP:PORT`
4. Test the mobile interface

---

## 🎉 **Success Indicators**

You'll know it's working when you see:

```
🏥 AfiCare MediLink Launcher
==================================================

🔍 Finding available port...
✅ Found available port: 8080
🚀 Starting MediLink on port 8080...
🌐 Your app will be available at: http://localhost:8080

📱 Demo Accounts:
   Patient: username=patient_demo, password=demo123
   Doctor:  username=dr_demo, password=demo123
   Admin:   username=admin_demo, password=demo123

⏹️  Press Ctrl+C to stop the server
==================================================

  You can now view your Streamlit app in your browser.
  Local URL: http://localhost:8080
```

---

## 🏆 **What This Demonstrates**

This working prototype shows:

✅ **Patient-Owned Records** - Patients control their data with MediLink ID  
✅ **Hospital Integration** - Any doctor can access patient records with permission  
✅ **AI Medical Diagnosis** - Rule-based analysis for malaria, pneumonia, etc.  
✅ **Role-Based Access** - Different interfaces for patients, doctors, admins  
✅ **Mobile Ready** - Works on phones and tablets  
✅ **Completely FREE** - No licensing costs, open source  

---

## 🚀 **Next Steps**

Once you have it running:

1. **Test all user roles** - Patient, Doctor, Nurse, Admin
2. **Try the AI consultation** - Enter symptoms, get diagnosis
3. **Test record sharing** - Generate access codes, share between users
4. **Explore mobile interface** - Use on your phone
5. **Review the architecture** - Check out the documentation files

---

## 💡 **Need Help?**

If you're still having issues:

1. Make sure you're in the `aficare-agent` directory
2. Check that Python and Streamlit are installed
3. Try the Python launcher first: `python launch_medilink.py`
4. If all else fails, run as Administrator

**The system is working and ready for testing!** 🎉