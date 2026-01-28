"""
MediLink Database Version - Uses SQLite for persistent data storage
Single app for patients, doctors, and admins with role-based interface
Includes rule-based medical AI for consultations
"""

import streamlit as st
from datetime import datetime
import secrets
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import sys
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent / "src"))

from database.database_manager import get_database

# Import the medical AI components from the simple version
from medilink_simple import SimpleRuleEngine, SimpleTriageEngine, MedicalAI, PatientData, ConsultationResult

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink (Database Version)",
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

# Get database instance
db = get_database()

# Initialize the medical AI system
@st.cache_resource
def get_medical_ai():
    """Get cached medical AI instance"""
    return MedicalAI()

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

.database-info {
    background: #e3f2fd;
    border: 1px solid #2196f3;
    border-radius: 8px;
    padding: 1rem;
    margin: 1rem 0;
}

.success-message {
    background: #e8f5e8;
    border: 1px solid #4caf50;
    border-radius: 8px;
    padding: 1rem;
    margin: 1rem 0;
    color: #2e7d32;
}
</style>
""", unsafe_allow_html=True)

def generate_medilink_id(location: str = "") -> str:
    """Generate unique MediLink ID"""
    location_codes = {
        "nairobi": "NBO", "mombasa": "MSA", "kisumu": "KSM",
        "nakuru": "NKR", "eldoret": "ELD"
    }
    location_code = location_codes.get(location.lower(), "KEN")
    unique_id = secrets.token_hex(4).upper()
    return f"ML-{location_code}-{unique_id}"

def show_login_page():
    """Display login/registration page"""
    
    # Header
    st.markdown("""
    <div class="main-header patient-theme">
        <h1>🏥 AfiCare MediLink (Database Version)</h1>
        <p>Your Health Records, Your Control - Now with Persistent Storage!</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Database info
    st.markdown("""
    <div class="database-info">
        <h4>💾 Database Version Features:</h4>
        <p>✅ User accounts persist between sessions<br>
        ✅ Consultations saved permanently<br>
        ✅ Access codes stored in database<br>
        ✅ Complete audit trail<br>
        ✅ Multi-user support</p>
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
    
    username = st.text_input("Username or MediLink ID", placeholder="ML-NBO-XXXX or username")
    password = st.text_input("Password", type="password")
    role = st.selectbox("Login as:", ["patient", "doctor", "nurse", "admin"], format_func=lambda x: x.title())
    
    if st.button("🔐 Login", type="primary"):
        if not username or not password:
            st.error("❌ Please enter username and password")
        else:
            # Attempt authentication with database
            success, user_data = db.authenticate_user(username, password, role)
            
            if success:
                st.session_state.logged_in = True
                st.session_state.user_role = role
                st.session_state.user_data = user_data
                st.session_state.medilink_id = user_data.get('medilink_id')
                
                st.success(f"✅ Welcome back, {user_data['full_name']}!")
                st.rerun()
            else:
                st.error("❌ **Login Failed** - Please check your credentials")

def show_registration_form():
    """Registration form for new users"""
    
    st.subheader("Register New Account")
    
    role = st.selectbox("Register as:", ["patient", "doctor", "nurse", "admin"], format_func=lambda x: x.title())
    
    col1, col2 = st.columns(2)
    
    with col1:
        full_name = st.text_input("Full Name *")
        username = st.text_input("Username *")
        phone = st.text_input("Phone Number *")
        
    with col2:
        email = st.text_input("Email Address *")
        password = st.text_input("Create Password *", type="password")
        confirm_password = st.text_input("Confirm Password *", type="password")
    
    # Role-specific fields
    if role == "patient":
        col1, col2 = st.columns(2)
        with col1:
            age = st.number_input("Age *", min_value=0, max_value=120, value=25)
            gender = st.selectbox("Gender *", ["Male", "Female", "Other"])
        with col2:
            location = st.selectbox("Location", ["Nairobi", "Mombasa", "Kisumu", "Other"])
            medical_history = st.text_area("Medical History (Optional)")
    else:
        department = st.text_input("Department")
        hospital_id = st.text_input("Hospital ID", value="HOSP001")
        age, gender, location, medical_history = None, None, None, None
    
    agree_terms = st.checkbox("I agree to the Terms of Service *")
    
    if st.button("📝 Register Account", type="primary"):
        # Validation
        if not all([full_name, username, phone, email, password, confirm_password]):
            st.error("❌ Please fill in all required fields")
        elif password != confirm_password:
            st.error("❌ Passwords do not match")
        elif not agree_terms:
            st.error("❌ Please agree to the Terms of Service")
        else:
            # Create user data
            user_data = {
                "username": username,
                "password": password,
                "role": role,
                "full_name": full_name,
                "phone": phone,
                "email": email,
                "department": department if role != "patient" else None,
                "hospital_id": hospital_id if role != "patient" else None,
                "age": age,
                "gender": gender,
                "location": location,
                "medical_history": medical_history
            }
            
            # Generate MediLink ID for patients
            if role == "patient":
                user_data["medilink_id"] = generate_medilink_id(location)
            
            # Save to database
            success, message = db.create_user(user_data)
            
            if success:
                st.balloons()
                medilink_display = f" - MediLink ID: {user_data.get('medilink_id')}" if role == "patient" else ""
                st.markdown(f"""
                <div class="success-message">
                    <h3>🎉 Registration Successful!</h3>
                    <p><strong>Username:</strong> {username}{medilink_display}</p>
                    <p><strong>Role:</strong> {role.title()}</p>
                    <p><em>💾 Your account has been saved to the database permanently!</em></p>
                    <p><strong>👆 Click the 'Login' tab above to sign in!</strong></p>
                </div>
                """, unsafe_allow_html=True)
            else:
                st.error(f"❌ Registration failed: {message}")

def show_dashboard():
    """Show role-based dashboard"""
    
    role = st.session_state.user_role
    user_data = st.session_state.user_data
    
    # Header
    theme_class = f"{role}-theme"
    st.markdown(f"""
    <div class="main-header {theme_class}">
        <h1>🏥 AfiCare MediLink (Database Version)</h1>
        <p>{user_data['full_name']} - {role.title()}</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Sidebar with database stats
    with st.sidebar:
        st.write(f"**Logged in as:** {role.title()}")
        if role == "patient" and st.session_state.medilink_id:
            st.write(f"**MediLink ID:** {st.session_state.medilink_id}")
        
        # Show database stats
        stats = db.get_system_stats()
        st.write("**📊 Database Stats:**")
        if stats.get('user_counts'):
            for role_name, count in stats['user_counts'].items():
                st.write(f"• {role_name.title()}s: {count}")
        st.write(f"• Total Consultations: {stats.get('total_consultations', 0)}")
        
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
    """Patient interface with database integration"""
    
    medilink_id = st.session_state.medilink_id
    
    st.info(f"📋 Your MediLink ID: **{medilink_id}** - All your medical records are stored in the database")
    
    # Get patient's consultations from database
    consultations = db.get_patient_consultations(medilink_id)
    
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Total Visits", len(consultations))
    with col2:
        last_visit = consultations[0]['consultation_date'][:10] if consultations else "Never"
        st.metric("Last Visit", last_visit)
    with col3:
        emergency_visits = len([c for c in consultations if c['triage_level'] == 'EMERGENCY'])
        st.metric("Emergency Visits", emergency_visits)
    
    # Show recent consultations
    if consultations:
        st.subheader("📈 Recent Consultations from Database")
        for consultation in consultations[:5]:
            with st.expander(f"{consultation['consultation_date'][:16]} - {consultation['triage_level']}"):
                st.write(f"**Doctor:** {consultation['doctor_username']}")
                st.write(f"**Chief Complaint:** {consultation['chief_complaint'] or 'Not specified'}")
                st.write(f"**Triage Level:** {consultation['triage_level']}")
                if consultation['suspected_conditions']:
                    conditions = consultation['suspected_conditions']
                    if conditions:
                        st.write(f"**Top Diagnosis:** {conditions[0].get('display_name', 'Unknown')} ({conditions[0].get('confidence', 0):.1%} confidence)")
    else:
        st.info("No consultations found in database. Visit a healthcare provider to start building your medical history!")
    
    # Access code generation
    st.subheader("🔐 Share Records with Hospital")
    if st.button("🔢 Generate Access Code"):
        success, access_code = db.generate_access_code(medilink_id, expires_hours=24)
        if success:
            st.success(f"✅ Access Code: **{access_code}** (Valid for 24 hours)")
            st.info("Share this code with your healthcare provider to grant access to your records.")

def show_healthcare_provider_dashboard():
    """Healthcare provider interface with database"""
    
    st.subheader("🔍 Access Patient Records")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Search by MediLink ID**")
        medilink_id = st.text_input("Enter MediLink ID", placeholder="ML-NBO-XXXX")
        
        if st.button("🔍 Search Patient"):
            if medilink_id:
                patient = db.get_user_by_medilink_id(medilink_id)
                if patient:
                    show_patient_records_for_provider(patient)
                else:
                    st.error("❌ Patient not found")
    
    with col2:
        st.write("**Access with Patient Code**")
        access_code = st.text_input("Enter 6-digit access code", placeholder="123456")
        
        if st.button("🔓 Access with Code"):
            if len(access_code) == 6:
                success, found_medilink_id = db.verify_access_code(access_code, st.session_state.user_data['username'])
                if success:
                    patient = db.get_user_by_medilink_id(found_medilink_id)
                    if patient:
                        show_patient_records_for_provider(patient)
                else:
                    st.error("❌ Invalid or expired access code")

def show_patient_records_for_provider(patient):
    """Show patient records to healthcare provider"""
    
    st.success(f"✅ Access granted: {patient['full_name']} ({patient['medilink_id']})")
    
    # Patient info
    col1, col2 = st.columns(2)
    with col1:
        st.write(f"**Age:** {patient.get('age', 'Unknown')}")
        st.write(f"**Gender:** {patient.get('gender', 'Unknown')}")
        st.write(f"**Phone:** {patient.get('phone', 'Unknown')}")
    with col2:
        st.write(f"**Location:** {patient.get('location', 'Unknown')}")
        if patient.get('medical_history'):
            st.warning(f"**Medical History:** {patient['medical_history']}")
    
    # Show consultations from database
    consultations = db.get_patient_consultations(patient['medilink_id'])
    
    if consultations:
        st.subheader("📋 Medical History from Database")
        for consultation in consultations[:3]:
            with st.expander(f"{consultation['consultation_date'][:10]} - {consultation['triage_level']}"):
                st.write(f"**Doctor:** {consultation['doctor_username']}")
                st.write(f"**Chief Complaint:** {consultation['chief_complaint']}")
                if consultation['suspected_conditions']:
                    top_condition = consultation['suspected_conditions'][0]
                    st.write(f"**Diagnosis:** {top_condition.get('display_name', 'Unknown')} ({top_condition.get('confidence', 0):.1%})")
    
    # New consultation form
    st.subheader("📋 New Consultation")
    
    chief_complaint = st.text_area("Chief Complaint")
    
    # Symptoms checkboxes
    st.write("**Symptoms:**")
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
    
    # Vital signs
    st.write("**Vital Signs:**")
    col1, col2, col3 = st.columns(3)
    
    with col1:
        temperature = st.number_input("Temperature (°C)", value=37.0)
        systolic_bp = st.number_input("Systolic BP", value=120)
    
    with col2:
        pulse = st.number_input("Pulse (bpm)", value=80)
        resp_rate = st.number_input("Respiratory Rate", value=16)
    
    with col3:
        oxygen_sat = st.number_input("Oxygen Saturation (%)", value=98)
    
    if st.button("🤖 Analyze with AI & Save to Database", type="primary"):
        # Prepare symptoms
        symptoms_list = []
        if fever: symptoms_list.append("fever")
        if cough: symptoms_list.append("cough")
        if headache: symptoms_list.append("headache")
        if nausea: symptoms_list.append("nausea")
        if chest_pain: symptoms_list.append("chest pain")
        if difficulty_breathing: symptoms_list.append("difficulty breathing")
        if fatigue: symptoms_list.append("fatigue")
        if dizziness: symptoms_list.append("dizziness")
        
        if not symptoms_list:
            st.error("Please select at least one symptom")
        else:
            # Run AI analysis
            medical_ai = get_medical_ai()
            
            patient_data = PatientData(
                patient_id=patient['medilink_id'],
                age=patient.get('age', 30),
                gender=patient.get('gender', 'unknown'),
                symptoms=symptoms_list,
                vital_signs={
                    "temperature": temperature,
                    "systolic_bp": systolic_bp,
                    "pulse": pulse,
                    "respiratory_rate": resp_rate,
                    "oxygen_saturation": oxygen_sat
                },
                medical_history=[],
                current_medications=[],
                chief_complaint=chief_complaint or "Consultation"
            )
            
            with st.spinner("🤖 AI analyzing..."):
                result = medical_ai.conduct_consultation(patient_data)
                
                # Display results
                st.success("🎯 AI Analysis Complete!")
                
                triage_colors = {"EMERGENCY": "🚨", "URGENT": "⚠️", "LESS_URGENT": "⏰", "NON_URGENT": "✅"}
                triage_emoji = triage_colors.get(result.triage_level, "ℹ️")
                st.write(f"**{triage_emoji} Triage Level:** {result.triage_level}")
                st.write(f"**🎯 Confidence:** {result.confidence_score:.1%}")
                
                # Show conditions
                if result.suspected_conditions:
                    st.write("**🔍 Suspected Conditions:**")
                    for i, condition in enumerate(result.suspected_conditions[:3], 1):
                        st.write(f"{i}. **{condition['display_name']}** - {condition['confidence']:.1%}")
                
                # Show recommendations
                if result.recommendations:
                    st.write("**💊 Recommendations:**")
                    for i, rec in enumerate(result.recommendations[:3], 1):
                        st.write(f"{i}. {rec}")
                
                # Save to database
                consultation_data = {
                    "patient_medilink_id": patient['medilink_id'],
                    "doctor_username": st.session_state.user_data['username'],
                    "hospital_id": st.session_state.user_data.get('hospital_id'),
                    "chief_complaint": chief_complaint,
                    "symptoms": symptoms_list,
                    "vital_signs": {
                        "temperature": temperature,
                        "systolic_bp": systolic_bp,
                        "pulse": pulse,
                        "respiratory_rate": resp_rate,
                        "oxygen_saturation": oxygen_sat
                    },
                    "triage_level": result.triage_level,
                    "suspected_conditions": result.suspected_conditions,
                    "recommendations": result.recommendations,
                    "referral_needed": result.referral_needed,
                    "follow_up_required": result.follow_up_required,
                    "confidence_score": result.confidence_score
                }
                
                success, message = db.save_consultation(consultation_data)
                
                if success:
                    st.success("✅ Consultation saved to database!")
                    st.info("📋 This consultation is now part of the patient's permanent MediLink record")
                else:
                    st.error(f"❌ Failed to save: {message}")

def show_admin_dashboard():
    """Admin interface"""
    
    st.subheader("⚙️ System Administration")
    
    # System statistics
    stats = db.get_system_stats()
    
    st.write("**📊 Database Statistics:**")
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if stats.get('user_counts'):
            for role, count in stats['user_counts'].items():
                st.metric(f"{role.title()}s", count)
    
    with col2:
        st.metric("Total Consultations", stats.get('total_consultations', 0))
        st.metric("Recent (7 days)", stats.get('recent_consultations', 0))
    
    with col3:
        st.metric("Active Access Codes", stats.get('active_access_codes', 0))
        db_size = stats.get('database_size', 0)
        st.metric("Database Size", f"{db_size / 1024:.1f} KB" if db_size > 0 else "0 KB")
    
    st.info("💾 **Database Version Active** - All data is being stored persistently in SQLite database")

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        show_dashboard()

if __name__ == "__main__":
    main()