"""
MediLink Simple - Simplified version to avoid port issues
Single app for patients, doctors, and admins with role-based interface
"""

import streamlit as st
from datetime import datetime
import secrets

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize session state
if 'logged_in' not in st.session_state:
    st.session_state.logged_in = False
if 'user_role' not in st.session_state:
    st.session_state.user_role = None
if 'user_data' not in st.session_state:
    st.session_state.user_data = None
if 'medilink_id' not in st.session_state:
    st.session_state.medilink_id = None

# Custom CSS
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

.demo-alert {
    background: #fff3cd;
    border: 1px solid #ffeaa7;
    border-radius: 8px;
    padding: 1rem;
    margin: 1rem 0;
}
</style>
""", unsafe_allow_html=True)

def authenticate_user(username: str, password: str, role: str) -> bool:
    """Authenticate user and set session"""
    
    # Demo accounts for testing
    demo_accounts = {
        "patient_demo": {
            "password": "demo123",
            "role": "patient",
            "full_name": "John Doe",
            "medilink_id": "ML-NBO-DEMO1",
            "phone": "+254712345678",
            "email": "john.doe@example.com"
        },
        "ML-NBO-DEMO1": {  # Allow login with MediLink ID
            "password": "demo123",
            "role": "patient", 
            "full_name": "John Doe",
            "medilink_id": "ML-NBO-DEMO1",
            "phone": "+254712345678",
            "email": "john.doe@example.com"
        },
        "dr_demo": {
            "password": "demo123",
            "role": "doctor",
            "full_name": "Dr. Mary Wanjiku",
            "hospital_id": "HOSP001",
            "department": "Internal Medicine"
        },
        "nurse_demo": {
            "password": "demo123",
            "role": "nurse",
            "full_name": "Nurse Jane Akinyi", 
            "hospital_id": "HOSP001",
            "department": "Emergency"
        },
        "admin_demo": {
            "password": "demo123",
            "role": "admin",
            "full_name": "Admin Peter Kamau",
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

def generate_medilink_id(location: str = "") -> str:
    """Generate unique MediLink ID"""
    
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

def show_login_page():
    """Display login/registration page"""
    
    # Header
    st.markdown("""
    <div class="main-header patient-theme">
        <h1>🏥 AfiCare MediLink</h1>
        <p>Your Health Records, Your Control - Completely FREE</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Demo alert
    st.markdown("""
    <div class="demo-alert">
        <h4>🎯 DEMO VERSION - Try It Now!</h4>
        <p>This is a working prototype of the MediLink system. Use the demo accounts below to explore different user roles.</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Login/Register tabs
    tab1, tab2 = st.tabs(["🔐 Login", "📝 Register"])
    
    with tab1:
        show_login_form()
    
    with tab2:
        show_registration_form()

def show_login_form():
    """Login form for all user types"""
    
    st.subheader("Login to AfiCare MediLink")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        username = st.text_input("Username or MediLink ID")
        password = st.text_input("Password", type="password")
        
        # Role selection
        role = st.selectbox(
            "Login as:",
            ["patient", "doctor", "nurse", "admin"],
            format_func=lambda x: x.title()
        )
    
    with col2:
        st.info("""
        **🎯 Demo Accounts:**
        
        **👤 Patient:**
        - Username: `patient_demo`
        - Password: `demo123`
        - MediLink ID: `ML-NBO-DEMO1`
        
        **👨‍⚕️ Doctor:**
        - Username: `dr_demo`
        - Password: `demo123`
        
        **👩‍⚕️ Nurse:**
        - Username: `nurse_demo`
        - Password: `demo123`
        
        **⚙️ Admin:**
        - Username: `admin_demo`
        - Password: `demo123`
        """)
    
    if st.button("🔐 Login", type="primary"):
        # Validate input fields
        if not username or not username.strip():
            st.error("❌ **Username or MediLink ID** is required")
        elif not password or not password.strip():
            st.error("❌ **Password** is required")
        elif not role:
            st.error("❌ **Role** must be selected")
        else:
            # Attempt authentication
            if authenticate_user(username, password, role):
                st.success(f"✅ Welcome back, {st.session_state.user_data['full_name']}!")
                st.rerun()
            else:
                st.error("❌ **Invalid credentials.** Please check:")
                st.write("• Username/MediLink ID is correct")
                st.write("• Password is correct") 
                st.write("• Role matches your account type")
                st.write("• Try the demo accounts shown on the right →")

def show_registration_form():
    """Registration form for new patients"""
    
    st.subheader("Register as New Patient - FREE")
    st.info("Healthcare providers are registered by hospital administrators")
    
    col1, col2 = st.columns(2)
    
    with col1:
        full_name = st.text_input("Full Name *", help="Enter your complete legal name")
        phone = st.text_input("Phone Number *", placeholder="+254712345678", help="Include country code if international")
        email = st.text_input("Email Address", placeholder="your.email@example.com", help="Optional but recommended for account recovery")
        
    with col2:
        age = st.number_input("Age *", min_value=0, max_value=120, value=25, help="Your age in years")
        gender = st.selectbox("Gender *", ["Male", "Female", "Other"], help="Select your gender")
        location = st.selectbox("Location/City", [
            "Nairobi", "Mombasa", "Kisumu", "Nakuru", "Eldoret", "Other"
        ], help="Your primary location - affects your MediLink ID")
    
    # Medical information
    st.subheader("Medical Information (Optional)")
    medical_history = st.text_area("Known medical conditions", placeholder="e.g., Diabetes, Hypertension, Asthma", help="List any ongoing medical conditions")
    allergies = st.text_area("Known allergies", placeholder="e.g., Penicillin, Sulfa drugs, Peanuts", help="List any known allergies - this is important for emergency care")
    
    # Emergency contact
    st.subheader("Emergency Contact (Optional but Recommended)")
    emergency_name = st.text_input("Emergency contact name", placeholder="e.g., Jane Doe (Wife)", help="Person to contact in case of emergency")
    emergency_phone = st.text_input("Emergency contact phone", placeholder="+254712345679", help="Phone number of emergency contact")
    
    # Create password
    st.subheader("Create Account")
    password = st.text_input("Create Password *", type="password", help="Minimum 6 characters")
    confirm_password = st.text_input("Confirm Password *", type="password", help="Re-enter the same password")
    
    # Terms and conditions
    agree_terms = st.checkbox("I agree to the Terms of Service and Privacy Policy *", help="Required to create account")
    
    if st.button("📝 Register FREE Account", type="primary"):
        # Detailed validation with specific error messages
        errors = []
        
        if not full_name or not full_name.strip():
            errors.append("❌ **Full Name** is required")
        
        if not phone or not phone.strip():
            errors.append("❌ **Phone Number** is required")
        elif len(phone.strip()) < 10:
            errors.append("❌ **Phone Number** must be at least 10 digits")
        
        if not age or age <= 0:
            errors.append("❌ **Age** must be greater than 0")
        
        if not gender:
            errors.append("❌ **Gender** must be selected")
        
        if not password or not password.strip():
            errors.append("❌ **Password** is required")
        elif len(password) < 6:
            errors.append("❌ **Password** must be at least 6 characters long")
        
        if not confirm_password or not confirm_password.strip():
            errors.append("❌ **Confirm Password** is required")
        elif password != confirm_password:
            errors.append("❌ **Passwords do not match** - please check both password fields")
        
        if not agree_terms:
            errors.append("❌ **Terms of Service** - you must agree to continue")
        
        # Show specific errors or proceed with registration
        if errors:
            st.error("**Please fix the following issues:**")
            for error in errors:
                st.write(error)
        else:
            # All validation passed - register the user
            medilink_id = generate_medilink_id(location)
            st.balloons()
            st.markdown(f"""
            <div class="medilink-id">
                <h3>🎉 Registration Successful!</h3>
                <p><strong>Your MediLink ID:</strong> {medilink_id}</p>
                <p><strong>Full Name:</strong> {full_name}</p>
                <p><strong>Phone:</strong> {phone}</p>
                <p><strong>Location:</strong> {location}</p>
                <p>Save this ID - it's your key to accessing your health records anywhere!</p>
                <p><em>You can now login using either your MediLink ID or username "patient_demo"</em></p>
            </div>
            """, unsafe_allow_html=True)
            
            st.success("✅ Account created successfully! Please go to the Login tab to sign in.")

def show_dashboard():
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
            st.session_state.logged_in = False
            st.session_state.user_role = None
            st.session_state.user_data = None
            st.session_state.medilink_id = None
            st.rerun()
    
    # Role-based interface
    if role == "patient":
        show_patient_dashboard()
    elif role in ["doctor", "nurse"]:
        show_healthcare_provider_dashboard()
    elif role == "admin":
        show_admin_dashboard()

def show_patient_dashboard():
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
    tab1, tab2, tab3, tab4 = st.tabs([
        "📊 Health Summary", "🏥 My Visits", "🔐 Share with Hospital", "⚙️ Settings"
    ])
    
    with tab1:
        show_patient_health_summary()
    
    with tab2:
        show_patient_visit_history()
    
    with tab3:
        show_patient_sharing_options()
    
    with tab4:
        show_patient_settings()

def show_patient_health_summary():
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
    
    # Recent activity
    st.subheader("📈 Recent Activity")
    
    activities = [
        {"date": "Jan 15, 2024", "hospital": "Nairobi Hospital", "diagnosis": "Malaria (treated)", "doctor": "Dr. Mary Wanjiku"},
        {"date": "Dec 10, 2023", "hospital": "Kenyatta Hospital", "diagnosis": "Diabetes checkup", "doctor": "Dr. John Kamau"},
        {"date": "Nov 05, 2023", "hospital": "Local Clinic", "diagnosis": "COVID vaccination", "doctor": "Nurse Peter"}
    ]
    
    for activity in activities:
        with st.expander(f"{activity['date']} - {activity['hospital']}"):
            st.write(f"**Doctor:** {activity['doctor']}")
            st.write(f"**Diagnosis:** {activity['diagnosis']}")
            st.write(f"**Hospital:** {activity['hospital']}")

def show_patient_visit_history():
    """Patient visit history"""
    
    st.subheader("🏥 Your Medical Visit History")
    
    visits = [
        {
            "date": "Jan 15, 2024",
            "hospital": "Nairobi General Hospital",
            "doctor": "Dr. Mary Wanjiku",
            "complaint": "Fever and headache for 3 days",
            "diagnosis": "Malaria",
            "treatment": "Artemether-Lumefantrine 3 days",
            "triage": "URGENT"
        },
        {
            "date": "Dec 10, 2023", 
            "hospital": "Kenyatta National Hospital",
            "doctor": "Dr. John Kamau",
            "complaint": "Routine diabetes check-up",
            "diagnosis": "Type 2 Diabetes - well controlled",
            "treatment": "Continue Metformin",
            "triage": "ROUTINE"
        }
    ]
    
    for visit in visits:
        with st.expander(f"{visit['date']} - {visit['hospital']} ({visit['triage']})"):
            col1, col2 = st.columns(2)
            
            with col1:
                st.write(f"**Doctor:** {visit['doctor']}")
                st.write(f"**Chief Complaint:** {visit['complaint']}")
                st.write(f"**Diagnosis:** {visit['diagnosis']}")
            
            with col2:
                st.write(f"**Treatment:** {visit['treatment']}")
                st.write(f"**Triage Level:** {visit['triage']}")

def show_patient_sharing_options():
    """Patient sharing interface"""
    
    st.subheader("🏥 Share Your Records with Healthcare Providers")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🔢 Generate Access Code**")
        st.info("Create a temporary code for hospital staff")
        
        if st.button("🔢 Generate Access Code", type="primary"):
            access_code = secrets.randbelow(900000) + 100000
            st.markdown(f"""
            <div class="access-code">
                Access Code: {access_code}
            </div>
            """, unsafe_allow_html=True)
            st.success("Valid for 24 hours. Share this with your healthcare provider.")
    
    with col2:
        st.write("**📱 QR Code Sharing**")
        st.info("Generate QR code for instant access")
        
        if st.button("📱 Generate QR Code", type="primary"):
            st.success("QR Code generated!")
            st.info("📱 Show this QR code to hospital staff for instant access.")

def show_patient_settings():
    """Patient settings"""
    
    st.subheader("⚙️ Privacy & Security Settings")
    
    # Privacy preferences
    st.write("**🔒 Privacy Preferences**")
    
    emergency_access = st.checkbox("Allow emergency access when unconscious", value=True)
    research_data = st.checkbox("Allow anonymized data for medical research", value=False)
    
    # Emergency info
    st.write("**🚨 Emergency Information**")
    
    col1, col2 = st.columns(2)
    
    with col1:
        blood_type = st.selectbox("Blood Type", ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"])
        allergies = st.text_area("Critical Allergies", value="Penicillin\nSulfa drugs")
    
    with col2:
        emergency_contact = st.text_input("Emergency Contact", value="Jane Doe")
        emergency_phone = st.text_input("Emergency Phone", value="+254712345679")
    
    if st.button("💾 Save Settings", type="primary"):
        st.success("Settings saved successfully!")

def show_healthcare_provider_dashboard():
    """Healthcare provider interface"""
    
    role = st.session_state.user_role
    
    # Navigation tabs
    tab1, tab2, tab3 = st.tabs([
        "🔍 Access Patient", "👥 My Patients", "📋 New Consultation"
    ])
    
    with tab1:
        show_provider_patient_access()
    
    with tab2:
        show_provider_patient_list()
    
    with tab3:
        show_provider_consultation()

def show_provider_patient_access():
    """Healthcare provider patient access"""
    
    st.subheader("🔍 Access Patient Records")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Search by MediLink ID**")
        medilink_id = st.text_input("Enter MediLink ID", placeholder="ML-NBO-XXXX")
        
        if st.button("🔍 Search Patient", type="primary"):
            if medilink_id == "ML-NBO-DEMO1":
                show_patient_records_for_provider()
            else:
                st.error("Patient not found or access denied")
    
    with col2:
        st.write("**Access with Patient Code**")
        access_code = st.text_input("Enter 6-digit access code", placeholder="123456")
        
        if st.button("🔓 Access with Code", type="primary"):
            if len(access_code) == 6:
                show_patient_records_for_provider()
            else:
                st.error("Please enter a valid 6-digit code")

def show_patient_records_for_provider():
    """Show patient records to healthcare provider"""
    
    st.success("✅ Access granted to patient records: ML-NBO-DEMO1")
    
    # Patient summary
    st.markdown("""
    <div style="background: #f8f9fa; padding: 1rem; border-radius: 8px; border-left: 4px solid #2E8B57; margin: 1rem 0;">
        <h3>👤 Patient: John Doe (ML-NBO-DEMO1)</h3>
        <p><strong>Age:</strong> 35 | <strong>Gender:</strong> Male | <strong>Blood Type:</strong> O+</p>
        <p><strong>Phone:</strong> +254712345678 | <strong>Emergency Contact:</strong> Jane Doe</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Critical alerts
    st.error("🚨 **ALLERGIES:** Penicillin, Sulfa drugs")
    st.warning("💊 **CURRENT MEDICATIONS:** Metformin 500mg, Lisinopril 10mg")
    
    # Medical history
    st.subheader("📋 Recent Medical History")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Recent Visits:**")
        st.write("• **Jan 15, 2024** - Malaria (treated)")
        st.write("• **Dec 10, 2023** - Diabetes checkup")
        st.write("• **Nov 05, 2023** - COVID vaccination")
    
    with col2:
        st.write("**Vital Signs Trends:**")
        st.write("• **BP:** 120/80 → 125/82 → 130/85")
        st.write("• **Weight:** 70kg → 72kg → 74kg")
        st.write("• **Temp:** Normal range")

def show_provider_patient_list():
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
        
        with col2:
            st.write(f"Last: {patient['last_visit']}")
        
        with col3:
            st.write(f"Condition: {patient['condition']}")
        
        with col4:
            if st.button("👁️", key=f"view_{patient['id']}"):
                show_patient_records_for_provider()

def show_provider_consultation():
    """New consultation interface"""
    
    st.subheader("📋 New Patient Consultation")
    
    # Patient ID
    medilink_id = st.text_input("Patient MediLink ID", placeholder="ML-XXX-XXXX")
    
    if medilink_id:
        st.success(f"Patient loaded: John Doe ({medilink_id})")
        
        # Consultation form
        chief_complaint = st.text_area("Chief Complaint")
        
        st.write("**Symptoms:**")
        col1, col2 = st.columns(2)
        
        with col1:
            fever = st.checkbox("Fever")
            cough = st.checkbox("Cough")
            headache = st.checkbox("Headache")
        
        with col2:
            chest_pain = st.checkbox("Chest pain")
            difficulty_breathing = st.checkbox("Difficulty breathing")
            fatigue = st.checkbox("Fatigue")
        
        st.write("**Vital Signs:**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            temperature = st.number_input("Temperature (°C)", value=37.0)
        
        with col2:
            systolic_bp = st.number_input("Systolic BP", value=120)
        
        with col3:
            pulse = st.number_input("Pulse (bpm)", value=80)
        
        if st.button("🤖 Analyze with AI", type="primary"):
            st.success("🎯 AI Analysis Complete!")
            
            st.write("**🔍 Suspected Conditions:**")
            st.write("1. **Malaria** - 85% confidence")
            st.write("2. **Viral fever** - 60% confidence")
            
            st.write("**⚠️ Triage Level:** URGENT")
            
            st.write("**💊 Recommendations:**")
            st.write("• Artemether-Lumefantrine based on weight")
            st.write("• Paracetamol for fever")
            
            if st.button("💾 Save Consultation"):
                st.success("Consultation saved to patient's MediLink record!")

def show_admin_dashboard():
    """Admin interface"""
    
    # Navigation tabs
    tab1, tab2, tab3 = st.tabs([
        "👥 User Management", "📊 Analytics", "⚙️ Settings"
    ])
    
    with tab1:
        show_admin_users()
    
    with tab2:
        show_admin_analytics()
    
    with tab3:
        show_admin_settings()

def show_admin_users():
    """Admin user management"""
    
    st.subheader("👥 User Management")
    
    # Add new user
    st.write("**➕ Add New Healthcare Provider**")
    
    col1, col2 = st.columns(2)
    
    with col1:
        full_name = st.text_input("Full Name")
        role = st.selectbox("Role", ["Doctor", "Nurse", "Clinical Officer"])
    
    with col2:
        department = st.text_input("Department")
        phone = st.text_input("Phone")
    
    if st.button("➕ Add User"):
        st.success(f"User {full_name} added successfully!")
    
    # User list
    st.write("**👥 Current Users**")
    
    users = [
        {"name": "Dr. Mary Wanjiku", "role": "Doctor", "department": "Internal Medicine"},
        {"name": "Nurse Jane Akinyi", "role": "Nurse", "department": "Emergency"},
        {"name": "Dr. John Kamau", "role": "Doctor", "department": "Pediatrics"}
    ]
    
    for user in users:
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.write(f"**{user['name']}**")
        
        with col2:
            st.write(user['role'])
        
        with col3:
            st.write(user['department'])

def show_admin_analytics():
    """Admin analytics"""
    
    st.subheader("📊 Hospital Analytics")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Total Patients", "1,234", "+56")
    
    with col2:
        st.metric("Active Users", "45", "+3")
    
    with col3:
        st.metric("Consultations Today", "89", "+12")
    
    with col4:
        st.metric("System Uptime", "99.9%", "30 days")

def show_admin_settings():
    """Admin settings"""
    
    st.subheader("⚙️ System Settings")
    
    hospital_name = st.text_input("Hospital Name", value="Nairobi General Hospital")
    hospital_location = st.text_input("Location", value="Nairobi, Kenya")
    
    if st.button("💾 Save Settings"):
        st.success("Settings saved successfully!")

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        show_dashboard()

if __name__ == "__main__":
    main()