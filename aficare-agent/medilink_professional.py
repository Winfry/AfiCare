"""
MediLink Professional - Beautiful, modern medical application
Cost-free deployment with stunning visuals and professional UX
"""

import streamlit as st
from datetime import datetime, timedelta
import secrets
import json
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
import base64

# Import enhanced components
import sys
sys.path.append(str(Path(__file__).parent))

try:
    from src.database.enhanced_database_manager import get_enhanced_database
    from src.utils.qr_manager import get_qr_manager
    from src.utils.export_manager import get_export_manager
    from src.ui.themes.professional_medical_theme import (
        apply_medical_theme, create_medical_header, create_status_card,
        create_medical_card, create_alert, create_access_code_display,
        create_audit_log_entry, get_medical_icons
    )
    
    # Import medical AI components
    from medilink_simple import (
        PatientData, ConsultationResult, SimpleRuleEngine, 
        SimpleTriageEngine, MedicalAI, generate_medilink_id
    )
    
    IMPORTS_SUCCESS = True
except Exception as e:
    st.error(f"Import error: {e}")
    IMPORTS_SUCCESS = False

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink Professional",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Check if imports were successful
if not IMPORTS_SUCCESS:
    st.error("Failed to import required modules. Please check the installation.")
    st.stop()

# Apply professional theme
apply_medical_theme()

# Initialize session state
if 'logged_in' not in st.session_state:
    st.session_state.logged_in = False
if 'user_role' not in st.session_state:
    st.session_state.user_role = None
if 'user_data' not in st.session_state:
    st.session_state.user_data = None
if 'medilink_id' not in st.session_state:
    st.session_state.medilink_id = None

# Get enhanced instances
@st.cache_resource
def get_enhanced_instances():
    """Get enhanced database, QR manager, and export manager instances"""
    try:
        db = get_enhanced_database()
        qr_mgr = get_qr_manager(db)
        export_mgr = get_export_manager(db, qr_mgr)
        medical_ai = MedicalAI()
        return db, qr_mgr, export_mgr, medical_ai
    except Exception as e:
        st.error(f"Failed to initialize components: {e}")
        return None, None, None, None

db, qr_manager, export_manager, medical_ai = get_enhanced_instances()

if db is None:
    st.error("Failed to initialize database. Please check the configuration.")
    st.stop()

icons = get_medical_icons()
def show_professional_login_page():
    """Display beautiful login/registration page"""
    
    # Professional header
    create_medical_header(
        "AfiCare MediLink Professional",
        "Advanced Medical Records • Beautiful Design • Cost-Free Forever"
    )
    
    # Feature showcase
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        create_status_card("100%", "Cost Free", "success")
    with col2:
        create_status_card("7", "Medical Conditions", "info")
    with col3:
        create_status_card("24/7", "Available", "warning")
    with col4:
        create_status_card("∞", "Patients", "info")
    
    st.markdown("<br>", unsafe_allow_html=True)
    
    # Enhanced features showcase
    create_medical_card(
        "🚀 Professional Features",
        """
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-top: 1rem;">
            <div>
                <strong>🔐 Secure Access Codes</strong><br>
                <small>Temporary sharing with QR codes</small>
            </div>
            <div>
                <strong>📊 Complete Audit Trail</strong><br>
                <small>Track all record access</small>
            </div>
            <div>
                <strong>📄 Multi-Format Export</strong><br>
                <small>PDF, JSON, CSV formats</small>
            </div>
            <div>
                <strong>🤖 AI-Powered Analysis</strong><br>
                <small>7 medical conditions</small>
            </div>
        </div>
        """,
        "✨"
    )
    
    # Login/Register in beautiful tabs
    tab1, tab2 = st.tabs([f"{icons['key']} Login", f"{icons['patient']} Register"])
    
    with tab1:
        show_professional_login_form()
    
    with tab2:
        show_professional_registration_form()

def show_professional_login_form():
    """Beautiful login form"""
    
    st.markdown("### Sign In to Your Account")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        username = st.text_input(
            "Username", 
            placeholder="Enter your username",
            help="Your unique username for AfiCare MediLink"
        )
        password = st.text_input(
            "Password", 
            type="password",
            help="Your secure password"
        )
        role = st.selectbox(
            "Login as:", 
            ["patient", "doctor", "nurse", "admin"], 
            format_func=lambda x: f"{icons.get(x, '👤')} {x.title()}"
        )
    
    with col2:
        st.markdown("#### Quick Access")
        st.info("💡 **Demo Accounts:**\n\n👤 Patient: `demo_patient`\n👨‍⚕️ Doctor: `demo_doctor`\n\nPassword: `demo123`")
    
    if st.button(f"{icons['key']} Sign In", type="primary", use_container_width=True):
        if not username or not password:
            create_alert("Please enter both username and password", "warning")
        else:
            success, user_data = db.authenticate_user(username, password, role)
            
            if success:
                st.session_state.logged_in = True
                st.session_state.user_role = role
                st.session_state.user_data = user_data
                st.session_state.medilink_id = user_data.get('medilink_id')
                
                # Log successful login
                db.log_access_enhanced(
                    patient_medilink_id=user_data.get('medilink_id', 'system'),
                    accessed_by=username,
                    access_type="login",
                    access_method="direct",
                    success=True
                )
                
                create_alert(f"Welcome back, {user_data['full_name']}! 🎉", "success")
                st.rerun()
            else:
                create_alert("Invalid credentials. Please try again.", "danger")

def show_professional_registration_form():
    """Beautiful registration form"""
    
    st.markdown("### Create Your Account")
    
    role = st.selectbox(
        "Account Type:", 
        ["patient", "doctor", "nurse", "admin"], 
        format_func=lambda x: f"{icons.get(x, '👤')} {x.title()}"
    )
    
    col1, col2 = st.columns(2)
    
    with col1:
        full_name = st.text_input("Full Name *", placeholder="John Doe")
        username = st.text_input("Username *", placeholder="johndoe")
        phone = st.text_input("Phone Number *", placeholder="+254 700 000 000")
        
    with col2:
        email = st.text_input("Email Address", placeholder="john@example.com")
        password = st.text_input("Create Password *", type="password")
        confirm_password = st.text_input("Confirm Password *", type="password")
    
    # Patient-specific fields
    if role == "patient":
        st.markdown("#### Medical Information")
        col1, col2 = st.columns(2)
        with col1:
            age = st.number_input("Age *", min_value=0, max_value=120, value=25)
            gender = st.selectbox("Gender *", ["Male", "Female", "Other"])
        with col2:
            location = st.selectbox("Location", ["Nairobi", "Mombasa", "Kisumu", "Other"])
    else:
        age, gender, location = None, None, None
    
    if st.button(f"{icons['patient']} Create Account", type="primary", use_container_width=True):
        if not all([full_name, username, phone, password, confirm_password]):
            create_alert("Please fill in all required fields", "warning")
        elif password != confirm_password:
            create_alert("Passwords do not match", "danger")
        else:
            user_data = {
                "username": username, "password": password, "role": role, "full_name": full_name,
                "phone": phone, "email": email, "age": age, "gender": gender, "location": location
            }
            
            if role == "patient":
                user_data["medilink_id"] = generate_medilink_id(location)
            
            success, message = db.create_user(user_data)
            
            if success:
                st.balloons()
                medilink_display = f"**MediLink ID:** `{user_data.get('medilink_id')}`" if role == "patient" else ""
                create_alert(f"🎉 Account created successfully!\n\n**Username:** `{username}`\n{medilink_display}\n\n👆 Switch to Login tab to sign in!", "success")
            else:
                create_alert(f"Registration failed: {message}", "danger")
def show_professional_dashboard():
    """Beautiful role-based dashboard"""
    
    role = st.session_state.user_role
    user_data = st.session_state.user_data
    
    # Professional header with user info
    create_medical_header(
        f"Welcome, {user_data['full_name']}",
        f"{icons.get(role, '👤')} {role.title()} Dashboard • AfiCare MediLink Professional"
    )
    
    # Enhanced sidebar
    with st.sidebar:
        st.markdown(f"### {icons['settings']} Account Info")
        st.write(f"**Role:** {icons.get(role, '👤')} {role.title()}")
        if role == "patient" and st.session_state.medilink_id:
            st.code(st.session_state.medilink_id, language=None)
        
        # Enhanced system stats
        stats = db.get_enhanced_system_stats()
        st.markdown(f"### {icons['chart']} System Stats")
        
        if stats.get('user_counts'):
            for role_name, count in stats['user_counts'].items():
                st.metric(f"{role_name.title()}s", count)
        
        st.metric("Consultations", stats.get('total_consultations', 0))
        st.metric("Active Codes", stats.get('active_access_codes', 0))
        st.metric("Audit Entries", stats.get('total_audit_entries', 0))
        
        st.markdown("---")
        if st.button(f"{icons['power']} Logout", use_container_width=True):
            # Log logout
            db.log_access_enhanced(
                patient_medilink_id=st.session_state.medilink_id or "system",
                accessed_by=user_data['username'],
                access_type="logout",
                access_method="direct",
                success=True
            )
            
            st.session_state.logged_in = False
            st.session_state.user_role = None
            st.session_state.user_data = None
            st.session_state.medilink_id = None
            st.rerun()
    
    # Role-based interface
    if role == "patient":
        show_professional_patient_dashboard()
    elif role in ["doctor", "nurse"]:
        show_professional_provider_dashboard()
    elif role == "admin":
        show_professional_admin_dashboard()

def show_professional_patient_dashboard():
    """Beautiful patient interface"""
    
    medilink_id = st.session_state.medilink_id
    
    # Patient metrics
    consultations = db.get_patient_consultations(medilink_id)
    active_codes = db.get_active_access_codes(medilink_id)
    access_log = db.get_access_log_enhanced(medilink_id, days=7)
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        create_status_card(str(len(consultations)), "Total Visits", "info")
    with col2:
        create_status_card(str(len(active_codes)), "Active Codes", "success")
    with col3:
        create_status_card(str(len(access_log)), "Recent Access", "warning")
    with col4:
        last_visit = consultations[0]['consultation_date'][:10] if consultations else "Never"
        create_status_card(last_visit, "Last Visit", "info")
    
    # Beautiful tabs
    tab1, tab2, tab3, tab4, tab5 = st.tabs([
        f"{icons['heart']} Overview",
        f"{icons['key']} Access Codes", 
        f"{icons['audit']} Access Log",
        f"{icons['export']} Export Data",
        f"{icons['profile']} Profile"
    ])
    
    with tab1:
        if consultations:
            st.markdown("### 📈 Your Medical History")
            for consultation in consultations[:3]:
                with st.expander(f"{consultation['consultation_date'][:16]} - {consultation['triage_level']}"):
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        st.write(f"**Doctor:** {consultation['doctor_username']}")
                        st.write(f"**Chief Complaint:** {consultation['chief_complaint'] or 'Not specified'}")
                        st.write(f"**Triage Level:** {consultation['triage_level']}")
                    
                    with col2:
                        if consultation['suspected_conditions']:
                            conditions = consultation['suspected_conditions']
                            if conditions:
                                st.write(f"**Top Diagnosis:** {conditions[0].get('display_name', 'Unknown')}")
                                st.write(f"**Confidence:** {conditions[0].get('confidence', 0):.1%}")
        else:
            create_alert("No consultations found. Visit a healthcare provider to start building your medical history!", "info")
    
    with tab2:
        st.markdown("### 🔑 Generate Access Codes")
        
        col1, col2 = st.columns(2)
        
        with col1:
            duration = st.selectbox("Code Duration", [1, 6, 24, 168], format_func=lambda x: f"{x} hours" if x < 24 else f"{x//24} days")
            
            permissions = {}
            st.write("**Permissions:**")
            permissions["view_basic_info"] = st.checkbox("Basic Information", value=True)
            permissions["view_medical_history"] = st.checkbox("Medical History", value=True)
            permissions["view_consultations"] = st.checkbox("Consultations", value=True)
            permissions["view_medications"] = st.checkbox("Medications", value=True)
        
        with col2:
            if st.button("🔑 Generate Access Code", type="primary"):
                success, access_code = db.generate_access_code(medilink_id, duration, permissions)
                
                if success:
                    expires_at = datetime.now() + timedelta(hours=duration)
                    create_access_code_display(access_code, expires_at.strftime("%Y-%m-%d %H:%M"))
                    
                    # Generate QR code
                    qr_display = qr_manager.create_patient_access_qr_display(
                        medilink_id, access_code, expires_at, permissions
                    )
                    
                    if qr_display["success"] and qr_display["qr_image"]:
                        st.image(qr_display["qr_image"], caption="QR Code for Healthcare Providers", width=200)
                        st.info("📱 Show this QR code to your healthcare provider for instant access")
                    
                    st.rerun()
                else:
                    create_alert(f"Failed to generate access code: {access_code}", "danger")
        
        # Show active codes
        if active_codes:
            st.markdown("### 🔓 Active Access Codes")
            
            for code in active_codes:
                with st.expander(f"Code: {code['access_code']} (Expires: {code['expires_at'][:16]})"):
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        st.write(f"**Created:** {code['created_at'][:16]}")
                        st.write(f"**Duration:** {code['duration_hours']} hours")
                    
                    with col2:
                        if st.button(f"🗑️ Revoke", key=f"revoke_{code['id']}"):
                            if db.revoke_access_code(code['access_code'], medilink_id, medilink_id):
                                create_alert("Access code revoked successfully", "success")
                                st.rerun()
    
    with tab3:
        st.markdown("### 📊 Access Log")
        
        if access_log:
            for entry in access_log:
                create_audit_log_entry(
                    entry['accessed_by'],
                    entry['access_type'].replace('_', ' ').title(),
                    entry['accessed_at'][:16],
                    entry['success']
                )
        else:
            create_alert("No access events recorded in the last 7 days.", "info")
    
    with tab4:
        st.markdown("### 📄 Export Your Medical Data")
        
        col1, col2 = st.columns(2)
        
        with col1:
            export_format = st.selectbox("Export Format", ["PDF", "JSON", "CSV"])
            export_purpose = st.selectbox("Export Purpose", [
                "Personal Records", "New Healthcare Provider", "Insurance", "Legal"
            ])
        
        with col2:
            st.write("**Export includes:**")
            st.write("• Patient information and profile")
            st.write("• Complete consultation history")
            st.write("• Medical diagnoses and treatments")
            st.write("• Verification QR code (PDF only)")
        
        if st.button(f"📥 Export as {export_format}", type="primary"):
            with st.spinner(f"Generating {export_format} export..."):
                success, export_data, message = export_manager.export_patient_data(
                    medilink_id=medilink_id,
                    export_format=export_format.lower(),
                    exported_by=st.session_state.user_data['username'],
                    export_purpose=export_purpose.lower().replace(' ', '_')
                )
                
                if success and export_data:
                    create_alert("Export generated successfully!", "success")
                    
                    # Provide download
                    if export_format == "PDF":
                        st.download_button(
                            label="📄 Download PDF",
                            data=export_data,
                            file_name=f"medical_records_{medilink_id}_{datetime.now().strftime('%Y%m%d')}.pdf",
                            mime="application/pdf"
                        )
                    elif export_format == "JSON":
                        st.download_button(
                            label="💾 Download JSON",
                            data=export_data,
                            file_name=f"medical_records_{medilink_id}_{datetime.now().strftime('%Y%m%d')}.json",
                            mime="application/json"
                        )
                    elif export_format == "CSV":
                        st.download_button(
                            label="📊 Download CSV",
                            data=export_data,
                            file_name=f"consultations_{medilink_id}_{datetime.now().strftime('%Y%m%d')}.csv",
                            mime="text/csv"
                        )
                else:
                    create_alert(f"Export failed: {message}", "danger")
    
    with tab5:
        st.markdown("### 👤 Medical Profile")
        
        # Get current profile
        current_profile = db.get_patient_profile(medilink_id) or {}
        
        # Profile form
        with st.form("patient_profile_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                st.write("**Medical Information**")
                allergies = st.text_area("Allergies (one per line)", 
                                       value="\n".join(current_profile.get('allergies', [])))
                chronic_conditions = st.text_area("Chronic Conditions (one per line)",
                                                value="\n".join(current_profile.get('chronic_conditions', [])))
                blood_type = st.selectbox("Blood Type", 
                                        ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"],
                                        index=0 if not current_profile.get('blood_type') else 
                                        ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"].index(current_profile['blood_type']))
            
            with col2:
                st.write("**Emergency Information**")
                emergency_name = st.text_input("Emergency Contact Name",
                                             value=current_profile.get('emergency_contacts', [{}])[0].get('name', '') if current_profile.get('emergency_contacts') else '')
                emergency_phone = st.text_input("Emergency Contact Phone",
                                              value=current_profile.get('emergency_contacts', [{}])[0].get('phone', '') if current_profile.get('emergency_contacts') else '')
                preferred_language = st.selectbox("Preferred Language",
                                                ["English", "Swahili", "Luganda", "Other"],
                                                index=0)
            
            if st.form_submit_button("💾 Update Profile", type="primary"):
                # Prepare profile data
                profile_data = {
                    'allergies': [a.strip() for a in allergies.split('\n') if a.strip()],
                    'chronic_conditions': [c.strip() for c in chronic_conditions.split('\n') if c.strip()],
                    'blood_type': blood_type if blood_type else None,
                    'preferred_language': preferred_language,
                    'emergency_contacts': [{
                        'name': emergency_name,
                        'phone': emergency_phone,
                        'relationship': 'Emergency Contact',
                        'primary': True
                    }] if emergency_name else []
                }
                
                if db.update_patient_profile(medilink_id, profile_data, st.session_state.user_data['username']):
                    create_alert("Profile updated successfully!", "success")
                    st.rerun()
                else:
                    create_alert("Failed to update profile", "danger")

def show_professional_provider_dashboard():
    """Beautiful healthcare provider interface"""
    
    st.markdown("### 👨‍⚕️ Healthcare Provider Dashboard")
    create_alert("Provider interface - Access patient records, create consultations, manage credentials", "info")

def show_professional_admin_dashboard():
    """Beautiful admin interface"""
    
    st.markdown("### ⚙️ System Administration")
    create_alert("Admin interface - System monitoring, user management, audit trails", "info")

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_professional_login_page()
    else:
        show_professional_dashboard()

if __name__ == "__main__":
    main()