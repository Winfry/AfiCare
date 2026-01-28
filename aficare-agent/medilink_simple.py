"""
MediLink Simple - Simplified version to avoid port issues
Single app for patients, doctors, and admins with role-based interface
Includes rule-based medical AI for consultations
Now with PWA support for mobile installation!
"""

import streamlit as st
from datetime import datetime
import secrets
import os
import base64
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import sys
from pathlib import Path
import json

# Get the directory of this script for asset paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(SCRIPT_DIR, "assets")

# Add src to path for imports
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

# Import the real AfiCare Agent
try:
    from core.agent import AfiCareAgent, PatientData, ConsultationResult
    from utils.config import Config
    REAL_AI_AVAILABLE = True
    print("✅ Real AfiCare AI Agent loaded successfully!")
except ImportError as e:
    print(f"⚠️ Could not load real AI Agent: {e}")
    print("🔄 Using simplified AI instead...")
    REAL_AI_AVAILABLE = False

@dataclass
class PatientData:
    """Patient information structure"""
    patient_id: str
    age: int
    gender: str
    symptoms: List[str]
    vital_signs: Dict[str, float]
    medical_history: List[str]
    current_medications: List[str]
    chief_complaint: str

@dataclass
class ConsultationResult:
    """Consultation outcome structure"""
    patient_id: str
    timestamp: datetime
    triage_level: str
    suspected_conditions: List[Dict[str, Any]]
    recommendations: List[str]
    referral_needed: bool
    follow_up_required: bool
    confidence_score: float

class SimpleRuleEngine:
    """Rule-based medical engine for consultations"""
    
    def __init__(self):
        self.conditions = self._load_conditions()
    
    def _load_conditions(self):
        """Load medical conditions and their rules"""
        conditions = {}
        
        # Malaria
        conditions["malaria"] = {
            "name": "Malaria",
            "symptoms": {
                "fever": 0.9,
                "chills": 0.8,
                "headache": 0.7,
                "muscle_aches": 0.6,
                "nausea": 0.5,
                "fatigue": 0.6,
                "vomiting": 0.5,
                "sweating": 0.4
            },
            "treatment": [
                "Artemether-Lumefantrine based on weight",
                "Paracetamol for fever and pain",
                "Oral rehydration therapy",
                "Rest and adequate nutrition",
                "Follow-up in 3 days"
            ],
            "danger_signs": ["severe_headache", "confusion", "difficulty_breathing"]
        }
        
        # Pneumonia
        conditions["pneumonia"] = {
            "name": "Pneumonia",
            "symptoms": {
                "cough": 0.9,
                "fever": 0.8,
                "difficulty_breathing": 0.9,
                "chest_pain": 0.7,
                "fatigue": 0.6,
                "rapid_breathing": 0.8,
                "chills": 0.6
            },
            "treatment": [
                "Amoxicillin 15mg/kg twice daily for 5 days (children)",
                "Amoxicillin 500mg three times daily for 5 days (adults)",
                "Oxygen therapy if SpO2 < 90%",
                "Adequate fluid intake",
                "Follow-up in 2-3 days"
            ],
            "danger_signs": ["difficulty_breathing", "chest_pain", "high_fever"]
        }
        
        # Hypertension
        conditions["hypertension"] = {
            "name": "Hypertension",
            "symptoms": {
                "headache": 0.4,
                "dizziness": 0.5,
                "blurred_vision": 0.6,
                "chest_pain": 0.3,
                "fatigue": 0.3
            },
            "treatment": [
                "Lifestyle modifications (diet, exercise)",
                "Regular blood pressure monitoring",
                "Antihypertensive medication if indicated",
                "Reduce salt intake",
                "Regular follow-up"
            ],
            "danger_signs": ["severe_headache", "chest_pain", "difficulty_breathing"]
        }
        
        # Common Cold/Flu
        conditions["common_cold"] = {
            "name": "Common Cold/Flu",
            "symptoms": {
                "cough": 0.7,
                "runny_nose": 0.8,
                "sore_throat": 0.7,
                "headache": 0.5,
                "fatigue": 0.6,
                "muscle_aches": 0.4,
                "fever": 0.4
            },
            "treatment": [
                "Rest and adequate sleep",
                "Increase fluid intake",
                "Paracetamol for fever and pain",
                "Warm salt water gargling",
                "Return if symptoms worsen"
            ],
            "danger_signs": ["high_fever", "difficulty_breathing", "severe_headache"]
        }
        
        return conditions
    
    def analyze_symptoms(self, symptoms: List[str], vital_signs: Dict[str, float], age: int, gender: str):
        """Analyze symptoms against medical conditions"""
        
        results = []
        normalized_symptoms = [s.lower().replace(" ", "_") for s in symptoms]
        
        for condition_name, condition_data in self.conditions.items():
            score = 0.0
            matching_symptoms = []
            
            # Check symptom matches
            for symptom, weight in condition_data["symptoms"].items():
                if any(symptom in ns or ns in symptom for ns in normalized_symptoms):
                    score += weight
                    matching_symptoms.append(symptom.replace("_", " ").title())
            
            # Vital signs adjustments
            temp = vital_signs.get("temperature", 37.0)
            bp_systolic = vital_signs.get("systolic_bp", 120)
            resp_rate = vital_signs.get("respiratory_rate", 16)
            
            if condition_name == "malaria" and temp > 38.5:
                score += 0.3
            elif condition_name == "pneumonia" and (resp_rate > 24 or temp > 38.0):
                score += 0.2
            elif condition_name == "hypertension" and bp_systolic > 140:
                score += 0.4
            elif condition_name == "common_cold" and temp < 38.0:
                score += 0.1
            
            # Age factors
            if condition_name == "pneumonia" and (age < 5 or age > 65):
                score += 0.1
            elif condition_name == "hypertension" and age > 40:
                score += 0.1
            
            if score > 0.2:  # Only include significant matches
                results.append({
                    "name": condition_name,
                    "display_name": condition_data["name"],
                    "confidence": min(score, 1.0),
                    "matching_symptoms": matching_symptoms,
                    "treatment": condition_data["treatment"],
                    "danger_signs": condition_data.get("danger_signs", [])
                })
        
        # Sort by confidence
        results.sort(key=lambda x: x["confidence"], reverse=True)
        return results

class SimpleTriageEngine:
    """Rule-based triage assessment"""
    
    def assess_urgency(self, patient_data: PatientData):
        """Assess patient urgency level"""
        
        score = 0.0
        danger_signs = []
        
        # Check symptoms for danger signs
        symptom_text = " ".join(patient_data.symptoms).lower()
        
        emergency_keywords = [
            "difficulty breathing", "chest pain", "unconscious", 
            "severe bleeding", "convulsions", "altered consciousness",
            "severe headache", "confusion", "high fever"
        ]
        
        for keyword in emergency_keywords:
            if keyword in symptom_text:
                score += 1.0
                danger_signs.append(keyword)
        
        # Check vital signs
        temp = patient_data.vital_signs.get("temperature", 37.0)
        if temp > 40.0 or temp < 35.0:
            score += 0.8
            danger_signs.append(f"Critical temperature: {temp}°C")
        
        pulse = patient_data.vital_signs.get("pulse", 80)
        if pulse > 120 or pulse < 50:
            score += 0.6
            danger_signs.append(f"Abnormal pulse: {pulse} bpm")
        
        resp_rate = patient_data.vital_signs.get("respiratory_rate", 16)
        if resp_rate > 30 or resp_rate < 8:
            score += 0.7
            danger_signs.append(f"Abnormal breathing: {resp_rate}/min")
        
        bp_systolic = patient_data.vital_signs.get("systolic_bp", 120)
        if bp_systolic > 180 or bp_systolic < 90:
            score += 0.5
            danger_signs.append(f"Critical blood pressure: {bp_systolic}")
        
        # Age factors
        if patient_data.age < 1 or patient_data.age > 75:
            score += 0.2
        
        # Determine triage level
        if score >= 0.8:
            level = "EMERGENCY"
            referral = True
        elif score >= 0.5:
            level = "URGENT"
            referral = True
        elif score >= 0.3:
            level = "LESS_URGENT"
            referral = False
        else:
            level = "NON_URGENT"
            referral = False
        
        return {
            "level": level,
            "score": score,
            "danger_signs": danger_signs,
            "referral_needed": referral
        }

class MedicalAI:
    """Main medical AI system combining rules and triage"""
    
    def __init__(self):
        self.rule_engine = SimpleRuleEngine()
        self.triage_engine = SimpleTriageEngine()
    
    def conduct_consultation(self, patient_data: PatientData) -> ConsultationResult:
        """Conduct complete medical consultation"""
        
        # Triage assessment
        triage_result = self.triage_engine.assess_urgency(patient_data)
        
        # Symptom analysis
        condition_matches = self.rule_engine.analyze_symptoms(
            patient_data.symptoms,
            patient_data.vital_signs,
            patient_data.age,
            patient_data.gender
        )
        
        # Generate recommendations
        recommendations = []
        
        if triage_result["level"] == "EMERGENCY":
            recommendations.append("🚨 IMMEDIATE MEDICAL ATTENTION REQUIRED")
            recommendations.append("Transfer to emergency department immediately")
        
        # Add condition-specific recommendations
        for condition in condition_matches[:2]:  # Top 2 conditions
            if condition["confidence"] > 0.5:
                recommendations.extend(condition["treatment"][:3])  # Top 3 treatments
        
        # General recommendations
        if triage_result["level"] in ["NON_URGENT", "LESS_URGENT"]:
            recommendations.extend([
                "Monitor symptoms and return if condition worsens",
                "Ensure adequate rest and hydration",
                "Follow medication instructions carefully"
            ])
        
        # Determine follow-up
        chronic_conditions = ["hypertension", "diabetes"]
        follow_up_required = any(
            condition["name"] in chronic_conditions 
            for condition in condition_matches 
            if condition["confidence"] > 0.4
        ) or triage_result["level"] in ["URGENT", "EMERGENCY"]
        
        return ConsultationResult(
            patient_id=patient_data.patient_id,
            timestamp=datetime.now(),
            triage_level=triage_result["level"],
            suspected_conditions=condition_matches,
            recommendations=recommendations,
            referral_needed=triage_result["referral_needed"],
            follow_up_required=follow_up_required,
            confidence_score=condition_matches[0]["confidence"] if condition_matches else 0.0
        )

# Initialize the medical AI system - REAL AfiCare Agent
@st.cache_resource
def get_medical_ai():
    """Get cached medical AI instance - Real AfiCare Agent"""
    try:
        # Try to load the real AfiCare Agent
        from core.agent import AfiCareAgent, PatientData as RealPatientData, ConsultationResult as RealConsultationResult
        from utils.config import Config
        
        config = Config()
        agent = AfiCareAgent(config)
        
        # Create a wrapper to make it compatible with the simple interface
        class AfiCareAgentWrapper:
            def __init__(self, agent):
                self.agent = agent
                self.name = "AfiCare AI Agent (Full Version)"
            
            def conduct_consultation(self, patient_data):
                """Convert simple patient data to real agent format and run consultation"""
                import asyncio
                
                # Convert to real agent format
                real_patient_data = RealPatientData(
                    patient_id=patient_data.patient_id,
                    age=patient_data.age,
                    gender=patient_data.gender,
                    symptoms=patient_data.symptoms,
                    vital_signs=patient_data.vital_signs,
                    medical_history=patient_data.medical_history,
                    current_medications=patient_data.current_medications,
                    chief_complaint=patient_data.chief_complaint
                )
                
                # Run the real AI consultation
                real_result = asyncio.run(self.agent.conduct_consultation(real_patient_data))
                
                # Convert back to simple format
                simple_result = ConsultationResult(
                    patient_id=real_result.patient_id,
                    timestamp=real_result.timestamp,
                    triage_level=real_result.triage_level,
                    suspected_conditions=real_result.suspected_conditions,
                    recommendations=real_result.recommendations,
                    referral_needed=real_result.referral_needed,
                    follow_up_required=real_result.follow_up_required,
                    confidence_score=real_result.confidence_score
                )
                
                return simple_result
        
        wrapper = AfiCareAgentWrapper(agent)
        print(f"✅ Real AfiCare AI Agent loaded with {len(agent.plugin_manager.plugins)} plugins!")
        return wrapper
        
    except Exception as e:
        print(f"⚠️ Could not load real AfiCare Agent: {e}")
        print("🔄 Using simplified AI instead...")
        return MedicalAI()

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================
# PWA AND LOGO SUPPORT
# ============================================

def get_logo_base64():
    """Get logo as base64 for embedding"""
    logo_path = os.path.join(ASSETS_DIR, "icon-192x192.png")
    if os.path.exists(logo_path):
        with open(logo_path, "rb") as f:
            return base64.b64encode(f.read()).decode()
    return None

def inject_pwa_support():
    """Inject PWA meta tags and styles for mobile app experience"""
    pwa_html = """
    <!-- PWA Meta Tags -->
    <meta name="application-name" content="AfiCare MediLink">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="default">
    <meta name="apple-mobile-web-app-title" content="AfiCare">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="theme-color" content="#2E7D32">

    <style>
        /* Mobile-first responsive design */
        @media (max-width: 768px) {
            .stApp { padding: 10px !important; }
            .stButton > button {
                width: 100% !important;
                padding: 15px !important;
                font-size: 16px !important;
                border-radius: 12px !important;
                min-height: 48px;
            }
            .stTextInput > div > div > input {
                font-size: 16px !important;
                padding: 15px !important;
            }
            h1 { font-size: 24px !important; }
            h2 { font-size: 20px !important; }
            h3 { font-size: 18px !important; }
        }

        /* Touch-friendly and smooth scrolling */
        html { scroll-behavior: smooth; }
        * { -webkit-tap-highlight-color: rgba(46, 125, 50, 0.2); }

        /* Safe area padding for notched phones */
        .stApp {
            padding-left: env(safe-area-inset-left);
            padding-right: env(safe-area-inset-right);
            padding-bottom: env(safe-area-inset-bottom);
        }

        /* Logo header styling */
        .aficare-logo-header {
            display: flex;
            align-items: center;
            gap: 15px;
            padding: 15px 20px;
            background: linear-gradient(135deg, #E8F5E9 0%, #C8E6C9 100%);
            border-radius: 15px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(46, 125, 50, 0.1);
        }

        .aficare-logo-icon {
            width: 60px;
            height: 60px;
            background: linear-gradient(135deg, #2E7D32, #66BB6A);
            border-radius: 15px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);
        }

        .aficare-logo-icon img {
            width: 45px;
            height: 45px;
            border-radius: 8px;
        }

        .aficare-logo-text h1 {
            margin: 0;
            color: #2E7D32;
            font-size: 28px;
        }

        .aficare-logo-text h1 span {
            color: #1B5E20;
        }

        .aficare-logo-text p {
            margin: 0;
            color: #666;
            font-size: 12px;
            letter-spacing: 2px;
        }

        /* Install prompt */
        #pwa-install-btn {
            display: none;
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #2E7D32;
            color: white;
            border: none;
            padding: 15px 25px;
            border-radius: 30px;
            font-size: 14px;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(46, 125, 50, 0.4);
            z-index: 9999;
        }
    </style>

    <script>
        // PWA Install prompt
        let deferredPrompt;
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            const btn = document.getElementById('pwa-install-btn');
            if (btn) btn.style.display = 'block';
        });

        function installPWA() {
            if (deferredPrompt) {
                deferredPrompt.prompt();
                deferredPrompt.userChoice.then((result) => {
                    deferredPrompt = null;
                });
            }
        }
    </script>

    <button id="pwa-install-btn" onclick="installPWA()">
        Install App
    </button>
    """
    st.markdown(pwa_html, unsafe_allow_html=True)

def display_logo_header():
    """Display the AfiCare logo header"""
    logo_b64 = get_logo_base64()

    if logo_b64:
        logo_html = f"""
        <div class="aficare-logo-header">
            <div class="aficare-logo-icon">
                <img src="data:image/png;base64,{logo_b64}" alt="AfiCare Logo">
            </div>
            <div class="aficare-logo-text">
                <h1>Afi<span>Care</span> MediLink</h1>
                <p>PATIENT-OWNED HEALTHCARE RECORDS</p>
            </div>
        </div>
        """
    else:
        logo_html = """
        <div class="aficare-logo-header">
            <div class="aficare-logo-icon">
                <span style="color: white; font-size: 30px;">+</span>
            </div>
            <div class="aficare-logo-text">
                <h1>Afi<span>Care</span> MediLink</h1>
                <p>PATIENT-OWNED HEALTHCARE RECORDS</p>
            </div>
        </div>
        """

    st.markdown(logo_html, unsafe_allow_html=True)

# Initialize PWA support
inject_pwa_support()

# Initialize session state
if 'logged_in' not in st.session_state:
    st.session_state.logged_in = False
if 'user_role' not in st.session_state:
    st.session_state.user_role = None
if 'user_data' not in st.session_state:
    st.session_state.user_data = None
if 'medilink_id' not in st.session_state:
    st.session_state.medilink_id = None
if 'registered_users' not in st.session_state:
    st.session_state.registered_users = {}

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

.required-field {
    border-left: 3px solid #ff6b6b !important;
}

.validation-error {
    background: #ffebee;
    border: 1px solid #f44336;
    border-radius: 8px;
    padding: 1rem;
    margin: 1rem 0;
    color: #c62828;
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
    
    # Check registered users first (newly registered accounts)
    if username in st.session_state.registered_users:
        user = st.session_state.registered_users[username]
        if user["password"] == password and user["role"] == role:
            st.session_state.logged_in = True
            st.session_state.user_role = role
            st.session_state.user_data = user
            st.session_state.medilink_id = user.get("medilink_id")
            return True
    
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

    # Display logo header
    display_logo_header()

    # Tagline
    st.markdown("""
    <p style="text-align: center; color: #666; margin-top: -10px; margin-bottom: 20px;">
        Your Health Records, Your Control - <strong style="color: #2E7D32;">Completely FREE</strong>
    </p>
    """, unsafe_allow_html=True)
    
    # Demo alert
    st.markdown("""
    <div class="demo-alert">
        <h4>🎯 DEMO VERSION - Try It Now!</h4>
        <p>This is a working prototype of the MediLink system. Use the demo accounts below to explore different user roles.</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Login/Register tabs
    tab1, tab2, tab3 = st.tabs(["🔐 Login", "📝 Register Patient", "👨‍⚕️ Register Healthcare Provider"])
    
    with tab1:
        show_login_form()
    
    with tab2:
        show_patient_registration_form()
    
    with tab3:
        show_healthcare_provider_registration_form()

def show_login_form():
    """Login form for all user types"""
    
    st.subheader("Login to AfiCare MediLink")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        username = st.text_input(
            "Username or MediLink ID", 
            placeholder="ML-NBO-XXXX or +254712345678",
            help="Enter your MediLink ID, phone number, or demo username",
            key="login_username"
        )
        password = st.text_input("Password", type="password", key="login_password")
        
        # Role selection
        role = st.selectbox(
            "Login as:",
            ["patient", "doctor", "nurse", "admin"],
            format_func=lambda x: x.title(),
            key="login_role"
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
                st.error("❌ **Login Failed**")
                
                # Check if user exists but with wrong role
                user_found = False
                correct_role = None
                
                if username in st.session_state.registered_users:
                    user_found = True
                    correct_role = st.session_state.registered_users[username]["role"]
                
                if user_found and correct_role != role:
                    st.warning(f"⚠️ **Role Mismatch**: Account '{username}' is registered as **{correct_role.title()}**, but you're trying to login as **{role.title()}**")
                    st.info(f"💡 **Solution**: Change the 'Login as' dropdown to **{correct_role.title()}** and try again")
                else:
                    st.write("**Please check:**")
                    st.write("• Username/MediLink ID is correct")
                    st.write("• Password is correct") 
                    st.write("• Role matches your account type")
                    st.write("• Try the demo accounts shown on the right →")
                    
                    if not user_found:
                        st.info("💡 **Account not found**: If you haven't registered yet, use the registration tabs above")

def show_patient_registration_form():
    """Registration form for new patients"""
    
    st.subheader("Register as New Patient - FREE")
    st.info("👤 This creates a PATIENT account with a MediLink ID")
    
    col1, col2 = st.columns(2)
    
    with col1:
        full_name = st.text_input("Full Name *", help="Enter your complete legal name", key="patient_full_name")
        phone = st.text_input("Phone Number *", placeholder="+254712345678", help="Include country code if international", key="patient_phone")
        email = st.text_input("Email Address", placeholder="your.email@example.com", help="Optional but recommended for account recovery", key="patient_email")
        
    with col2:
        age = st.number_input("Age *", min_value=0, max_value=120, value=25, help="Your age in years", key="patient_age")
        gender = st.selectbox("Gender *", ["Male", "Female", "Other"], help="Select your gender", key="patient_gender")
        location = st.selectbox("Location/City", [
            "Nairobi", "Mombasa", "Kisumu", "Nakuru", "Eldoret", "Other"
        ], help="Your primary location - affects your MediLink ID", key="patient_location")
    
    # Medical information
    st.subheader("Medical Information (Optional)")
    medical_history = st.text_area("Known medical conditions", placeholder="e.g., Diabetes, Hypertension, Asthma", help="List any ongoing medical conditions", key="patient_medical_history")
    allergies = st.text_area("Known allergies", placeholder="e.g., Penicillin, Sulfa drugs, Peanuts", help="List any known allergies - this is important for emergency care", key="patient_allergies")
    
    # Emergency contact
    st.subheader("Emergency Contact (Optional but Recommended)")
    emergency_name = st.text_input("Emergency contact name", placeholder="e.g., Jane Doe (Wife)", help="Person to contact in case of emergency", key="patient_emergency_name")
    emergency_phone = st.text_input("Emergency contact phone", placeholder="+254712345679", help="Phone number of emergency contact", key="patient_emergency_phone")
    
    # Create password
    st.subheader("Create Account")
    password = st.text_input("Create Password *", type="password", help="Minimum 6 characters", key="patient_password")
    confirm_password = st.text_input("Confirm Password *", type="password", help="Re-enter the same password", key="patient_confirm_password")
    
    # Terms and conditions
    agree_terms = st.checkbox("I agree to the Terms of Service and Privacy Policy *", help="Required to create account", key="patient_agree_terms")
    
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
            
            # Create user account data
            user_data = {
                "password": password,
                "role": "patient",
                "full_name": full_name,
                "medilink_id": medilink_id,
                "phone": phone,
                "email": email or "",
                "age": age,
                "gender": gender,
                "location": location,
                "medical_history": medical_history or "",
                "allergies": allergies or "",
                "emergency_name": emergency_name or "",
                "emergency_phone": emergency_phone or "",
                "registration_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
            # Save user with both MediLink ID and phone as login options
            st.session_state.registered_users[medilink_id] = user_data
            st.session_state.registered_users[phone] = user_data  # Allow login with phone too
            
            st.balloons()
            st.markdown(f"""
            <div class="medilink-id">
                <h3>🎉 Registration Successful!</h3>
                <p><strong>Your MediLink ID:</strong> {medilink_id}</p>
                <p><strong>Full Name:</strong> {full_name}</p>
                <p><strong>Phone:</strong> {phone}</p>
                <p><strong>Location:</strong> {location}</p>
                <br>
                <h4>🔐 Login Information:</h4>
                <p><strong>Username Options:</strong></p>
                <ul>
                    <li>MediLink ID: <code>{medilink_id}</code></li>
                    <li>Phone Number: <code>{phone}</code></li>
                </ul>
                <p><strong>Password:</strong> [The password you just created]</p>
                <p><strong>Role:</strong> Patient</p>
                <br>
                <p><em>💾 Your account has been saved! You can now login using either your MediLink ID or phone number.</em></p>
            </div>
            """, unsafe_allow_html=True)
            
            st.success("✅ Account created successfully! Please go to the Login tab to sign in.")
            
            # Show a helpful reminder
            st.info(f"""
            **🔑 Remember your login details:**
            - **Username:** `{medilink_id}` or `{phone}`
            - **Password:** [Your chosen password]
            - **Role:** Patient
            """)
            
            # Optional: Auto-switch to login tab (user experience improvement)
            st.write("**👆 Click the 'Login' tab above to sign in with your new account!**")

def show_healthcare_provider_registration_form():
    """Registration form for healthcare providers"""
    
    st.subheader("Register as Healthcare Provider")
    st.info("👨‍⚕️ This creates a DOCTOR, NURSE, or ADMIN account")
    
    col1, col2 = st.columns(2)
    
    with col1:
        full_name = st.text_input("Full Name *", help="Enter your complete professional name", key="provider_full_name")
        username = st.text_input("Username *", help="Choose a unique username for login", key="provider_username")
        role = st.selectbox("Role *", ["doctor", "nurse", "admin"], 
                           format_func=lambda x: x.title(),
                           help="Select your professional role", key="provider_role")
        
    with col2:
        phone = st.text_input("Phone Number *", placeholder="+254712345678", key="provider_phone")
        email = st.text_input("Email Address *", placeholder="your.email@hospital.com", key="provider_email")
        department = st.text_input("Department", placeholder="e.g., Internal Medicine, Emergency", key="provider_department")
    
    # Professional information
    st.subheader("Professional Information")
    col1, col2 = st.columns(2)
    
    with col1:
        license_number = st.text_input("License Number", help="Professional license/registration number", key="provider_license")
        hospital_id = st.text_input("Hospital ID", value="HOSP001", help="Your hospital identifier", key="provider_hospital_id")
    
    with col2:
        specialization = st.text_input("Specialization", help="Medical specialization or area of expertise", key="provider_specialization")
        years_experience = st.number_input("Years of Experience", min_value=0, max_value=50, value=5, key="provider_experience")
    
    # Create password
    st.subheader("Create Account")
    password = st.text_input("Create Password *", type="password", help="Minimum 6 characters", key="provider_password")
    confirm_password = st.text_input("Confirm Password *", type="password", help="Re-enter the same password", key="provider_confirm_password")
    
    # Terms and conditions
    agree_terms = st.checkbox("I agree to the Terms of Service and Professional Code of Conduct *", key="provider_agree_terms")
    
    if st.button("👨‍⚕️ Register Healthcare Provider Account", type="primary"):
        # Detailed validation
        errors = []
        
        if not full_name or not full_name.strip():
            errors.append("❌ **Full Name** is required")
        
        if not username or not username.strip():
            errors.append("❌ **Username** is required")
        elif len(username.strip()) < 3:
            errors.append("❌ **Username** must be at least 3 characters")
        
        if not phone or not phone.strip():
            errors.append("❌ **Phone Number** is required")
        
        if not email or not email.strip():
            errors.append("❌ **Email Address** is required")
        elif "@" not in email:
            errors.append("❌ **Email Address** must be valid")
        
        if not role:
            errors.append("❌ **Role** must be selected")
        
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
        
        # Check if username already exists
        if username in st.session_state.registered_users:
            errors.append("❌ **Username already exists** - please choose a different username")
        
        # Show specific errors or proceed with registration
        if errors:
            st.error("**Please fix the following issues:**")
            for error in errors:
                st.write(error)
        else:
            # All validation passed - register the healthcare provider
            provider_id = f"{role.upper()}-{secrets.token_hex(3).upper()}"
            
            # Create user account data
            user_data = {
                "password": password,
                "role": role,
                "full_name": full_name,
                "username": username,
                "phone": phone,
                "email": email,
                "department": department or "General",
                "hospital_id": hospital_id or "HOSP001",
                "license_number": license_number or "",
                "specialization": specialization or "",
                "years_experience": years_experience,
                "provider_id": provider_id,
                "registration_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
            # Save user with username as login
            st.session_state.registered_users[username] = user_data
            
            st.balloons()
            st.markdown(f"""
            <div class="medilink-id">
                <h3>🎉 Healthcare Provider Registration Successful!</h3>
                <p><strong>Provider ID:</strong> {provider_id}</p>
                <p><strong>Full Name:</strong> {full_name}</p>
                <p><strong>Role:</strong> {role.title()}</p>
                <p><strong>Department:</strong> {department or "General"}</p>
                <p><strong>Hospital:</strong> {hospital_id or "HOSP001"}</p>
                <br>
                <h4>🔐 Login Information:</h4>
                <p><strong>Username:</strong> <code>{username}</code></p>
                <p><strong>Password:</strong> [The password you just created]</p>
                <p><strong>Role:</strong> {role.title()}</p>
                <br>
                <p><em>💾 Your healthcare provider account has been created! You can now login to access the medical system.</em></p>
            </div>
            """, unsafe_allow_html=True)
            
            st.success("✅ Healthcare provider account created successfully! Please go to the Login tab to sign in.")
            
            # Show a helpful reminder
            st.info(f"""
            **🔑 Remember your login details:**
            - **Username:** `{username}`
            - **Password:** [Your chosen password]
            - **Role:** {role.title()}
            """)
            
            st.write("**👆 Click the 'Login' tab above to sign in with your new account!**")

def show_dashboard():
    """Show role-based dashboard"""

    role = st.session_state.user_role
    user_data = st.session_state.user_data

    # Display logo header with user info
    logo_b64 = get_logo_base64()
    role_colors = {
        "patient": "#4CAF50",
        "doctor": "#2196F3",
        "nurse": "#9C27B0",
        "admin": "#FF9800"
    }
    role_color = role_colors.get(role, "#4CAF50")

    if logo_b64:
        header_html = f"""
        <div style="display: flex; align-items: center; justify-content: space-between;
                    padding: 15px 20px; background: linear-gradient(135deg, #E8F5E9 0%, #C8E6C9 100%);
                    border-radius: 15px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(46, 125, 50, 0.1);">
            <div style="display: flex; align-items: center; gap: 15px;">
                <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #2E7D32, #66BB6A);
                            border-radius: 12px; display: flex; align-items: center; justify-content: center;
                            box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);">
                    <img src="data:image/png;base64,{logo_b64}" style="width: 35px; height: 35px; border-radius: 6px;" alt="Logo">
                </div>
                <div>
                    <h1 style="margin: 0; color: #2E7D32; font-size: 24px;">Afi<span style="color: #1B5E20;">Care</span></h1>
                    <p style="margin: 0; color: #666; font-size: 11px; letter-spacing: 1px;">MEDILINK</p>
                </div>
            </div>
            <div style="text-align: right;">
                <p style="margin: 0; font-weight: bold; color: #333;">{user_data['full_name']}</p>
                <span style="background: {role_color}; color: white; padding: 4px 12px;
                             border-radius: 12px; font-size: 12px; font-weight: bold;">{role.title()}</span>
            </div>
        </div>
        """
    else:
        header_html = f"""
        <div style="display: flex; align-items: center; justify-content: space-between;
                    padding: 15px 20px; background: linear-gradient(135deg, #E8F5E9 0%, #C8E6C9 100%);
                    border-radius: 15px; margin-bottom: 20px;">
            <div>
                <h1 style="margin: 0; color: #2E7D32; font-size: 24px;">AfiCare MediLink</h1>
            </div>
            <div style="text-align: right;">
                <p style="margin: 0; font-weight: bold;">{user_data['full_name']}</p>
                <span style="background: {role_color}; color: white; padding: 4px 12px;
                             border-radius: 12px; font-size: 12px;">{role.title()}</span>
            </div>
        </div>
        """

    st.markdown(header_html, unsafe_allow_html=True)

    # Sidebar with logo and logout
    with st.sidebar:
        # Mini logo in sidebar
        if logo_b64:
            st.markdown(f"""
            <div style="text-align: center; padding: 10px; margin-bottom: 15px;">
                <img src="data:image/png;base64,{logo_b64}" style="width: 60px; height: 60px; border-radius: 12px;" alt="Logo">
                <p style="margin: 5px 0 0 0; color: #2E7D32; font-weight: bold; font-size: 14px;">AfiCare</p>
            </div>
            """, unsafe_allow_html=True)

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

    if st.button("Save Settings", type="primary"):
        st.success("Settings saved successfully!")

    # PWA Install Instructions
    st.markdown("---")
    show_install_instructions()

def show_install_instructions():
    """Show PWA installation instructions"""
    with st.expander("Install AfiCare App on Your Device"):
        st.markdown("""
        ### Install on Android
        1. Open this page in **Chrome**
        2. Tap the menu (**...**) in the top right
        3. Tap **"Add to Home screen"**
        4. Tap **"Add"**

        ### Install on iPhone/iPad
        1. Open this page in **Safari**
        2. Tap the **Share button** (square with arrow)
        3. Scroll down and tap **"Add to Home Screen"**
        4. Tap **"Add"**

        ### Install on Desktop (Chrome/Edge)
        1. Look for the **install icon** in the address bar
        2. Click **"Install"**

        ---
        **Benefits of installing:**
        - Quick launch from home screen
        - Full-screen experience
        - Offline access to cached data
        - Native app feel
        """)

def show_healthcare_provider_dashboard():
    """Healthcare provider interface"""
    
    role = st.session_state.user_role
    
    # Navigation tabs
    tab1, tab2, tab3, tab4 = st.tabs([
        "🔍 Access Patient", "👥 My Patients", "📋 New Consultation", "🤖 AI Agent Demo"
    ])
    
    with tab1:
        show_provider_patient_access()
    
    with tab2:
        show_provider_patient_list()
    
    with tab3:
        show_provider_consultation()
    
    with tab4:
        show_ai_agent_demo()

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
            nausea = st.checkbox("Nausea")
            vomiting = st.checkbox("Vomiting")
        
        with col2:
            chest_pain = st.checkbox("Chest pain")
            difficulty_breathing = st.checkbox("Difficulty breathing")
            fatigue = st.checkbox("Fatigue")
            dizziness = st.checkbox("Dizziness")
            muscle_aches = st.checkbox("Muscle aches")
        
        st.write("**Vital Signs:**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            temperature = st.number_input("Temperature (°C)", value=37.0)
            systolic_bp = st.number_input("Systolic BP", value=120)
        
        with col2:
            diastolic_bp = st.number_input("Diastolic BP", value=80)
            pulse = st.number_input("Pulse (bpm)", value=80)
        
        with col3:
            resp_rate = st.number_input("Respiratory Rate (/min)", value=16)
            oxygen_sat = st.number_input("Oxygen Saturation (%)", value=98)
        
        if st.button("🤖 Analyze with AI", type="primary"):
            # Get medical AI
            medical_ai = get_medical_ai()
            
            # Prepare symptoms list from checkboxes
            symptoms_list = []
            if fever: symptoms_list.append("fever")
            if cough: symptoms_list.append("cough")
            if headache: symptoms_list.append("headache")
            if nausea: symptoms_list.append("nausea")
            if vomiting: symptoms_list.append("vomiting")
            if chest_pain: symptoms_list.append("chest pain")
            if difficulty_breathing: symptoms_list.append("difficulty breathing")
            if fatigue: symptoms_list.append("fatigue")
            if dizziness: symptoms_list.append("dizziness")
            if muscle_aches: symptoms_list.append("muscle aches")
            
            if not symptoms_list:
                st.error("Please select at least one symptom for analysis")
            else:
                # Create patient data object
                patient_data = PatientData(
                    patient_id="ML-NBO-DEMO1",
                    age=35,  # Default for demo
                    gender="male",
                    symptoms=symptoms_list,
                    vital_signs={
                        "temperature": temperature,
                        "systolic_bp": systolic_bp,
                        "diastolic_bp": diastolic_bp,
                        "pulse": pulse,
                        "respiratory_rate": resp_rate,
                        "oxygen_saturation": oxygen_sat
                    },
                    medical_history=[],
                    current_medications=[],
                    chief_complaint=chief_complaint or "Patient consultation"
                )
                
                # Run AI analysis
                with st.spinner("🤖 AI is analyzing the case..."):
                    try:
                        # Check if we're using the real AI Agent
                        if hasattr(medical_ai, 'agent'):
                            st.info("🤖 **Powered by Real AfiCare AI Agent** with advanced medical reasoning, rule engine, and triage assessment!")
                            result = medical_ai.conduct_consultation(patient_data)
                        else:
                            st.info("🔧 **Using Simplified AI** - The full AfiCare Agent couldn't be loaded")
                            result = medical_ai.conduct_consultation(patient_data)
                        
                        # Display results
                        st.success("🎯 AI Analysis Complete!")
                        
                        # Show AI agent info
                        if hasattr(medical_ai, 'agent'):
                            col1, col2, col3 = st.columns(3)
                            with col1:
                                st.metric("🔌 Plugins Loaded", len(medical_ai.agent.plugin_manager.plugins))
                            with col2:
                                st.metric("🧠 Rule Engine", "Active" if hasattr(medical_ai.agent, 'rule_engine') else "Inactive")
                            with col3:
                                st.metric("🚨 Triage Engine", "Active" if hasattr(medical_ai.agent, 'triage_engine') else "Inactive")
                        
                        # Triage level with color coding
                        triage_colors = {
                            "EMERGENCY": "🚨",
                            "emergency": "🚨",
                            "URGENT": "⚠️", 
                            "urgent": "⚠️",
                            "LESS_URGENT": "⏰",
                            "less_urgent": "⏰",
                            "NON_URGENT": "✅",
                            "non_urgent": "✅"
                        }
                        
                        triage_emoji = triage_colors.get(result.triage_level, "ℹ️")
                        st.write(f"**{triage_emoji} Triage Level:** {result.triage_level.upper()}")
                        st.write(f"**🎯 Overall Confidence:** {result.confidence_score:.1%}")
                        
                        # Suspected conditions
                        if result.suspected_conditions:
                            st.write("**🔍 Suspected Conditions:**")
                            for i, condition in enumerate(result.suspected_conditions[:3], 1):
                                confidence = condition["confidence"]
                                name = condition["display_name"]
                                st.write(f"{i}. **{name}** - {confidence:.1%} confidence")
                                
                                # Show matching symptoms
                                if condition.get("matching_symptoms"):
                                    symptoms_str = ", ".join(condition["matching_symptoms"])
                                    st.write(f"   *Matching symptoms: {symptoms_str}*")
                        
                        # Recommendations
                        if result.recommendations:
                            st.write("**💊 Treatment Recommendations:**")
                            for i, rec in enumerate(result.recommendations[:5], 1):
                                st.write(f"{i}. {rec}")
                        
                        # Referral and follow-up
                        col1, col2 = st.columns(2)
                        with col1:
                            if result.referral_needed:
                                st.warning("⚠️ **Referral recommended**")
                            else:
                                st.success("✅ **Can be managed locally**")
                        
                        with col2:
                            if result.follow_up_required:
                                st.info("📅 **Follow-up required**")
                            else:
                                st.info("ℹ️ **Routine follow-up as needed**")
                        
                        if st.button("💾 Save Consultation"):
                            st.success("✅ Consultation saved to patient's MediLink record!")
                            st.info("📋 This consultation has been added to the patient's medical history")
                            
                    except Exception as e:
                        st.error(f"❌ AI Analysis failed: {str(e)}")
                        st.info("💡 Please check that all required fields are filled correctly")

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

def show_ai_agent_demo():
    """Demonstrate the AfiCare AI Agent capabilities"""
    
    st.subheader("🤖 AfiCare AI Agent - Live Demo")
    
    # Get the medical AI
    medical_ai = get_medical_ai()
    
    # Show AI status
    if hasattr(medical_ai, 'agent'):
        st.success("✅ **Real AfiCare AI Agent Active**")
        
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("🔌 Plugins", len(medical_ai.agent.plugin_manager.plugins))
        with col2:
            st.metric("🧠 Rule Engine", "Active")
        with col3:
            st.metric("🚨 Triage Engine", "Active")
    else:
        st.info("🔧 **Simplified AI Active** - Full agent couldn't be loaded")
    
    st.markdown("---")
    
    # Pre-built test cases
    st.subheader("🧪 Test Cases")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("🦠 Test Malaria Case", type="primary"):
            st.session_state.demo_case = "malaria"
    
    with col2:
        if st.button("🫁 Test Pneumonia Case", type="primary"):
            st.session_state.demo_case = "pneumonia"
    
    with col3:
        if st.button("🩺 Test Hypertension Case", type="primary"):
            st.session_state.demo_case = "hypertension"
    
    # Show selected test case
    if 'demo_case' in st.session_state:
        case = st.session_state.demo_case
        
        if case == "malaria":
            st.markdown("### 🦠 Malaria Test Case")
            st.info("**Patient:** John Doe (35M) - High fever and body aches for 3 days")
            
            patient_data = PatientData(
                patient_id="DEMO-MALARIA",
                age=35,
                gender="Male",
                symptoms=["fever", "headache", "muscle aches", "chills", "sweating"],
                vital_signs={
                    "temperature": 39.2,
                    "pulse": 98,
                    "systolic_bp": 130,
                    "diastolic_bp": 85,
                    "respiratory_rate": 20
                },
                medical_history=["None"],
                current_medications=["None"],
                chief_complaint="High fever and body aches for 3 days"
            )
            
        elif case == "pneumonia":
            st.markdown("### 🫁 Pneumonia Test Case")
            st.info("**Patient:** Sarah Ali (45F) - Persistent cough with fever and breathing difficulty")
            
            patient_data = PatientData(
                patient_id="DEMO-PNEUMONIA",
                age=45,
                gender="Female",
                symptoms=["cough", "fever", "difficulty breathing", "chest pain"],
                vital_signs={
                    "temperature": 38.8,
                    "pulse": 105,
                    "systolic_bp": 125,
                    "diastolic_bp": 80,
                    "respiratory_rate": 26
                },
                medical_history=["Asthma"],
                current_medications=["Salbutamol inhaler"],
                chief_complaint="Persistent cough with fever and breathing difficulty"
            )
            
        elif case == "hypertension":
            st.markdown("### 🩺 Hypertension Test Case")
            st.info("**Patient:** James Ruto (55M) - Persistent headaches and dizziness")
            
            patient_data = PatientData(
                patient_id="DEMO-HTN",
                age=55,
                gender="Male",
                symptoms=["headache", "dizziness", "blurred vision"],
                vital_signs={
                    "temperature": 37.1,
                    "pulse": 82,
                    "systolic_bp": 165,
                    "diastolic_bp": 95,
                    "respiratory_rate": 16
                },
                medical_history=["Family history of hypertension"],
                current_medications=["None"],
                chief_complaint="Persistent headaches and dizziness"
            )
        
        # Run AI analysis
        if st.button("🤖 Run AI Analysis", type="primary", key=f"analyze_{case}"):
            with st.spinner("🧠 AfiCare AI Agent is analyzing the case..."):
                try:
                    result = medical_ai.conduct_consultation(patient_data)
                    
                    # Display results
                    st.success("🎯 AI Analysis Complete!")
                    
                    # Metrics
                    col1, col2, col3, col4 = st.columns(4)
                    
                    with col1:
                        triage_colors = {
                            "emergency": "🚨", "urgent": "⚠️", 
                            "less_urgent": "⏰", "non_urgent": "✅"
                        }
                        triage_emoji = triage_colors.get(result.triage_level.lower(), "ℹ️")
                        st.metric("Triage Level", f"{triage_emoji} {result.triage_level.upper()}")
                    
                    with col2:
                        st.metric("Confidence", f"{result.confidence_score:.1%}")
                    
                    with col3:
                        st.metric("Referral", "Yes" if result.referral_needed else "No")
                    
                    with col4:
                        st.metric("Follow-up", "Yes" if result.follow_up_required else "No")
                    
                    # Suspected conditions
                    st.subheader("🔍 AI Diagnosis")
                    for i, condition in enumerate(result.suspected_conditions[:3]):
                        name = condition.get('display_name', condition.get('name', 'Unknown'))
                        confidence = condition.get('confidence', 0)
                        category = condition.get('category', 'Medical Condition')
                        
                        st.write(f"**{i+1}. {name}** ({confidence:.1%} confidence)")
                        st.caption(f"Category: {category}")
                    
                    # AI Recommendations
                    st.subheader("💊 AI Treatment Recommendations")
                    for i, rec in enumerate(result.recommendations[:6]):
                        st.write(f"{i+1}. {rec}")
                    
                    # Technical details
                    with st.expander("🔧 Technical Details"):
                        st.json({
                            "patient_id": result.patient_id,
                            "timestamp": result.timestamp.isoformat(),
                            "ai_engine": "AfiCare AI Agent" if hasattr(medical_ai, 'agent') else "Simplified AI",
                            "plugins_used": len(medical_ai.agent.plugin_manager.plugins) if hasattr(medical_ai, 'agent') else 0,
                            "rule_engine_active": hasattr(medical_ai, 'agent'),
                            "triage_engine_active": hasattr(medical_ai, 'agent')
                        })
                    
                except Exception as e:
                    st.error(f"❌ AI Analysis Failed: {str(e)}")
                    st.write("**Debug Info:**")
                    st.write(f"AI Type: {'Real Agent' if hasattr(medical_ai, 'agent') else 'Simplified'}")

        show_dashboard()

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        show_dashboard()

if __name__ == "__main__":
    main()