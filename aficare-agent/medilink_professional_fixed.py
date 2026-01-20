"""
MediLink Professional Fixed - Beautiful, modern medical application
Cost-free deployment with stunning visuals and professional UX
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

try:
    from src.database.enhanced_database_manager import get_enhanced_database
    from src.utils.qr_manager import get_qr_manager
    from src.utils.export_manager import get_export_manager
    
    # Import medical AI components
    from medilink_simple import (
        PatientData, ConsultationResult, SimpleRuleEngine, 
        SimpleTriageEngine, MedicalAI, generate_medilink_id
    )
    
    IMPORTS_SUCCESS = True
except Exception as e:
    IMPORTS_SUCCESS = False
    import_error = str(e)

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink Professional",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Professional Medical Theme CSS (embedded)
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    
    :root {
        --primary-color: #2563eb;
        --primary-dark: #1d4ed8;
        --secondary-color: #10b981;
        --accent-color: #f59e0b;
        --danger-color: #ef4444;
        --warning-color: #f97316;
        --success-color: #22c55e;
        --info-color: #3b82f6;
        
        --bg-primary: #ffffff;
        --bg-secondary: #f8fafc;
        --bg-tertiary: #f1f5f9;
        --text-primary: #1e293b;
        --text-secondary: #64748b;
        --text-muted: #94a3b8;
        
        --border-color: #e2e8f0;
        --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
        --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
        --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1);
        
        --radius-sm: 0.375rem;
        --radius-md: 0.5rem;
        --radius-lg: 0.75rem;
        --radius-xl: 1rem;
    }
    
    .stApp {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
    }
    
    .main .block-container {
        padding-top: 2rem;
        padding-bottom: 2rem;
        max-width: 1200px;
    }
    
    .medical-header {
        background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
        padding: 2rem;
        border-radius: var(--radius-xl);
        color: white;
        text-align: center;
        margin-bottom: 2rem;
        box-shadow: var(--shadow-lg);
        position: relative;
        overflow: hidden;
    }
    
    .medical-header::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grid" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M 10 0 L 0 0 0 10" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="0.5"/></pattern></defs><rect width="100" height="100" fill="url(%23grid)"/></svg>');
        opacity: 0.3;
    }
    
    .medical-header h1 {
        font-size: 2.5rem;
        font-weight: 700;
        margin: 0;
        position: relative;
        z-index: 1;
    }
    
    .medical-header p {
        font-size: 1.1rem;
        margin: 0.5rem 0 0 0;
        opacity: 0.9;
        position: relative;
        z-index: 1;
    }
    
    .medical-card {
        background: var(--bg-primary);
        border-radius: var(--radius-lg);
        padding: 1.5rem;
        margin: 1rem 0;
        box-shadow: var(--shadow-md);
        border: 1px solid var(--border-color);
        transition: all 0.3s ease;
    }
    
    .medical-card:hover {
        transform: translateY(-2px);
        box-shadow: var(--shadow-lg);
    }
    
    .status-card {
        background: var(--bg-primary);
        border-radius: var(--radius-lg);
        padding: 1.5rem;
        text-align: center;
        box-shadow: var(--shadow-md);
        border-left: 4px solid var(--primary-color);
        transition: all 0.3s ease;
    }
    
    .status-card:hover {
        transform: translateY(-2px);
        box-shadow: var(--shadow-lg);
    }
    
    .status-card.success {
        border-left-color: var(--success-color);
    }
    
    .status-card.warning {
        border-left-color: var(--warning-color);
    }
    
    .status-card.danger {
        border-left-color: var(--danger-color);
    }
    
    .status-card.info {
        border-left-color: var(--info-color);
    }
    
    .status-number {
        font-size: 2rem;
        font-weight: 700;
        color: var(--primary-color);
        margin-bottom: 0.5rem;
    }
    
    .status-label {
        font-size: 0.875rem;
        color: var(--text-secondary);
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .stButton > button {
        background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
        color: white;
        border: none;
        border-radius: var(--radius-md);
        padding: 0.75rem 1.5rem;
        font-weight: 500;
        font-size: 0.875rem;
        transition: all 0.3s ease;
        box-shadow: var(--shadow-sm);
    }
    
    .stButton > button:hover {
        transform: translateY(-1px);
        box-shadow: var(--shadow-md);
        background: linear-gradient(135deg, var(--primary-dark) 0%, var(--primary-color) 100%);
    }
    
    .stTextInput > div > div > input {
        border-radius: var(--radius-md);
        border: 2px solid var(--border-color);
        padding: 0.75rem;
        font-size: 0.875rem;
        transition: all 0.3s ease;
    }
    
    .stTextInput > div > div > input:focus {
        border-color: var(--primary-color);
        box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
    }
    
    .alert {
        padding: 1rem;
        border-radius: var(--radius-md);
        margin: 1rem 0;
        border-left: 4px solid;
        font-weight: 500;
    }
    
    .alert.success {
        background: #f0fdf4;
        border-left-color: var(--success-color);
        color: #166534;
    }
    
    .alert.warning {
        background: #fffbeb;
        border-left-color: var(--warning-color);
        color: #92400e;
    }
    
    .alert.danger {
        background: #fef2f2;
        border-left-color: var(--danger-color);
        color: #991b1b;
    }
    
    .alert.info {
        background: #eff6ff;
        border-left-color: var(--info-color);
        color: #1e40af;
    }
    
    .access-code-display {
        background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
        border: 2px solid var(--info-color);
        border-radius: var(--radius-xl);
        padding: 2rem;
        text-align: center;
        margin: 1rem 0;
        position: relative;
        overflow: hidden;
    }
    
    .access-code-display::before {
        content: '';
        position: absolute;
        top: -50%;
        left: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle, rgba(59, 130, 246, 0.1) 0%, transparent 70%);
        animation: pulse 3s ease-in-out infinite;
    }
    
    @keyframes pulse {
        0%, 100% { transform: scale(1); opacity: 0.5; }
        50% { transform: scale(1.1); opacity: 0.8; }
    }
    
    .access-code-number {
        font-size: 3rem;
        font-weight: 700;
        color: var(--info-color);
        font-family: 'Roboto Mono', monospace;
        letter-spacing: 0.2em;
        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        position: relative;
        z-index: 1;
    }
    
    .audit-log-entry {
        background: var(--bg-primary);
        border-left: 4px solid var(--info-color);
        border-radius: var(--radius-md);
        padding: 1rem;
        margin: 0.5rem 0;
        box-shadow: var(--shadow-sm);
        transition: all 0.3s ease;
    }
    
    .audit-log-entry:hover {
        transform: translateX(4px);
        box-shadow: var(--shadow-md);
    }
    
    .audit-log-entry.success {
        border-left-color: var(--success-color);
    }
    
    .audit-log-entry.warning {
        border-left-color: var(--warning-color);
    }
    
    .audit-log-entry.danger {
        border-left-color: var(--danger-color);
    }
    
    /* Hide Streamlit Branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    
    @media (max-width: 768px) {
        .main .block-container {
            padding-left: 1rem;
            padding-right: 1rem;
        }
        
        .medical-header h1 {
            font-size: 2rem;
        }
        
        .medical-card {
            padding: 1rem;
        }
        
        .access-code-number {
            font-size: 2rem;
        }
    }
</style>
""", unsafe_allow_html=True)

# Medical icons
icons = {
    'patient': '👤', 'doctor': '👨‍⚕️', 'nurse': '👩‍⚕️', 'admin': '⚙️',
    'consultation': '🩺', 'key': '🔑', 'qr_code': '📱', 'export': '📄',
    'audit': '📊', 'profile': '👤', 'heart': '❤️', 'chart': '📈',
    'settings': '⚙️', 'power': '⚡', 'success': '✅', 'warning': '⚠️',
    'info': 'ℹ️', 'danger': '❌'
}

# Helper functions
def create_medical_header(title: str, subtitle: str, icon: str = "🏥"):
    """Create a professional medical header"""
    st.markdown(f"""
    <div class="medical-header">
        <h1>{icon} {title}</h1>
        <p>{subtitle}</p>
    </div>
    """, unsafe_allow_html=True)

def create_status_card(number: str, label: str, card_type: str = "info"):
    """Create a status card with number and label"""
    st.markdown(f"""
    <div class="status-card {card_type}">
        <div class="status-number">{number}</div>
        <div class="status-label">{label}</div>
    </div>
    """, unsafe_allow_html=True)

def create_medical_card(title: str, content: str, icon: str = "ℹ️"):
    """Create a medical information card"""
    st.markdown(f"""
    <div class="medical-card">
        <div style="display: flex; align-items: center; margin-bottom: 1rem; padding-bottom: 0.75rem; border-bottom: 2px solid #e2e8f0;">
            <div style="width: 2.5rem; height: 2.5rem; border-radius: 0.5rem; display: flex; align-items: center; justify-content: center; margin-right: 1rem; font-size: 1.25rem;">{icon}</div>
            <h3 style="font-size: 1.25rem; font-weight: 600; color: #1e293b; margin: 0;">{title}</h3>
        </div>
        <div>
            {content}
        </div>
    </div>
    """, unsafe_allow_html=True)

def create_alert(message: str, alert_type: str = "info"):
    """Create a styled alert message"""
    st.markdown(f"""
    <div class="alert {alert_type}">
        {message}
    </div>
    """, unsafe_allow_html=True)

def create_access_code_display(code: str, expires: str):
    """Create a beautiful access code display"""
    st.markdown(f"""
    <div class="access-code-display">
        <h3>🎯 Your Access Code</h3>
        <div class="access-code-number">{code}</div>
        <p>Expires: {expires}</p>
    </div>
    """, unsafe_allow_html=True)

def create_audit_log_entry(user: str, action: str, time: str, success: bool = True):
    """Create a styled audit log entry"""
    entry_type = "success" if success else "danger"
    icon = "✅" if success else "❌"
    
    st.markdown(f"""
    <div class="audit-log-entry {entry_type}">
        <strong>{icon} {user}</strong> - {action}<br>
        <small>📅 {time}</small>
    </div>
    """, unsafe_allow_html=True)

# Check if imports were successful
if not IMPORTS_SUCCESS:
    st.error(f"Failed to import required modules: {import_error}")
    st.info("Please ensure all dependencies are installed and the database is properly configured.")
    st.stop()

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
    tab1, tab2, tab3, tab4 = st.tabs([
        f"{icons['heart']} Overview",
        f"{icons['key']} Access Codes", 
        f"{icons['audit']} Access Log",
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