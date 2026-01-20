"""
MediLink Beautiful - Working beautiful version with enhanced styling
"""

import streamlit as st
from datetime import datetime, timedelta
import secrets
import json
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple

# Import enhanced components
import sys
sys.path.append(str(Path(__file__).parent))

from src.database.enhanced_database_manager import get_enhanced_database
from src.utils.qr_manager import get_qr_manager
from src.utils.export_manager import get_export_manager

# Import medical AI components
from medilink_simple import (
    PatientData, ConsultationResult, SimpleRuleEngine, 
    SimpleTriageEngine, MedicalAI, generate_medilink_id
)

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink Beautiful",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Beautiful CSS styling
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    
    .stApp {
        font-family: 'Inter', sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    
    .main-header {
        background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
        padding: 2rem;
        border-radius: 15px;
        color: white;
        text-align: center;
        margin-bottom: 2rem;
        box-shadow: 0 10px 25px rgba(0,0,0,0.1);
    }
    
    .main-header h1 {
        font-size: 2.5rem;
        font-weight: 700;
        margin: 0;
    }
    
    .main-header p {
        font-size: 1.1rem;
        margin: 0.5rem 0 0 0;
        opacity: 0.9;
    }
    
    .feature-card {
        background: white;
        padding: 1.5rem;
        border-radius: 12px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        margin: 1rem 0;
        border-left: 4px solid #2563eb;
        transition: transform 0.3s ease;
    }
    
    .feature-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 15px rgba(0,0,0,0.15);
    }
    
    .status-metric {
        background: white;
        padding: 1.5rem;
        border-radius: 12px;
        text-align: center;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        border-top: 4px solid #10b981;
    }
    
    .status-number {
        font-size: 2rem;
        font-weight: 700;
        color: #2563eb;
        margin-bottom: 0.5rem;
    }
    
    .status-label {
        color: #64748b;
        font-weight: 500;
        text-transform: uppercase;
        font-size: 0.875rem;
        letter-spacing: 0.05em;
    }
    
    .alert-success {
        background: #f0fdf4;
        border: 1px solid #22c55e;
        border-radius: 8px;
        padding: 1rem;
        color: #166534;
        margin: 1rem 0;
    }
    
    .alert-info {
        background: #eff6ff;
        border: 1px solid #3b82f6;
        border-radius: 8px;
        padding: 1rem;
        color: #1e40af;
        margin: 1rem 0;
    }
    
    .alert-warning {
        background: #fffbeb;
        border: 1px solid #f59e0b;
        border-radius: 8px;
        padding: 1rem;
        color: #92400e;
        margin: 1rem 0;
    }
    
    .stButton > button {
        background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
        color: white;
        border: none;
        border-radius: 8px;
        padding: 0.75rem 1.5rem;
        font-weight: 500;
        transition: all 0.3s ease;
    }
    
    .stButton > button:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(37, 99, 235, 0.4);
    }
    
    .stTextInput > div > div > input {
        border-radius: 8px;
        border: 2px solid #e2e8f0;
        transition: border-color 0.3s ease;
    }
    
    .stTextInput > div > div > input:focus {
        border-color: #2563eb;
        box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
    }
    
    .access-code-display {
        background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
        border: 2px solid #3b82f6;
        border-radius: 15px;
        padding: 2rem;
        text-align: center;
        margin: 1rem 0;
    }
    
    .access-code-number {
        font-size: 3rem;
        font-weight: 700;
        color: #3b82f6;
        font-family: 'Courier New', monospace;
        letter-spacing: 0.2em;
    }
    
    /* Hide Streamlit branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
</style>
""", unsafe_allow_html=True)

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

def show_beautiful_login_page():
    """Display beautiful login/registration page"""
    
    # Beautiful header
    st.markdown("""
    <div class="main-header">
        <h1>🏥 AfiCare MediLink Beautiful</h1>
        <p>Advanced Medical Records • Beautiful Design • Cost-Free Forever</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Feature showcase
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown("""
        <div class="status-metric">
            <div class="status-number">100%</div>
            <div class="status-label">Cost Free</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="status-metric">
            <div class="status-number">7</div>
            <div class="status-label">Medical Conditions</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("""
        <div class="status-metric">
            <div class="status-number">24/7</div>
            <div class="status-label">Available</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown("""
        <div class="status-metric">
            <div class="status-number">∞</div>
            <div class="status-label">Patients</div>
        </div>
        """, unsafe_allow_html=True)
    
    # Enhanced features
    st.markdown("""
    <div class="feature-card">
        <h3>🚀 Professional Features</h3>
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
    </div>
    """, unsafe_allow_html=True)
    
    # Login/Register tabs
    tab1, tab2 = st.tabs(["🔐 Login", "📝 Register"])
    
    with tab1:
        show_beautiful_login_form()
    
    with tab2:
        show_beautiful_registration_form()

def show_beautiful_login_form():
    """Beautiful login form"""
    
    st.markdown("### Sign In to Your Account")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        username = st.text_input("Username", placeholder="Enter your username")
        password = st.text_input("Password", type="password")
        role = st.selectbox("Login as:", ["patient", "doctor", "nurse", "admin"], 
                           format_func=lambda x: f"👤 {x.title()}" if x == "patient" else f"👨‍⚕️ {x.title()}")
    
    with col2:
        st.markdown("""
        <div class="alert-info">
            <h4>💡 Demo Accounts</h4>
            <p><strong>Patient:</strong> demo_patient<br>
            <strong>Doctor:</strong> demo_doctor<br>
            <strong>Password:</strong> demo123</p>
        </div>
        """, unsafe_allow_html=True)
    
    if st.button("🔐 Sign In", type="primary", use_container_width=True):
        if not username or not password:
            st.markdown('<div class="alert-warning">Please enter both username and password</div>', unsafe_allow_html=True)
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
                
                st.markdown(f'<div class="alert-success">Welcome back, {user_data["full_name"]}! 🎉</div>', unsafe_allow_html=True)
                st.rerun()
            else:
                st.markdown('<div class="alert-warning">Invalid credentials. Please try again.</div>', unsafe_allow_html=True)

def show_beautiful_registration_form():
    """Beautiful registration form"""
    
    st.markdown("### Create Your Account")
    
    role = st.selectbox("Account Type:", ["patient", "doctor", "nurse", "admin"], 
                       format_func=lambda x: f"👤 {x.title()}" if x == "patient" else f"👨‍⚕️ {x.title()}")
    
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
    
    if st.button("📝 Create Account", type="primary", use_container_width=True):
        if not all([full_name, username, phone, password, confirm_password]):
            st.markdown('<div class="alert-warning">Please fill in all required fields</div>', unsafe_allow_html=True)
        elif password != confirm_password:
            st.markdown('<div class="alert-warning">Passwords do not match</div>', unsafe_allow_html=True)
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
                medilink_display = f"<br><strong>MediLink ID:</strong> <code>{user_data.get('medilink_id')}</code>" if role == "patient" else ""
                st.markdown(f'''
                <div class="alert-success">
                    <h4>🎉 Account created successfully!</h4>
                    <p><strong>Username:</strong> <code>{username}</code>{medilink_display}</p>
                    <p>👆 Switch to Login tab to sign in!</p>
                </div>
                ''', unsafe_allow_html=True)
            else:
                st.markdown(f'<div class="alert-warning">Registration failed: {message}</div>', unsafe_allow_html=True)

def show_beautiful_dashboard():
    """Beautiful role-based dashboard"""
    
    role = st.session_state.user_role
    user_data = st.session_state.user_data
    
    # Beautiful header
    st.markdown(f"""
    <div class="main-header">
        <h1>Welcome, {user_data['full_name']}</h1>
        <p>👤 {role.title()} Dashboard • AfiCare MediLink Beautiful</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Enhanced sidebar
    with st.sidebar:
        st.markdown(f"### ⚙️ Account Info")
        st.write(f"**Role:** 👤 {role.title()}")
        if role == "patient" and st.session_state.medilink_id:
            st.code(st.session_state.medilink_id, language=None)
        
        # Enhanced system stats
        stats = db.get_enhanced_system_stats()
        st.markdown(f"### 📊 System Stats")
        
        if stats.get('user_counts'):
            for role_name, count in stats['user_counts'].items():
                st.metric(f"{role_name.title()}s", count)
        
        st.metric("Consultations", stats.get('total_consultations', 0))
        st.metric("Active Codes", stats.get('active_access_codes', 0))
        
        st.markdown("---")
        if st.button("🚪 Logout", use_container_width=True):
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
        show_beautiful_patient_dashboard()
    elif role in ["doctor", "nurse"]:
        show_beautiful_provider_dashboard()
    elif role == "admin":
        show_beautiful_admin_dashboard()

def show_beautiful_patient_dashboard():
    """Beautiful patient interface"""
    
    medilink_id = st.session_state.medilink_id
    
    # Patient metrics
    consultations = db.get_patient_consultations(medilink_id)
    active_codes = db.get_active_access_codes(medilink_id)
    access_log = db.get_access_log_enhanced(medilink_id, days=7)
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown(f"""
        <div class="status-metric">
            <div class="status-number">{len(consultations)}</div>
            <div class="status-label">Total Visits</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
        <div class="status-metric">
            <div class="status-number">{len(active_codes)}</div>
            <div class="status-label">Active Codes</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
        <div class="status-metric">
            <div class="status-number">{len(access_log)}</div>
            <div class="status-label">Recent Access</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        last_visit = consultations[0]['consultation_date'][:10] if consultations else "Never"
        st.markdown(f"""
        <div class="status-metric">
            <div class="status-number">{last_visit}</div>
            <div class="status-label">Last Visit</div>
        </div>
        """, unsafe_allow_html=True)
    
    # Beautiful tabs
    tab1, tab2, tab3 = st.tabs(["❤️ Overview", "🔑 Access Codes", "📊 Access Log"])
    
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
            st.markdown('<div class="alert-info">No consultations found. Visit a healthcare provider to start building your medical history!</div>', unsafe_allow_html=True)
    
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
        
        with col2:
            if st.button("🔑 Generate Access Code", type="primary"):
                success, access_code = db.generate_access_code(medilink_id, duration, permissions)
                
                if success:
                    expires_at = datetime.now() + timedelta(hours=duration)
                    
                    st.markdown(f"""
                    <div class="access-code-display">
                        <h3>🎯 Your Access Code</h3>
                        <div class="access-code-number">{access_code}</div>
                        <p>Expires: {expires_at.strftime("%Y-%m-%d %H:%M")}</p>
                    </div>
                    """, unsafe_allow_html=True)
                    
                    # Generate QR code
                    qr_display = qr_manager.create_patient_access_qr_display(
                        medilink_id, access_code, expires_at, permissions
                    )
                    
                    if qr_display["success"] and qr_display["qr_image"]:
                        st.image(qr_display["qr_image"], caption="QR Code for Healthcare Providers", width=200)
                        st.markdown('<div class="alert-info">📱 Show this QR code to your healthcare provider for instant access</div>', unsafe_allow_html=True)
                    
                    st.rerun()
                else:
                    st.markdown(f'<div class="alert-warning">Failed to generate access code: {access_code}</div>', unsafe_allow_html=True)
        
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
                                st.markdown('<div class="alert-success">Access code revoked successfully</div>', unsafe_allow_html=True)
                                st.rerun()
    
    with tab3:
        st.markdown("### 📊 Access Log")
        
        if access_log:
            for entry in access_log:
                success_icon = "✅" if entry['success'] else "❌"
                method_icon = {"direct": "🔐", "access_code": "🔑", "qr_code": "📱"}.get(entry['access_method'], "🔐")
                
                st.markdown(f"""
                <div class="feature-card">
                    <strong>{success_icon} {method_icon} {entry['accessed_by']}</strong> - {entry['access_type'].replace('_', ' ').title()}<br>
                    <small>📅 {entry['accessed_at'][:16]} | Method: {entry['access_method'].replace('_', ' ').title()}</small>
                </div>
                """, unsafe_allow_html=True)
        else:
            st.markdown('<div class="alert-info">No access events recorded in the last 7 days.</div>', unsafe_allow_html=True)

def show_beautiful_provider_dashboard():
    """Beautiful healthcare provider interface"""
    
    st.markdown("### 👨‍⚕️ Healthcare Provider Dashboard")
    st.markdown('<div class="alert-info">Provider interface - Access patient records, create consultations, manage credentials</div>', unsafe_allow_html=True)

def show_beautiful_admin_dashboard():
    """Beautiful admin interface"""
    
    st.markdown("### ⚙️ System Administration")
    st.markdown('<div class="alert-info">Admin interface - System monitoring, user management, audit trails</div>', unsafe_allow_html=True)

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_beautiful_login_page()
    else:
        show_beautiful_dashboard()

if __name__ == "__main__":
    main()