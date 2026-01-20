# MediLink ID System - Patient-Owned Health Records for AfiCare

## 🆔 **MEDILINK ID - UNIQUE NAMING**

Instead of "Afya ID", we'll use **"MediLink ID"** - connecting patients and healthcare providers seamlessly.

**Format:** `ML-XXXX-YYYY` (e.g., ML-7K9M-2X4P)
- ML = MediLink
- XXXX = Location/Region code
- YYYY = Unique patient identifier

---

## 📱 **UNIFIED APP ARCHITECTURE**

### **Single App, Multiple Roles:**

```
🏥 AfiCare MediLink App
═══════════════════════════

Login Screen:
┌─────────────────────────────────────┐
│ Welcome to AfiCare MediLink         │
│                                     │
│ Username: [________________]        │
│ Password: [________________]        │
│                                     │
│ Login as:                           │
│ ○ Patient    ○ Doctor              │
│ ○ Nurse      ○ Admin               │
│                                     │
│ [Login] [Register as Patient]       │
└─────────────────────────────────────┘
```

### **Role-Based Interface:**

#### **Patient View:**
```
📱 Patient Dashboard
MediLink ID: ML-7K9M-2X4P

📊 My Health Records
├── 📈 Health Summary
├── 🏥 My Visits (15)
├── 💊 Medications
├── 🧪 Lab Results
├── 🔐 Privacy Settings
└── 🏥 Share with Hospital
```

#### **Doctor View:**
```
👨‍⚕️ Doctor Dashboard
Dr. John Kamau - Nairobi Hospital

🔍 Patient Access
├── 📋 Search Patient (MediLink ID)
├── 👥 My Patients Today
├── 🚨 Emergency Cases
├── 📊 Hospital Statistics
└── ⚙️ Settings
```

#### **Admin View:**
```
⚙️ Admin Dashboard
Hospital Administrator

📊 System Management
├── 👥 User Management
├── 🏥 Hospital Settings
├── 📈 Analytics
├── 🔒 Security Logs
└── 💾 Data Management
```

---

## 💰 **FREE DEPLOYMENT STRATEGY**

### **Open Source & Free Components:**

#### **1. Technology Stack (All Free):**
```yaml
Backend:
  - Python (Free)
  - FastAPI (Free)
  - PostgreSQL (Free)
  - SQLite (Free)

Frontend:
  - React Native (Free)
  - Flutter (Free alternative)
  - Progressive Web App (Free)

Hosting Options:
  - Self-hosted (Free)
  - Heroku Free Tier
  - Railway Free Tier
  - Vercel Free Tier
  - GitHub Pages (Free)

Database:
  - PostgreSQL (Free)
  - Supabase (Free tier)
  - PlanetScale (Free tier)
```

#### **2. Free Deployment Options:**

**Option A: Complete Self-Hosting (100% Free)**
```bash
# Hospital installs on their own server
# No monthly costs, complete control
# Requirements: Basic server/computer
```

**Option B: Cloud Free Tiers**
```yaml
Supabase: Free PostgreSQL database (500MB)
Vercel: Free web hosting
Railway: Free backend hosting (500 hours/month)
Total Cost: $0/month for small hospitals
```

**Option C: Community Cloud**
```yaml
# We provide free hosting for African hospitals
# Funded by donations/grants
# Hospitals pay nothing
```

---

## 🏗️ **UNIFIED APP ARCHITECTURE**

### **Single Codebase, Multiple Interfaces:**

<function_calls>
<invoke name="fsWrite">
<parameter name="path">aficare-agent/src/medilink/unified_app.py""
MediLink Unified App - Single app for patients, doctors, and admins
Role-based interface with intelligent routing
"""

import streamlit as st
from datetime import datetime
from typing import Optional, Dict, Any
import hashlib
import secrets

# Import our existing components
from ..core.agent import AfiCareAgent
from ..utils.config import Config
from ..memory.patient_store import PatientStore

class MediLinkApp:
    """Unified app for all user types"""
    
    def __init__(self):
        self.config = Config()
        self.agent = AfiCareAgent(self.config)
        self.current_user = None
        self.setup_session_state()
    
    def setup_session_state(self):
        """Initialize session state"""
        if 'logged_in' not in st.session_state:
            st.session_state.logged_in = False
        if 'user_role' not in st.session_state:
            st.session_state.user_role = None
        if 'user_data' not in st.session_state:
            st.session_state.user_data = None
        if 'medilink_id' not in st.session_state:
            st.session_state.medilink_id = None
    
    def run(self):
        """Main app entry point"""
        
        st.set_page_config(
            page_title="AfiCare MediLink",
            page_icon="🏥",
            layout="wide"
        )
        
        # Custom CSS for role-based styling
        self.load_custom_css()
        
        if not st.session_state.logged_in:
            self.show_login_page()
        else:
            self.show_dashboard()
    
    def load_custom_css(self):
        """Load role-based CSS styling"""
        st.markdown("""
        <style>
        .patient-theme { background: linear-gradient(90deg, #4CAF50, #45a049); }
        .doctor-theme { background: linear-gradient(90deg, #2196F3, #1976D2); }
        .admin-theme { background: linear-gradient(90deg, #FF9800, #F57C00); }
        .nurse-theme { background: linear-gradient(90deg, #9C27B0, #7B1FA2); }
        
        .main-header {
            padding: 1rem;
            border-radius: 10px;
            color: white;
            text-align: center;
            margin-bottom: 2rem;
        }
        
        .medilink-id {
            background: #f0f8ff;
            padding: 1rem;
            border-radius: 8px;
            border-left: 4px solid #2196F3;
            margin: 1rem 0;
        }
        
        .role-badge {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 15px;
            font-size: 0.8rem;
            font-weight: bold;
            margin-left: 1rem;
        }
        
        .patient-badge { background: #4CAF50; color: white; }
        .doctor-badge { background: #2196F3; color: white; }
        .admin-badge { background: #FF9800; color: white; }
        .nurse-badge { background: #9C27B0; color: white; }
        </style>
        """, unsafe_allow_html=True)
    
    def show_login_page(self):
        """Display login/registration page"""
        
        # Header
        theme_class = "patient-theme"  # Default theme for login
        st.markdown(f"""
        <div class="main-header {theme_class}">
            <h1>🏥 AfiCare MediLink</h1>
            <p>Your Health Records, Your Control</p>
        </div>
        """, unsafe_allow_html=True)
        
        # Login/Register tabs
        tab1, tab2 = st.tabs(["🔐 Login", "📝 Register"])
        
        with tab1:
            self.show_login_form()
        
        with tab2:
            self.show_registration_form()
    
    def show_login_form(self):
        """Login form for all user types"""
        
        st.subheader("Login to AfiCare MediLink")
        
        col1, col2 = st.columns([2, 1])
        
        with col1:
            username = st.text_input("Username or MediLink ID")
            password = st.text_input("Password", type="password")
            
            # Role selection
            role = st.selectbox(
                "Login as:",
                ["Patient", "Doctor", "Nurse", "Clinical Officer", "Admin"]
            )
        
        with col2:
            st.info("""
            **Demo Accounts:**
            
            **Patient:**
            - Username: patient_demo
            - Password: demo123
            - MediLink ID: ML-DEMO-PAT1
            
            **Doctor:**
            - Username: dr_demo
            - Password: demo123
            
            **Admin:**
            - Username: admin_demo
            - Password: demo123
            """)
        
        if st.button("🔐 Login", type="primary"):
            if self.authenticate_user(username, password, role.lower()):
                st.success(f"Welcome back, {st.session_state.user_data['full_name']}!")
                st.rerun()
            else:
                st.error("Invalid credentials. Please try again.")
    
    def show_registration_form(self):
        """Registration form for new patients"""
        
        st.subheader("Register as New Patient")
        st.info("Healthcare providers are registered by hospital administrators")
        
        col1, col2 = st.columns(2)
        
        with col1:
            full_name = st.text_input("Full Name")
            phone = st.text_input("Phone Number")
            email = st.text_input("Email Address")
            
        with col2:
            age = st.number_input("Age", min_value=0, max_value=120, value=25)
            gender = st.selectbox("Gender", ["Male", "Female", "Other"])
            location = st.text_input("Location/City")
        
        # Medical information
        st.subheader("Medical Information (Optional)")
        medical_history = st.text_area("Known medical conditions")
        allergies = st.text_area("Known allergies")
        
        # Create password
        st.subheader("Create Account")
        password = st.text_input("Create Password", type="password")
        confirm_password = st.text_input("Confirm Password", type="password")
        
        # Terms and conditions
        agree_terms = st.checkbox("I agree to the Terms of Service and Privacy Policy")
        
        if st.button("📝 Register", type="primary"):
            if self.register_patient(
                full_name, phone, email, age, gender, location,
                medical_history, allergies, password, confirm_password, agree_terms
            ):
                st.success("Registration successful! Please login with your new MediLink ID.")
                st.rerun()
    
    def authenticate_user(self, username: str, password: str, role: str) -> bool:
        """Authenticate user and set session"""
        
        # Demo accounts for testing
        demo_accounts = {
            "patient_demo": {
                "password": "demo123",
                "role": "patient",
                "full_name": "Demo Patient",
                "medilink_id": "ML-DEMO-PAT1",
                "hospital_id": None
            },
            "dr_demo": {
                "password": "demo123", 
                "role": "doctor",
                "full_name": "Dr. Demo Doctor",
                "medilink_id": None,
                "hospital_id": "HOSP001"
            },
            "admin_demo": {
                "password": "demo123",
                "role": "admin", 
                "full_name": "Admin Demo",
                "medilink_id": None,
                "hospital_id": "HOSP001"
            }
        }
        
        # Check demo accounts
        if username in demo_accounts:
            account = demo_accounts[username]
            if account["password"] == password and account["role"] == role:
                st.session_state.logged_in = True
                st.session_state.user_role = role
                st.session_state.user_data = account
                st.session_state.medilink_id = account.get("medilink_id")
                return True
        
        # TODO: Implement real authentication with database
        return False
    
    def register_patient(self, full_name, phone, email, age, gender, location,
                        medical_history, allergies, password, confirm_password, agree_terms) -> bool:
        """Register new patient"""
        
        # Validation
        if not all([full_name, phone, age, gender, password, confirm_password]):
            st.error("Please fill in all required fields")
            return False
        
        if password != confirm_password:
            st.error("Passwords do not match")
            return False
        
        if not agree_terms:
            st.error("Please agree to the Terms of Service")
            return False
        
        # Generate MediLink ID
        medilink_id = self.generate_medilink_id(location)
        
        # TODO: Save to database
        st.success(f"Registration successful! Your MediLink ID is: {medilink_id}")
        return True
    
    def generate_medilink_id(self, location: str = "") -> str:
        """Generate unique MediLink ID"""
        
        # Location code mapping
        location_codes = {
            "nairobi": "NBO",
            "mombasa": "MSA", 
            "kisumu": "KSM",
            "nakuru": "NKR",
            "eldoret": "ELD"
        }
        
        location_code = location_codes.get(location.lower(), "KEN")
        unique_id = secrets.token_hex(4).upper()
        
        return f"ML-{location_code}-{unique_id}"
    
    def show_dashboard(self):
        """Show role-based dashboard"""
        
        role = st.session_state.user_role
        user_data = st.session_state.user_data
        
        # Role-based header
        theme_class = f"{role}-theme"
        role_badge = f"{role}-badge"
        
        st.markdown(f"""
        <div class="main-header {theme_class}">
            <h1>🏥 AfiCare MediLink</h1>
            <p>{user_data['full_name']} <span class="role-badge {role_badge}">{role.title()}</span></p>
        </div>
        """, unsafe_allow_html=True)
        
        # Logout button in sidebar
        with st.sidebar:
            if st.button("🚪 Logout"):
                self.logout()
                st.rerun()
        
        # Role-based interface
        if role == "patient":
            self.show_patient_dashboard()
        elif role == "doctor":
            self.show_doctor_dashboard()
        elif role == "nurse":
            self.show_nurse_dashboard()
        elif role == "admin":
            self.show_admin_dashboard()
    
    def show_patient_dashboard(self):
        """Patient interface"""
        
        medilink_id = st.session_state.medilink_id
        
        # MediLink ID display
        st.markdown(f"""
        <div class="medilink-id">
            <h3>📋 Your MediLink ID: {medilink_id}</h3>
            <p>This ID contains all your medical records and follows you everywhere</p>
        </div>
        """, unsafe_allow_html=True)
        
        # Navigation tabs
        tab1, tab2, tab3, tab4, tab5 = st.tabs([
            "📊 Health Summary", "🏥 My Visits", "🔐 Privacy Settings", 
            "🏥 Share with Hospital", "📱 Emergency Info"
        ])
        
        with tab1:
            self.show_patient_health_summary()
        
        with tab2:
            self.show_patient_visit_history()
        
        with tab3:
            self.show_patient_privacy_settings()
        
        with tab4:
            self.show_patient_sharing_options()
        
        with tab5:
            self.show_patient_emergency_info()
    
    def show_doctor_dashboard(self):
        """Doctor interface"""
        
        # Navigation tabs
        tab1, tab2, tab3, tab4 = st.tabs([
            "🔍 Patient Access", "👥 My Patients", "📊 Consultations", "⚙️ Settings"
        ])
        
        with tab1:
            self.show_doctor_patient_access()
        
        with tab2:
            self.show_doctor_patient_list()
        
        with tab3:
            self.show_doctor_consultations()
        
        with tab4:
            self.show_doctor_settings()
    
    def show_admin_dashboard(self):
        """Admin interface"""
        
        # Navigation tabs
        tab1, tab2, tab3, tab4 = st.tabs([
            "👥 User Management", "📊 Analytics", "🔒 Security", "⚙️ System Settings"
        ])
        
        with tab1:
            self.show_admin_user_management()
        
        with tab2:
            self.show_admin_analytics()
        
        with tab3:
            self.show_admin_security()
        
        with tab4:
            self.show_admin_settings()
    
    # Patient interface methods
    def show_patient_health_summary(self):
        """Patient health summary"""
        
        st.subheader("📊 Your Health Summary")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Total Visits", "15", "+2 this month")
        
        with col2:
            st.metric("Last Visit", "Jan 15, 2024", "Nairobi Hospital")
        
        with col3:
            st.metric("Health Score", "85%", "+5% improved")
        
        # Recent activity
        st.subheader("Recent Activity")
        
        activities = [
            {"date": "Jan 15, 2024", "type": "Consultation", "hospital": "Nairobi Hospital", "diagnosis": "Malaria (treated)"},
            {"date": "Dec 10, 2023", "type": "Check-up", "hospital": "Kenyatta Hospital", "diagnosis": "Routine examination"},
            {"date": "Nov 05, 2023", "type": "Vaccination", "hospital": "Local Clinic", "diagnosis": "COVID-19 booster"}
        ]
        
        for activity in activities:
            with st.expander(f"{activity['date']} - {activity['type']} at {activity['hospital']}"):
                st.write(f"**Diagnosis:** {activity['diagnosis']}")
                st.write(f"**Hospital:** {activity['hospital']}")
                st.write(f"**Date:** {activity['date']}")
    
    def show_patient_sharing_options(self):
        """Patient sharing interface"""
        
        st.subheader("🏥 Share Records with Hospital")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.write("**Generate Access Code**")
            if st.button("🔢 Generate 6-Digit Code"):
                access_code = secrets.randbelow(900000) + 100000
                st.success(f"Access Code: **{access_code}**")
                st.info("Valid for 24 hours. Share this code with your healthcare provider.")
        
        with col2:
            st.write("**QR Code Sharing**")
            if st.button("📱 Generate QR Code"):
                st.success("QR Code generated!")
                st.info("Show this QR code to hospital staff for instant access.")
    
    # Doctor interface methods
    def show_doctor_patient_access(self):
        """Doctor patient access interface"""
        
        st.subheader("🔍 Access Patient Records")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.write("**Search by MediLink ID**")
            medilink_id = st.text_input("Enter MediLink ID", placeholder="ML-XXXX-YYYY")
            
            if st.button("🔍 Search Patient"):
                if medilink_id:
                    st.success(f"Patient found: {medilink_id}")
                    # TODO: Load patient records
                else:
                    st.error("Please enter a valid MediLink ID")
        
        with col2:
            st.write("**Access with Patient Code**")
            access_code = st.text_input("Enter 6-digit access code", placeholder="123456")
            
            if st.button("🔓 Access Records"):
                if access_code and len(access_code) == 6:
                    st.success("Access granted!")
                    # TODO: Load patient records
                else:
                    st.error("Please enter a valid 6-digit code")
    
    def logout(self):
        """Logout user"""
        st.session_state.logged_in = False
        st.session_state.user_role = None
        st.session_state.user_data = None
        st.session_state.medilink_id = None

# Placeholder methods for other interfaces
    def show_patient_visit_history(self): pass
    def show_patient_privacy_settings(self): pass
    def show_patient_emergency_info(self): pass
    def show_doctor_patient_list(self): pass
    def show_doctor_consultations(self): pass
    def show_doctor_settings(self): pass
    def show_nurse_dashboard(self): pass
    def show_admin_user_management(self): pass
    def show_admin_analytics(self): pass
    def show_admin_security(self): pass
    def show_admin_settings(self): pass

if __name__ == "__main__":
    app = MediLinkApp()
    app.run()