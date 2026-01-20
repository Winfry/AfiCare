"""
MediLink Enhanced Medical - Advanced version with enhanced database features
Single app for patients, doctors, and admins with comprehensive data persistence
Includes enhanced access codes, QR codes, audit logging, and data export
"""

import streamlit as st
from datetime import datetime, timedelta
import secrets
import json
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
import base64

# Import the enhanced components
import sys
sys.path.append(str(Path(__file__).parent))

from src.database.enhanced_database_manager import get_enhanced_database
from src.utils.qr_manager import get_qr_manager
from src.utils.export_manager import get_export_manager

# Import medical AI components from the simple version
from medilink_simple import (
    PatientData, ConsultationResult, SimpleRuleEngine, 
    SimpleTriageEngine, MedicalAI, generate_medilink_id
)

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink Enhanced",
    page_icon="🏥",
    layout="wide"
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

# Get enhanced instances
@st.cache_resource
def get_enhanced_instances():
    """Get enhanced database, QR manager, and export manager instances"""
    db = get_enhanced_database()
    qr_mgr = get_qr_manager(db)
    export_mgr = get_export_manager(db, qr_mgr)
    medical_ai = MedicalAI()
    return db, qr_mgr, export_mgr, medical_ai

db, qr_manager, export_manager, medical_ai = get_enhanced_instances()

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

.enhanced-info {
    background: #e8f5e8;
    border: 1px solid #4caf50;
    border-radius: 8px;
    padding: 1rem;
    margin: 1rem 0;
}

.access-code-display {
    background: #f0f8ff;
    border: 2px solid #2196f3;
    border-radius: 10px;
    padding: 1.5rem;
    text-align: center;
    margin: 1rem 0;
}

.qr-code-container {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 1rem;
}

.audit-log-entry {
    background: #f9f9f9;
    border-left: 4px solid #2196f3;
    padding: 0.5rem;
    margin: 0.5rem 0;
}
</style>
""", unsafe_allow_html=True)

def show_login_page():
    """Display enhanced login/registration page"""
    
    # Header
    st.markdown("""
    <div class="main-header patient-theme">
        <h1>🏥 AfiCare MediLink Enhanced</h1>
        <p>Advanced Medical Records with QR Codes, Audit Trails & Data Export</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Enhanced features info
    st.markdown("""
    <div class="enhanced-info">
        <h4>🚀 Enhanced Features:</h4>
        <p>✅ Temporary access codes with QR codes for easy sharing<br>
        ✅ Comprehensive audit trail - see who accessed your records<br>
        ✅ Enhanced patient profiles with medical alerts<br>
        ✅ Data export in PDF, JSON, and CSV formats<br>
        ✅ Healthcare provider credential management<br>
        ✅ All data encrypted and securely stored</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Login/Register tabs
    tab1, tab2 = st.tabs(["🔐 Login", "📝 Register"])
    
    with tab1:
        show_login_form()
    
    with tab2:
        show_registration_form()

def show_login_form():
    """Enhanced login form"""
    st.subheader("Login to AfiCare MediLink Enhanced")
    
    username = st.text_input("Username", placeholder="Enter your username")
    password = st.text_input("Password", type="password")
    role = st.selectbox("Login as:", ["patient", "doctor", "nurse", "admin"], format_func=lambda x: x.title())
    
    if st.button("🔐 Login", type="primary"):
        if not username or not password:
            st.error("❌ Please enter username and password")
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
                
                st.success(f"✅ Welcome back, {user_data['full_name']}!")
                st.rerun()
            else:
                # Log failed login
                db.log_access_enhanced(
                    patient_medilink_id="unknown",
                    accessed_by=username,
                    access_type="login",
                    access_method="direct",
                    success=False,
                    failure_reason="Invalid credentials"
                )
                st.error("❌ Login failed - Please check your credentials")

def show_registration_form():
    """Enhanced registration form"""
    st.subheader("Register New Account")
    
    role = st.selectbox("Register as:", ["patient", "doctor", "nurse", "admin"], format_func=lambda x: x.title())
    
    col1, col2 = st.columns(2)
    
    with col1:
        full_name = st.text_input("Full Name *")
        username = st.text_input("Username *")
        phone = st.text_input("Phone Number *")
        
    with col2:
        email = st.text_input("Email Address")
        password = st.text_input("Create Password *", type="password")
        confirm_password = st.text_input("Confirm Password *", type="password")
    
    # Patient-specific fields
    if role == "patient":
        col1, col2 = st.columns(2)
        with col1:
            age = st.number_input("Age *", min_value=0, max_value=120, value=25)
            gender = st.selectbox("Gender *", ["Male", "Female", "Other"])
        with col2:
            location = st.selectbox("Location", ["Nairobi", "Mombasa", "Kisumu", "Other"])
    else:
        age, gender, location = None, None, None
    
    if st.button("📝 Register Account", type="primary"):
        if not all([full_name, username, phone, password, confirm_password]):
            st.error("❌ Please fill in all required fields")
        elif password != confirm_password:
            st.error("❌ Passwords do not match")
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
                medilink_display = f" - MediLink ID: {user_data.get('medilink_id')}" if role == "patient" else ""
                st.success(f"🎉 Registration successful! Username: {username}{medilink_display}")
                st.info("👆 Click 'Login' tab to sign in!")
            else:
                st.error(f"❌ Registration failed: {message}")

def show_dashboard():
    """Enhanced role-based dashboard"""
    
    role = st.session_state.user_role
    user_data = st.session_state.user_data
    
    # Header
    theme_class = f"{role}-theme"
    st.markdown(f"""
    <div class="main-header {theme_class}">
        <h1>🏥 AfiCare MediLink Enhanced</h1>
        <p>{user_data['full_name']} - {role.title()}</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Sidebar with enhanced stats
    with st.sidebar:
        st.write(f"**Logged in as:** {role.title()}")
        if role == "patient" and st.session_state.medilink_id:
            st.write(f"**MediLink ID:** {st.session_state.medilink_id}")
        
        # Enhanced database stats
        stats = db.get_enhanced_system_stats()
        st.write("**📊 Enhanced System Stats:**")
        if stats.get('user_counts'):
            for role_name, count in stats['user_counts'].items():
                st.write(f"• {role_name.title()}s: {count}")
        st.write(f"• Total Consultations: {stats.get('total_consultations', 0)}")
        st.write(f"• Active Access Codes: {stats.get('active_access_codes', 0)}")
        st.write(f"• Audit Log Entries: {stats.get('total_audit_entries', 0)}")
        st.write(f"• Recent Exports: {stats.get('recent_exports', 0)}")
        
        if st.button("🚪 Logout"):
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
        show_enhanced_patient_dashboard()
    elif role in ["doctor", "nurse"]:
        show_enhanced_healthcare_provider_dashboard()
    elif role == "admin":
        show_enhanced_admin_dashboard()

def show_enhanced_patient_dashboard():
    """Enhanced patient interface with access codes, QR codes, and data export"""
    
    medilink_id = st.session_state.medilink_id
    
    # Patient overview
    col1, col2, col3, col4 = st.columns(4)
    
    consultations = db.get_patient_consultations(medilink_id)
    active_codes = db.get_active_access_codes(medilink_id)
    access_log = db.get_access_log_enhanced(medilink_id, days=7)
    
    with col1:
        st.metric("Total Visits", len(consultations))
    with col2:
        st.metric("Active Access Codes", len(active_codes))
    with col3:
        st.metric("Recent Access Events", len(access_log))
    with col4:
        last_visit = consultations[0]['consultation_date'][:10] if consultations else "Never"
        st.metric("Last Visit", last_visit)
    
    # Main tabs
    tab1, tab2, tab3, tab4, tab5 = st.tabs([
        "🏠 Overview", "🔑 Access Codes", "📊 Access Log", "📄 Export Data", "👤 Profile"
    ])
    
    with tab1:
        show_patient_overview(consultations)
    
    with tab2:
        show_access_code_management(medilink_id, active_codes)
    
    with tab3:
        show_patient_access_log(access_log)
    
    with tab4:
        show_data_export_interface(medilink_id)
    
    with tab5:
        show_patient_profile_management(medilink_id)

def show_patient_overview(consultations):
    """Show patient medical history overview"""
    
    st.subheader("📈 Your Medical History")
    
    if consultations:
        for consultation in consultations[:5]:
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
                    
                    if consultation.get('recommendations'):
                        st.write("**Recommendations:**")
                        for rec in consultation['recommendations'][:3]:
                            st.write(f"• {rec}")
    else:
        st.info("No consultations found. Visit a healthcare provider to start building your medical history!")

def show_access_code_management(medilink_id, active_codes):
    """Show access code generation and management"""
    
    st.subheader("🔑 Temporary Access Codes")
    st.write("Generate temporary codes to share your medical records with healthcare providers")
    
    # Generate new access code
    col1, col2 = st.columns(2)
    
    with col1:
        duration = st.selectbox("Code Duration", [1, 6, 24, 168], format_func=lambda x: f"{x} hours" if x < 24 else f"{x//24} days")
        
        permissions = {}
        st.write("**Permissions:**")
        permissions["view_basic_info"] = st.checkbox("Basic Information", value=True)
        permissions["view_medical_history"] = st.checkbox("Medical History", value=True)
        permissions["view_consultations"] = st.checkbox("Consultations", value=True)
        permissions["view_medications"] = st.checkbox("Medications", value=True)
        permissions["create_consultation"] = st.checkbox("Create New Consultation", value=False)
    
    with col2:
        if st.button("🔑 Generate Access Code", type="primary"):
            success, access_code = db.generate_access_code(medilink_id, duration, permissions)
            
            if success:
                st.success(f"✅ Access code generated: **{access_code}**")
                
                # Generate QR code
                expires_at = datetime.now() + timedelta(hours=duration)
                qr_display = qr_manager.create_patient_access_qr_display(
                    medilink_id, access_code, expires_at, permissions
                )
                
                if qr_display["success"]:
                    st.markdown("""
                    <div class="access-code-display">
                        <h3>🎯 Your Access Code</h3>
                        <h2 style="color: #2196f3;">{}</h2>
                        <p>Expires: {}</p>
                    </div>
                    """.format(access_code, expires_at.strftime("%Y-%m-%d %H:%M")), unsafe_allow_html=True)
                    
                    # Display QR code
                    if qr_display["qr_image"]:
                        st.markdown('<div class="qr-code-container">', unsafe_allow_html=True)
                        st.image(qr_display["qr_image"], caption="QR Code for Healthcare Providers", width=200)
                        st.markdown('</div>', unsafe_allow_html=True)
                        
                        # Instructions
                        st.info("📱 Show this QR code to your healthcare provider for instant access to your records")
                
                st.rerun()
            else:
                st.error(f"❌ Failed to generate access code: {access_code}")
    
    # Show active codes
    if active_codes:
        st.subheader("🔓 Active Access Codes")
        
        for code in active_codes:
            with st.expander(f"Code: {code['access_code']} (Expires: {code['expires_at'][:16]})"):
                col1, col2 = st.columns(2)
                
                with col1:
                    st.write(f"**Created:** {code['created_at'][:16]}")
                    st.write(f"**Duration:** {code['duration_hours']} hours")
                    if code.get('used_by'):
                        st.write(f"**Used by:** {code['used_by']}")
                        st.write(f"**Used at:** {code['used_at'][:16]}")
                
                with col2:
                    permissions = code.get('permissions', {})
                    st.write("**Permissions:**")
                    for perm, enabled in permissions.items():
                        status = "✅" if enabled else "❌"
                        st.write(f"{status} {perm.replace('_', ' ').title()}")
                
                if st.button(f"🗑️ Revoke Code {code['access_code']}", key=f"revoke_{code['id']}"):
                    if db.revoke_access_code(code['access_code'], medilink_id, medilink_id):
                        st.success("✅ Access code revoked")
                        st.rerun()
                    else:
                        st.error("❌ Failed to revoke access code")
    else:
        st.info("No active access codes. Generate one above to share your records.")

def show_patient_access_log(access_log):
    """Show patient access audit log"""
    
    st.subheader("📊 Access Log - Who Viewed Your Records")
    st.write("Complete audit trail of all access to your medical records")
    
    if access_log:
        for entry in access_log:
            success_icon = "✅" if entry['success'] else "❌"
            method_icon = {"direct": "🔐", "access_code": "🔑", "qr_code": "📱"}.get(entry['access_method'], "🔐")
            
            st.markdown(f"""
            <div class="audit-log-entry">
                <strong>{success_icon} {method_icon} {entry['accessed_by']}</strong> - {entry['access_type'].replace('_', ' ').title()}<br>
                <small>📅 {entry['accessed_at'][:16]} | Method: {entry['access_method'].replace('_', ' ').title()}</small>
                {f"<br><small>❌ Failed: {entry['failure_reason']}</small>" if not entry['success'] and entry.get('failure_reason') else ""}
            </div>
            """, unsafe_allow_html=True)
    else:
        st.info("No access events recorded in the last 30 days.")

def show_data_export_interface(medilink_id):
    """Show data export interface"""
    
    st.subheader("📄 Export Your Medical Data")
    st.write("Download your complete medical records in various formats")
    
    col1, col2 = st.columns(2)
    
    with col1:
        export_format = st.selectbox("Export Format", ["PDF", "JSON", "CSV"])
        
        # Date range selection
        use_date_range = st.checkbox("Filter by date range")
        start_date = None
        end_date = None
        
        if use_date_range:
            col_start, col_end = st.columns(2)
            with col_start:
                start_date = st.date_input("Start Date")
            with col_end:
                end_date = st.date_input("End Date")
        
        export_purpose = st.selectbox("Export Purpose", [
            "Personal Records", "New Healthcare Provider", "Insurance", "Legal"
        ])
    
    with col2:
        st.write("**Export will include:**")
        st.write("• Patient information and profile")
        st.write("• Complete consultation history")
        st.write("• Medical diagnoses and treatments")
        st.write("• Verification QR code (PDF only)")
        
        if export_format == "PDF":
            st.info("📄 PDF format is ideal for sharing with healthcare providers")
        elif export_format == "JSON":
            st.info("💾 JSON format is perfect for data portability")
        elif export_format == "CSV":
            st.info("📊 CSV format is great for data analysis")
    
    if st.button(f"📥 Export as {export_format}", type="primary"):
        with st.spinner(f"Generating {export_format} export..."):
            date_range = (start_date.isoformat() if start_date else None, 
                         end_date.isoformat() if end_date else None)
            
            success, export_data, message = export_manager.export_patient_data(
                medilink_id=medilink_id,
                export_format=export_format.lower(),
                date_range=date_range,
                exported_by=st.session_state.user_data['username'],
                export_purpose=export_purpose.lower().replace(' ', '_')
            )
            
            if success and export_data:
                st.success("✅ Export generated successfully!")
                
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
                st.error(f"❌ Export failed: {message}")
    
    # Show export history
    st.subheader("📋 Export History")
    export_history = db.get_export_history(medilink_id)
    
    if export_history:
        for export in export_history[:5]:
            st.write(f"📄 {export['export_format'].upper()} export on {export['created_at'][:16]} - {export['export_purpose'].replace('_', ' ').title()}")
    else:
        st.info("No previous exports found.")

def show_patient_profile_management(medilink_id):
    """Show enhanced patient profile management"""
    
    st.subheader("👤 Enhanced Medical Profile")
    st.write("Maintain comprehensive medical information for better healthcare")
    
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
            organ_donor = st.checkbox("Organ Donor", value=current_profile.get('organ_donor', False))
        
        with col2:
            st.write("**Emergency Information**")
            emergency_name = st.text_input("Emergency Contact Name",
                                         value=current_profile.get('emergency_contacts', [{}])[0].get('name', '') if current_profile.get('emergency_contacts') else '')
            emergency_phone = st.text_input("Emergency Contact Phone",
                                          value=current_profile.get('emergency_contacts', [{}])[0].get('phone', '') if current_profile.get('emergency_contacts') else '')
            emergency_relationship = st.text_input("Relationship",
                                                 value=current_profile.get('emergency_contacts', [{}])[0].get('relationship', '') if current_profile.get('emergency_contacts') else '')
            
            preferred_language = st.selectbox("Preferred Language",
                                            ["English", "Swahili", "Luganda", "Other"],
                                            index=["English", "Swahili", "Luganda", "Other"].index(current_profile.get('preferred_language', 'English')) if current_profile.get('preferred_language') in ["English", "Swahili", "Luganda", "Other"] else 0)
        
        medical_alerts = st.text_area("Medical Alerts (one per line)",
                                    value="\n".join(current_profile.get('medical_alerts', [])))
        
        if st.form_submit_button("💾 Update Profile", type="primary"):
            # Prepare profile data
            profile_data = {
                'allergies': [a.strip() for a in allergies.split('\n') if a.strip()],
                'chronic_conditions': [c.strip() for c in chronic_conditions.split('\n') if c.strip()],
                'blood_type': blood_type if blood_type else None,
                'organ_donor': organ_donor,
                'preferred_language': preferred_language,
                'medical_alerts': [a.strip() for a in medical_alerts.split('\n') if a.strip()],
                'emergency_contacts': [{
                    'name': emergency_name,
                    'phone': emergency_phone,
                    'relationship': emergency_relationship,
                    'primary': True
                }] if emergency_name else []
            }
            
            if db.update_patient_profile(medilink_id, profile_data, st.session_state.user_data['username']):
                st.success("✅ Profile updated successfully!")
                st.rerun()
            else:
                st.error("❌ Failed to update profile")

def show_enhanced_healthcare_provider_dashboard():
    """Enhanced healthcare provider interface"""
    
    st.subheader("👨‍⚕️ Healthcare Provider Dashboard")
    
    # Provider tabs
    tab1, tab2, tab3 = st.tabs(["🔍 Patient Access", "📊 My Activity", "👤 My Credentials"])
    
    with tab1:
        show_patient_access_interface()
    
    with tab2:
        show_provider_activity_dashboard()
    
    with tab3:
        show_provider_credentials_management()

def show_patient_access_interface():
    """Show patient access interface with QR code scanning"""
    
    st.subheader("🔍 Access Patient Records")
    
    # Access method selection
    access_method = st.radio("Access Method:", ["MediLink ID", "Access Code", "QR Code Data"])
    
    if access_method == "MediLink ID":
        medilink_id = st.text_input("Enter Patient MediLink ID", placeholder="ML-NBO-XXXX")
        
        if medilink_id and st.button("🔍 Load Patient"):
            patient_info = db.get_user_by_medilink_id(medilink_id)
            if patient_info:
                show_patient_consultation_interface(medilink_id, patient_info)
            else:
                st.error("❌ Patient not found")
    
    elif access_method == "Access Code":
        access_code = st.text_input("Enter 6-digit Access Code", placeholder="123456")
        
        if access_code and st.button("🔑 Verify Access Code"):
            success, medilink_id, permissions = db.verify_access_code(
                access_code, st.session_state.user_data['username']
            )
            
            if success:
                st.success(f"✅ Access granted to patient {medilink_id}")
                patient_info = db.get_user_by_medilink_id(medilink_id)
                show_patient_consultation_interface(medilink_id, patient_info, permissions)
            else:
                st.error("❌ Invalid or expired access code")
    
    elif access_method == "QR Code Data":
        st.info("📱 In a real implementation, this would use camera access to scan QR codes")
        qr_data = st.text_area("Paste QR Code Data (for testing)", placeholder="Encrypted QR code data...")
        
        if qr_data and st.button("📱 Scan QR Code"):
            success, medilink_id, permissions = qr_manager.validate_qr_data(
                qr_data, st.session_state.user_data['username']
            )
            
            if success:
                st.success(f"✅ QR Code verified - Access granted to patient {medilink_id}")
                patient_info = db.get_user_by_medilink_id(medilink_id)
                show_patient_consultation_interface(medilink_id, patient_info, permissions)
            else:
                st.error("❌ Invalid or expired QR code")

def show_patient_consultation_interface(medilink_id, patient_info, permissions=None):
    """Show patient consultation interface with permissions"""
    
    st.success(f"✅ Patient loaded: {patient_info['full_name']} ({medilink_id})")
    
    # Check permissions
    can_view_history = permissions is None or permissions.get('view_medical_history', True)
    can_create_consultation = permissions is None or permissions.get('create_consultation', True)
    
    # Patient overview
    col1, col2, col3 = st.columns(3)
    with col1:
        st.write(f"**Age:** {patient_info.get('age', 'N/A')}")
        st.write(f"**Gender:** {patient_info.get('gender', 'N/A')}")
    with col2:
        st.write(f"**Phone:** {patient_info.get('phone', 'N/A')}")
        st.write(f"**Location:** {patient_info.get('location', 'N/A')}")
    with col3:
        # Get emergency info
        emergency_info = db.get_patient_emergency_info(medilink_id)
        if emergency_info and emergency_info.get('medical_alerts'):
            st.warning(f"⚠️ Medical Alerts: {', '.join(emergency_info['medical_alerts'])}")
    
    # Medical history
    if can_view_history:
        consultations = db.get_patient_consultations(medilink_id)
        if consultations:
            st.subheader("📋 Medical History")
            for consultation in consultations[:3]:
                with st.expander(f"{consultation['consultation_date'][:16]} - {consultation['triage_level']}"):
                    st.write(f"**Doctor:** {consultation['doctor_username']}")
                    st.write(f"**Chief Complaint:** {consultation['chief_complaint']}")
                    if consultation['suspected_conditions']:
                        conditions = consultation['suspected_conditions']
                        if conditions:
                            st.write(f"**Diagnosis:** {conditions[0].get('display_name')} ({conditions[0].get('confidence', 0):.1%})")
    else:
        st.info("ℹ️ Medical history access not permitted with current access code")
    
    # New consultation
    if can_create_consultation:
        st.subheader("📋 New Consultation")
        show_consultation_form(medilink_id, patient_info)
    else:
        st.info("ℹ️ Consultation creation not permitted with current access code")

def show_consultation_form(medilink_id, patient_info):
    """Show consultation form with AI analysis"""
    
    chief_complaint = st.text_area("Chief Complaint")
    
    # Symptoms
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
    
    if st.button("🤖 Analyze with AI & Save", type="primary"):
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
            # Create patient data
            patient_data = PatientData(
                patient_id=medilink_id,
                age=patient_info.get('age', 30),
                gender=patient_info.get('gender', 'unknown'),
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
            
            # Run AI analysis
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
                    "patient_medilink_id": medilink_id,
                    "doctor_username": st.session_state.user_data['username'],
                    "chief_complaint": chief_complaint,
                    "symptoms": symptoms_list,
                    "triage_level": result.triage_level,
                    "suspected_conditions": result.suspected_conditions,
                    "recommendations": result.recommendations,
                    "confidence_score": result.confidence_score
                }
                
                if db.save_consultation(consultation_data):
                    st.success("✅ Consultation saved to database!")
                    
                    # Log consultation creation
                    db.log_access_enhanced(
                        patient_medilink_id=medilink_id,
                        accessed_by=st.session_state.user_data['username'],
                        access_type="create_consultation",
                        access_method="direct",
                        success=True,
                        data_accessed=["consultation", "symptoms", "vital_signs"]
                    )
                else:
                    st.error("❌ Failed to save consultation")

def show_provider_activity_dashboard():
    """Show provider activity dashboard"""
    
    st.subheader("📊 My Activity Dashboard")
    
    username = st.session_state.user_data['username']
    activity = db.get_provider_activity(username, days=7)
    
    if activity:
        # Activity summary
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Total Activities", len(activity))
        with col2:
            successful_activities = len([a for a in activity if a['success']])
            st.metric("Successful", successful_activities)
        with col3:
            unique_patients = len(set(a['patient_medilink_id'] for a in activity if a['patient_medilink_id'] != 'system'))
            st.metric("Unique Patients", unique_patients)
        
        # Recent activity
        st.subheader("Recent Activity")
        for entry in activity[:10]:
            success_icon = "✅" if entry['success'] else "❌"
            st.write(f"{success_icon} {entry['access_type'].replace('_', ' ').title()} - {entry['accessed_at'][:16]}")
            if entry['patient_medilink_id'] != 'system':
                st.write(f"   Patient: {entry['patient_medilink_id']}")
    else:
        st.info("No recent activity found.")

def show_provider_credentials_management():
    """Show provider credentials management"""
    
    st.subheader("👤 Professional Credentials")
    
    username = st.session_state.user_data['username']
    current_credentials = db.get_provider_credentials(username) or {}
    
    with st.form("credentials_form"):
        col1, col2 = st.columns(2)
        
        with col1:
            license_number = st.text_input("Medical License Number", 
                                         value=current_credentials.get('license_number', ''))
            medical_school = st.text_input("Medical School",
                                         value=current_credentials.get('medical_school', ''))
            years_experience = st.number_input("Years of Experience", 
                                             value=current_credentials.get('years_experience', 0),
                                             min_value=0, max_value=50)
        
        with col2:
            specializations = st.text_area("Specializations (one per line)",
                                         value="\n".join(current_credentials.get('specializations', [])))
            residency_info = st.text_input("Residency Information",
                                         value=current_credentials.get('residency_info', ''))
            hospital_affiliations = st.text_area("Hospital Affiliations (one per line)",
                                                value="\n".join(current_credentials.get('hospital_affiliations', [])))
        
        if st.form_submit_button("💾 Update Credentials", type="primary"):
            credentials_data = {
                'license_number': license_number,
                'medical_school': medical_school,
                'years_experience': years_experience,
                'specializations': [s.strip() for s in specializations.split('\n') if s.strip()],
                'residency_info': residency_info,
                'hospital_affiliations': [h.strip() for h in hospital_affiliations.split('\n') if h.strip()],
                'verification_status': 'pending'
            }
            
            if db.update_provider_credentials(username, credentials_data):
                st.success("✅ Credentials updated successfully!")
                st.rerun()
            else:
                st.error("❌ Failed to update credentials")
    
    # Show current verification status
    if current_credentials:
        status = current_credentials.get('verification_status', 'pending')
        status_colors = {'verified': '✅', 'pending': '⏳', 'expired': '❌'}
        st.write(f"**Verification Status:** {status_colors.get(status, '❓')} {status.title()}")

def show_enhanced_admin_dashboard():
    """Enhanced admin interface with comprehensive system monitoring"""
    
    st.subheader("⚙️ System Administration")
    
    # Admin tabs
    tab1, tab2, tab3, tab4 = st.tabs(["📊 System Stats", "🔍 Audit Trail", "👥 User Management", "🔧 System Tools"])
    
    with tab1:
        show_system_statistics()
    
    with tab2:
        show_system_audit_trail()
    
    with tab3:
        show_user_management()
    
    with tab4:
        show_system_tools()

def show_system_statistics():
    """Show comprehensive system statistics"""
    
    stats = db.get_enhanced_system_stats()
    
    # Main metrics
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        total_users = sum(stats.get('user_counts', {}).values())
        st.metric("Total Users", total_users)
    
    with col2:
        st.metric("Total Consultations", stats.get('total_consultations', 0))
    
    with col3:
        st.metric("Active Access Codes", stats.get('active_access_codes', 0))
    
    with col4:
        st.metric("Audit Log Entries", stats.get('total_audit_entries', 0))
    
    # User breakdown
    if stats.get('user_counts'):
        st.subheader("👥 User Distribution")
        for role, count in stats['user_counts'].items():
            st.write(f"• {role.title()}s: {count}")
    
    # Recent activity
    st.subheader("📈 Recent Activity")
    col1, col2 = st.columns(2)
    
    with col1:
        st.metric("Recent Exports", stats.get('recent_exports', 0))
    
    with col2:
        st.metric("Complete Profiles", stats.get('complete_patient_profiles', 0))

def show_system_audit_trail():
    """Show system-wide audit trail"""
    
    st.subheader("🔍 System Audit Trail")
    
    # Audit summary
    audit_summary = db.get_system_audit_summary(days=7)
    
    if audit_summary:
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Total Events (7 days)", audit_summary.get('total_events', 0))
        
        with col2:
            st.metric("Failed Attempts", audit_summary.get('failed_attempts', 0))
        
        with col3:
            success_rate = audit_summary.get('success_rate', 100)
            st.metric("Success Rate", f"{success_rate:.1f}%")
        
        # Access by method
        if audit_summary.get('access_by_method'):
            st.subheader("📊 Access Methods")
            for method, count in audit_summary['access_by_method'].items():
                st.write(f"• {method.replace('_', ' ').title()}: {count}")
        
        # Top providers
        if audit_summary.get('top_providers'):
            st.subheader("👨‍⚕️ Most Active Providers")
            for provider in audit_summary['top_providers'][:5]:
                st.write(f"• {provider['username']}: {provider['activity_count']} activities")

def show_user_management():
    """Show user management interface"""
    
    st.subheader("👥 User Management")
    st.info("User management features would be implemented here")
    
    # Placeholder for user management features
    st.write("Features to implement:")
    st.write("• View all users")
    st.write("• Verify provider credentials")
    st.write("• Manage user permissions")
    st.write("• Reset passwords")

def show_system_tools():
    """Show system maintenance tools"""
    
    st.subheader("🔧 System Maintenance Tools")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Database Maintenance**")
        
        if st.button("🧹 Cleanup Expired Access Codes"):
            cleaned = db.cleanup_expired_access_codes()
            st.success(f"✅ Cleaned up {cleaned} expired access codes")
        
        if st.button("📊 Refresh System Stats"):
            st.rerun()
    
    with col2:
        st.write("**System Information**")
        st.write(f"• Database: SQLite Enhanced")
        st.write(f"• Features: Access Codes, QR Codes, Audit Trail, Data Export")
        st.write(f"• Version: Enhanced Medical v1.0")

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        show_dashboard()

if __name__ == "__main__":
    main()