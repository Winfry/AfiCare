"""
MediLink Unified App - Single app for patients, doctors, and admins
Role-based interface with intelligent routing
"""

import streamlit as st
from datetime import datetime
from typing import Optional, Dict, Any
import hashlib
import secrets
import sys
from pathlib import Path

# Add src to path for imports
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

class MediLinkApp:
    """Unified app for all user types"""
    
    def __init__(self):
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
        
        .access-code {
            background: #e8f5e8;
            padding: 1rem;
            border-radius: 8px;
            text-align: center;
            font-size: 1.5rem;
            font-weight: bold;
            border: 2px solid #4CAF50;
        }
        
        .patient-card {
            background: #f8f9fa;
            padding: 1rem;
            border-radius: 8px;
            border-left: 4px solid #2E8B57;
            margin-bottom: 1rem;
        }
        </style>
        """, unsafe_allow_html=True)
    
    def show_login_page(self):
        """Display login/registration page"""
        
        # Header
        theme_class = "patient-theme"  # Default theme for login
        st.markdown(f"""
        <div class="main-header {theme_class}">
            <h1>🏥 AfiCare MediLink</h1>
            <p>Your Health Records, Your Control - Completely FREE</p>
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
            - MediLink ID: ML-NBO-DEMO1
            
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
        
        st.subheader("Register as New Patient - FREE")
        st.info("Healthcare providers are registered by hospital administrators")
        
        col1, col2 = st.columns(2)
        
        with col1:
            full_name = st.text_input("Full Name *")
            phone = st.text_input("Phone Number *")
            email = st.text_input("Email Address")
            
        with col2:
            age = st.number_input("Age *", min_value=0, max_value=120, value=25)
            gender = st.selectbox("Gender *", ["Male", "Female", "Other"])
            location = st.selectbox("Location/City", [
                "Nairobi", "Mombasa", "Kisumu", "Nakuru", "Eldoret", "Other"
            ])
        
        # Medical information
        st.subheader("Medical Information (Optional)")
        medical_history = st.text_area("Known medical conditions (e.g., Diabetes, Hypertension)")
        allergies = st.text_area("Known allergies (e.g., Penicillin, Sulfa drugs)")
        
        # Emergency contact
        st.subheader("Emergency Contact")
        emergency_name = st.text_input("Emergency contact name")
        emergency_phone = st.text_input("Emergency contact phone")
        
        # Create password
        st.subheader("Create Account")
        password = st.text_input("Create Password *", type="password")
        confirm_password = st.text_input("Confirm Password *", type="password")
        
        # Terms and conditions
        agree_terms = st.checkbox("I agree to the Terms of Service and Privacy Policy")
        
        if st.button("📝 Register FREE Account", type="primary"):
            if self.register_patient(
                full_name, phone, email, age, gender, location,
                medical_history, allergies, emergency_name, emergency_phone,
                password, confirm_password, agree_terms
            ):
                st.balloons()
                st.success("Registration successful! Please login with your new MediLink ID.")
    
    def authenticate_user(self, username: str, password: str, role: str) -> bool:
        """Authenticate user and set session"""
        
        # Demo accounts for testing
        demo_accounts = {
            "patient_demo": {
                "password": "demo123",
                "role": "patient",
                "full_name": "John Doe",
                "medilink_id": "ML-NBO-DEMO1",
                "hospital_id": None,
                "phone": "+254712345678",
                "email": "john.doe@example.com"
            },
            "ML-NBO-DEMO1": {  # Allow login with MediLink ID
                "password": "demo123",
                "role": "patient", 
                "full_name": "John Doe",
                "medilink_id": "ML-NBO-DEMO1",
                "hospital_id": None,
                "phone": "+254712345678",
                "email": "john.doe@example.com"
            },
            "dr_demo": {
                "password": "demo123",
                "role": "doctor",
                "full_name": "Dr. Mary Wanjiku",
                "medilink_id": None,
                "hospital_id": "HOSP001",
                "department": "Internal Medicine"
            },
            "nurse_demo": {
                "password": "demo123",
                "role": "nurse",
                "full_name": "Nurse Jane Akinyi", 
                "medilink_id": None,
                "hospital_id": "HOSP001",
                "department": "Emergency"
            },
            "admin_demo": {
                "password": "demo123",
                "role": "admin",
                "full_name": "Admin Peter Kamau",
                "medilink_id": None,
                "hospital_id": "HOSP001",
                "department": "Administration"
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
        
        return False
    
    def register_patient(self, full_name, phone, email, age, gender, location,
                        medical_history, allergies, emergency_name, emergency_phone,
                        password, confirm_password, agree_terms) -> bool:
        """Register new patient"""
        
        # Validation
        if not all([full_name, phone, age, gender, password, confirm_password]):
            st.error("Please fill in all required fields marked with *")
            return False
        
        if password != confirm_password:
            st.error("Passwords do not match")
            return False
        
        if len(password) < 6:
            st.error("Password must be at least 6 characters")
            return False
        
        if not agree_terms:
            st.error("Please agree to the Terms of Service")
            return False
        
        # Generate MediLink ID
        medilink_id = self.generate_medilink_id(location)
        
        # Display success with MediLink ID
        st.markdown(f"""
        <div class="medilink-id">
            <h3>🎉 Registration Successful!</h3>
            <p><strong>Your MediLink ID:</strong> {medilink_id}</p>
            <p>Save this ID - it's your key to accessing your health records anywhere!</p>
        </div>
        """, unsafe_allow_html=True)
        
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
            st.write(f"**Logged in as:** {role.title()}")
            if role == "patient" and st.session_state.medilink_id:
                st.write(f"**MediLink ID:** {st.session_state.medilink_id}")
            
            if st.button("🚪 Logout"):
                self.logout()
                st.rerun()
        
        # Role-based interface
        if role == "patient":
            self.show_patient_dashboard()
        elif role in ["doctor", "nurse", "clinical officer"]:
            self.show_healthcare_provider_dashboard()
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
            "📊 Health Summary", "🏥 My Visits", "🔐 Share with Hospital", 
            "⚙️ Privacy Settings", "🚨 Emergency Info"
        ])
        
        with tab1:
            self.show_patient_health_summary()
        
        with tab2:
            self.show_patient_visit_history()
        
        with tab3:
            self.show_patient_sharing_options()
        
        with tab4:
            self.show_patient_privacy_settings()
        
        with tab5:
            self.show_patient_emergency_info()
    
    def show_healthcare_provider_dashboard(self):
        """Healthcare provider interface (doctor, nurse, clinical officer)"""
        
        role = st.session_state.user_role
        user_data = st.session_state.user_data
        
        # Navigation tabs
        tab1, tab2, tab3, tab4 = st.tabs([
            "🔍 Access Patient", "👥 My Patients", "📋 New Consultation", "📊 Statistics"
        ])
        
        with tab1:
            self.show_provider_patient_access()
        
        with tab2:
            self.show_provider_patient_list()
        
        with tab3:
            self.show_provider_new_consultation()
        
        with tab4:
            self.show_provider_statistics()
    
    def show_admin_dashboard(self):
        """Admin interface"""
        
        # Navigation tabs
        tab1, tab2, tab3, tab4 = st.tabs([
            "👥 User Management", "📊 Hospital Analytics", "🔒 Security & Audit", "⚙️ System Settings"
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
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("Total Visits", "15", "+2 this month")
        
        with col2:
            st.metric("Last Visit", "Jan 15, 2024", "Nairobi Hospital")
        
        with col3:
            st.metric("Active Medications", "2", "Metformin, Lisinopril")
        
        with col4:
            st.metric("Health Score", "85%", "+5% improved")
        
        # Health trends
        st.subheader("📈 Health Trends")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.write("**Recent Vital Signs**")
            vital_data = {
                "Date": ["Jan 15", "Dec 10", "Nov 05"],
                "Blood Pressure": ["120/80", "125/82", "130/85"],
                "Weight (kg)": [70, 72, 74],
                "Temperature (°C)": [36.8, 37.0, 36.9]
            }
            st.dataframe(vital_data)
        
        with col2:
            st.write("**Recent Diagnoses**")
            diagnoses = [
                {"Date": "Jan 15, 2024", "Condition": "Malaria", "Status": "Treated ✅"},
                {"Date": "Dec 10, 2023", "Condition": "Hypertension", "Status": "Managed 🔄"},
                {"Date": "Nov 05, 2023", "Condition": "Routine Check", "Status": "Normal ✅"}
            ]
            
            for diagnosis in diagnoses:
                st.write(f"**{diagnosis['Date']}:** {diagnosis['Condition']} - {diagnosis['Status']}")
    
    def show_patient_visit_history(self):
        """Patient visit history"""
        
        st.subheader("🏥 Your Medical Visit History")
        
        visits = [
            {
                "date": "Jan 15, 2024",
                "hospital": "Nairobi General Hospital",
                "doctor": "Dr. Mary Wanjiku",
                "chief_complaint": "Fever and headache for 3 days",
                "diagnosis": "Malaria",
                "treatment": "Artemether-Lumefantrine 3 days",
                "triage": "URGENT",
                "vitals": "Temp: 39.2°C, BP: 120/80, Pulse: 95"
            },
            {
                "date": "Dec 10, 2023", 
                "hospital": "Kenyatta National Hospital",
                "doctor": "Dr. John Kamau",
                "chief_complaint": "Routine diabetes check-up",
                "diagnosis": "Type 2 Diabetes - well controlled",
                "treatment": "Continue Metformin, lifestyle counseling",
                "triage": "ROUTINE",
                "vitals": "Temp: 36.8°C, BP: 125/82, Pulse: 78"
            },
            {
                "date": "Nov 05, 2023",
                "hospital": "Eastleigh Health Center", 
                "doctor": "Clinical Officer Peter",
                "chief_complaint": "COVID-19 vaccination",
                "diagnosis": "Vaccination - no adverse reactions",
                "treatment": "COVID-19 booster dose administered",
                "triage": "ROUTINE",
                "vitals": "Temp: 36.9°C, BP: 130/85, Pulse: 80"
            }
        ]
        
        for visit in visits:
            with st.expander(f"{visit['date']} - {visit['hospital']} ({visit['triage']})"):
                col1, col2 = st.columns(2)
                
                with col1:
                    st.write(f"**Doctor:** {visit['doctor']}")
                    st.write(f"**Chief Complaint:** {visit['chief_complaint']}")
                    st.write(f"**Diagnosis:** {visit['diagnosis']}")
                
                with col2:
                    st.write(f"**Treatment:** {visit['treatment']}")
                    st.write(f"**Vital Signs:** {visit['vitals']}")
                    st.write(f"**Triage Level:** {visit['triage']}")
    
    def show_patient_sharing_options(self):
        """Patient sharing interface"""
        
        st.subheader("🏥 Share Your Records with Healthcare Providers")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.write("**🔢 Generate Access Code**")
            st.info("Create a temporary code for hospital staff to access your records")
            
            duration = st.selectbox("Code valid for:", ["1 hour", "24 hours", "1 week"])
            
            if st.button("🔢 Generate Access Code", type="primary"):
                access_code = secrets.randbelow(900000) + 100000
                st.markdown(f"""
                <div class="access-code">
                    Access Code: {access_code}
                </div>
                """, unsafe_allow_html=True)
                st.success(f"Code valid for {duration}. Share this with your healthcare provider.")
        
        with col2:
            st.write("**📱 QR Code Sharing**")
            st.info("Generate QR code for instant access at the hospital")
            
            include_full = st.checkbox("Include full medical history")
            
            if st.button("📱 Generate QR Code", type="primary"):
                st.success("QR Code generated!")
                st.info("📱 Show this QR code to hospital staff for instant access to your records.")
                # TODO: Generate actual QR code
        
        # Active sharing permissions
        st.subheader("🔐 Active Sharing Permissions")
        
        permissions = [
            {"hospital": "Nairobi General Hospital", "granted": "Jan 15, 2024", "expires": "Jan 22, 2024", "type": "Full Access"},
            {"hospital": "Dr. Mary Wanjiku", "granted": "Dec 10, 2023", "expires": "Never", "type": "Ongoing Care"}
        ]
        
        for perm in permissions:
            col1, col2, col3 = st.columns([3, 2, 1])
            
            with col1:
                st.write(f"**{perm['hospital']}**")
                st.write(f"Type: {perm['type']}")
            
            with col2:
                st.write(f"Granted: {perm['granted']}")
                st.write(f"Expires: {perm['expires']}")
            
            with col3:
                if st.button("🗑️ Revoke", key=f"revoke_{perm['hospital']}"):
                    st.success("Access revoked!")
    
    def show_patient_privacy_settings(self):
        """Patient privacy settings"""
        
        st.subheader("⚙️ Privacy & Security Settings")
        
        # Privacy preferences
        st.write("**🔒 Privacy Preferences**")
        
        emergency_access = st.checkbox("Allow emergency access when unconscious", value=True)
        research_data = st.checkbox("Allow anonymized data for medical research", value=False)
        marketing = st.checkbox("Receive health tips and updates", value=True)
        
        # Data sharing controls
        st.write("**📊 Data Sharing Controls**")
        
        share_vitals = st.checkbox("Share vital signs trends with doctors", value=True)
        share_history = st.checkbox("Share full medical history", value=True)
        share_medications = st.checkbox("Share current medications", value=True)
        share_allergies = st.checkbox("Share allergy information", value=True)
        
        # Security settings
        st.write("**🔐 Security Settings**")
        
        col1, col2 = st.columns(2)
        
        with col1:
            if st.button("🔑 Change Password"):
                st.info("Password change functionality coming soon")
        
        with col2:
            if st.button("📱 Setup 2-Factor Authentication"):
                st.info("2FA setup coming soon")
        
        # Save settings
        if st.button("💾 Save Privacy Settings", type="primary"):
            st.success("Privacy settings saved successfully!")
    
    def show_patient_emergency_info(self):
        """Patient emergency information"""
        
        st.subheader("🚨 Emergency Information")
        
        st.warning("This information is accessible to healthcare providers during emergencies")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.write("**🩸 Critical Medical Information**")
            
            blood_type = st.selectbox("Blood Type", ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"], index=0)
            
            st.write("**🚫 Critical Allergies**")
            allergies = st.text_area("Life-threatening allergies", value="Penicillin\nSulfa drugs")
            
            st.write("**💊 Critical Medications**")
            medications = st.text_area("Current medications", value="Metformin 500mg twice daily\nLisinopril 10mg once daily")
        
        with col2:
            st.write("**📞 Emergency Contacts**")
            
            contact1_name = st.text_input("Primary contact name", value="Jane Doe (Wife)")
            contact1_phone = st.text_input("Primary contact phone", value="+254712345679")
            
            contact2_name = st.text_input("Secondary contact name", value="Dr. Mary Wanjiku")
            contact2_phone = st.text_input("Secondary contact phone", value="+254700123456")
            
            st.write("**🏥 Preferred Hospital**")
            preferred_hospital = st.text_input("Preferred hospital", value="Nairobi General Hospital")
        
        if st.button("💾 Update Emergency Information", type="primary"):
            st.success("Emergency information updated successfully!")
    
    # Healthcare provider interface methods
    def show_provider_patient_access(self):
        """Healthcare provider patient access"""
        
        st.subheader("🔍 Access Patient Records")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.write("**Search by MediLink ID**")
            medilink_id = st.text_input("Enter MediLink ID", placeholder="ML-NBO-XXXX")
            
            if st.button("🔍 Search Patient", type="primary"):
                if medilink_id:
                    if medilink_id == "ML-NBO-DEMO1":
                        self.show_patient_records_for_provider(medilink_id)
                    else:
                        st.error("Patient not found or access denied")
                else:
                    st.error("Please enter a valid MediLink ID")
        
        with col2:
            st.write("**Access with Patient Code**")
            access_code = st.text_input("Enter 6-digit access code", placeholder="123456")
            
            if st.button("🔓 Access with Code", type="primary"):
                if access_code and len(access_code) == 6:
                    # Demo: any 6-digit code works
                    self.show_patient_records_for_provider("ML-NBO-DEMO1")
                else:
                    st.error("Please enter a valid 6-digit code")
    
    def show_patient_records_for_provider(self, medilink_id: str):
        """Show patient records to healthcare provider"""
        
        st.success(f"✅ Access granted to patient records: {medilink_id}")
        
        # Patient summary
        st.markdown(f"""
        <div class="patient-card">
            <h3>👤 Patient: John Doe (ML-NBO-DEMO1)</h3>
            <p><strong>Age:</strong> 35 | <strong>Gender:</strong> Male | <strong>Blood Type:</strong> O+</p>
            <p><strong>Phone:</strong> +254712345678 | <strong>Emergency Contact:</strong> Jane Doe (+254712345679)</p>
        </div>
        """, unsafe_allow_html=True)
        
        # Critical alerts
        st.error("🚨 **ALLERGIES:** Penicillin, Sulfa drugs")
        st.warning("💊 **CURRENT MEDICATIONS:** Metformin 500mg, Lisinopril 10mg")
        
        # Medical history tabs
        tab1, tab2, tab3, tab4 = st.tabs(["📋 Recent Visits", "📊 Vital Trends", "💊 Medications", "🧪 Lab Results"])
        
        with tab1:
            st.write("**Recent Medical Visits**")
            visits = [
                {"date": "Jan 15, 2024", "hospital": "Nairobi General", "diagnosis": "Malaria", "doctor": "Dr. Mary Wanjiku"},
                {"date": "Dec 10, 2023", "hospital": "Kenyatta National", "diagnosis": "Diabetes checkup", "doctor": "Dr. John Kamau"}
            ]
            
            for visit in visits:
                st.write(f"• **{visit['date']}** - {visit['diagnosis']} at {visit['hospital']} (Dr: {visit['doctor']})")
        
        with tab2:
            st.write("**Vital Signs Trends**")
            vital_data = {
                "Date": ["Jan 15", "Dec 10", "Nov 05"],
                "BP": ["120/80", "125/82", "130/85"],
                "Temp": ["39.2°C", "36.8°C", "36.9°C"],
                "Weight": ["70kg", "72kg", "74kg"]
            }
            st.dataframe(vital_data)
        
        with tab3:
            st.write("**Current Medications**")
            st.write("• Metformin 500mg - Twice daily (for diabetes)")
            st.write("• Lisinopril 10mg - Once daily (for hypertension)")
        
        with tab4:
            st.write("**Recent Lab Results**")
            st.write("• **Jan 15, 2024:** Malaria RDT - Positive")
            st.write("• **Dec 10, 2023:** HbA1c - 7.2% (good control)")
            st.write("• **Nov 05, 2023:** Lipid profile - Normal")
    
    def show_provider_patient_list(self):
        """Show provider's patient list"""
        
        st.subheader("👥 My Recent Patients")
        
        patients = [
            {"id": "ML-NBO-DEMO1", "name": "John Doe", "last_visit": "Jan 15, 2024", "condition": "Malaria"},
            {"id": "ML-MSA-ABC123", "name": "Mary Smith", "last_visit": "Jan 14, 2024", "condition": "Hypertension"},
            {"id": "ML-KSM-DEF456", "name": "Peter Ochieng", "last_visit": "Jan 13, 2024", "condition": "Diabetes"}
        ]
        
        for patient in patients:
            col1, col2, col3, col4 = st.columns([2, 2, 2, 1])
            
            with col1:
                st.write(f"**{patient['name']}**")
                st.write(f"ID: {patient['id']}")
            
            with col2:
                st.write(f"Last visit: {patient['last_visit']}")
            
            with col3:
                st.write(f"Condition: {patient['condition']}")
            
            with col4:
                if st.button("👁️ View", key=f"view_{patient['id']}"):
                    self.show_patient_records_for_provider(patient['id'])
    
    def show_provider_new_consultation(self):
        """New consultation interface"""
        
        st.subheader("📋 New Patient Consultation")
        
        # Patient identification
        st.write("**👤 Patient Identification**")
        col1, col2 = st.columns(2)
        
        with col1:
            medilink_id = st.text_input("MediLink ID", placeholder="ML-XXX-XXXX")
        
        with col2:
            access_code = st.text_input("Or Access Code", placeholder="123456")
        
        if st.button("🔍 Load Patient"):
            if medilink_id or access_code:
                st.success("Patient loaded: John Doe (ML-NBO-DEMO1)")
                
                # Consultation form (simplified version of our existing consultation)
                st.write("**🗣️ Chief Complaint**")
                chief_complaint = st.text_area("What is the main problem?")
                
                st.write("**🔍 Symptoms**")
                col1, col2 = st.columns(2)
                
                with col1:
                    fever = st.checkbox("Fever")
                    cough = st.checkbox("Cough") 
                    headache = st.checkbox("Headache")
                    nausea = st.checkbox("Nausea")
                
                with col2:
                    chest_pain = st.checkbox("Chest pain")
                    difficulty_breathing = st.checkbox("Difficulty breathing")
                    fatigue = st.checkbox("Fatigue")
                    dizziness = st.checkbox("Dizziness")
                
                st.write("**🌡️ Vital Signs**")
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    temperature = st.number_input("Temperature (°C)", value=37.0)
                
                with col2:
                    systolic_bp = st.number_input("Systolic BP", value=120)
                    diastolic_bp = st.number_input("Diastolic BP", value=80)
                
                with col3:
                    pulse = st.number_input("Pulse (bpm)", value=80)
                    resp_rate = st.number_input("Respiratory Rate", value=16)
                
                if st.button("🤖 Analyze with AI", type="primary"):
                    st.success("🎯 AI Analysis Complete!")
                    
                    # Mock AI results
                    st.write("**🔍 Suspected Conditions:**")
                    st.write("1. **Malaria** - 85% confidence")
                    st.write("2. **Viral fever** - 60% confidence")
                    
                    st.write("**⚠️ Triage Level:** URGENT")
                    
                    st.write("**💊 Recommendations:**")
                    st.write("• Artemether-Lumefantrine based on weight")
                    st.write("• Paracetamol for fever")
                    st.write("• Oral rehydration therapy")
                    
                    if st.button("💾 Save Consultation"):
                        st.success("Consultation saved to patient's MediLink record!")
    
    def show_provider_statistics(self):
        """Provider statistics"""
        
        st.subheader("📊 My Statistics")
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("Patients Today", "12", "+3")
        
        with col2:
            st.metric("This Week", "67", "+15")
        
        with col3:
            st.metric("Emergency Cases", "3", "+1")
        
        with col4:
            st.metric("Follow-ups Due", "8", "-2")
        
        # Common conditions chart
        st.write("**📈 Common Conditions This Month**")
        conditions_data = {
            "Condition": ["Malaria", "Hypertension", "Diabetes", "Pneumonia", "Common Cold"],
            "Cases": [25, 18, 15, 12, 20]
        }
        st.bar_chart(conditions_data)
    
    # Admin interface methods (simplified)
    def show_admin_user_management(self):
        """Admin user management"""
        
        st.subheader("👥 User Management")
        
        # Add new healthcare provider
        st.write("**➕ Add New Healthcare Provider**")
        
        col1, col2 = st.columns(2)
        
        with col1:
            full_name = st.text_input("Full Name")
            username = st.text_input("Username")
            role = st.selectbox("Role", ["Doctor", "Nurse", "Clinical Officer"])
        
        with col2:
            department = st.text_input("Department")
            phone = st.text_input("Phone")
            email = st.text_input("Email")
        
        if st.button("➕ Add User"):
            st.success(f"User {full_name} added successfully!")
        
        # User list
        st.write("**👥 Current Users**")
        users = [
            {"name": "Dr. Mary Wanjiku", "role": "Doctor", "department": "Internal Medicine", "status": "Active"},
            {"name": "Nurse Jane Akinyi", "role": "Nurse", "department": "Emergency", "status": "Active"},
            {"name": "Dr. John Kamau", "role": "Doctor", "department": "Pediatrics", "status": "Active"}
        ]
        
        for user in users:
            col1, col2, col3, col4 = st.columns([2, 1, 2, 1])
            
            with col1:
                st.write(f"**{user['name']}**")
            
            with col2:
                st.write(user['role'])
            
            with col3:
                st.write(user['department'])
            
            with col4:
                st.write(f"✅ {user['status']}")
    
    def show_admin_analytics(self):
        """Admin analytics"""
        
        st.subheader("📊 Hospital Analytics")
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("Total Patients", "1,234", "+56 this month")
        
        with col2:
            st.metric("Active Users", "45", "+3 new")
        
        with col3:
            st.metric("Consultations Today", "89", "+12")
        
        with col4:
            st.metric("System Uptime", "99.9%", "30 days")
    
    def show_admin_security(self):
        """Admin security"""
        
        st.subheader("🔒 Security & Audit")
        
        st.write("**📋 Recent Access Log**")
        logs = [
            {"time": "14:30", "user": "Dr. Mary", "action": "Accessed patient ML-NBO-DEMO1", "ip": "192.168.1.100"},
            {"time": "14:25", "user": "Nurse Jane", "action": "Created new consultation", "ip": "192.168.1.101"},
            {"time": "14:20", "user": "Patient John", "action": "Generated access code", "ip": "41.90.x.x"}
        ]
        
        for log in logs:
            st.write(f"**{log['time']}** - {log['user']}: {log['action']} (IP: {log['ip']})")
    
    def show_admin_settings(self):
        """Admin settings"""
        
        st.subheader("⚙️ System Settings")
        
        st.write("**🏥 Hospital Information**")
        hospital_name = st.text_input("Hospital Name", value="Nairobi General Hospital")
        hospital_location = st.text_input("Location", value="Nairobi, Kenya")
        
        st.write("**🔐 Security Settings**")
        session_timeout = st.number_input("Session timeout (hours)", value=8)
        require_2fa = st.checkbox("Require 2-factor authentication")
        
        if st.button("💾 Save Settings"):
            st.success("Settings saved successfully!")
    
    def logout(self):
        """Logout user"""
        st.session_state.logged_in = False
        st.session_state.user_role = None
        st.session_state.user_data = None
        st.session_state.medilink_id = None

if __name__ == "__main__":
    app = MediLinkApp()
    app.run()