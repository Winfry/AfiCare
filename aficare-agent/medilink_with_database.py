"""
MediLink with Database - Enhanced version of medilink_simple.py with SQLite storage
Single app for patients, doctors, and admins with role-based interface
Includes rule-based medical AI for consultations + persistent database storage
"""

import streamlit as st
from datetime import datetime, timedelta
import secrets
import sqlite3
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass

# Import the medical AI components from the simple version
import sys
sys.path.append(str(Path(__file__).parent))

# Copy the medical AI classes from medilink_simple.py
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
                "fever": 0.9, "chills": 0.8, "headache": 0.7, "muscle_aches": 0.6,
                "nausea": 0.5, "fatigue": 0.6, "vomiting": 0.5, "sweating": 0.4
            },
            "treatment": [
                "Artemether-Lumefantrine based on weight", "Paracetamol for fever and pain",
                "Oral rehydration therapy", "Rest and adequate nutrition", "Follow-up in 3 days"
            ],
            "danger_signs": ["severe_headache", "confusion", "difficulty_breathing"]
        }
        
        # Pneumonia
        conditions["pneumonia"] = {
            "name": "Pneumonia",
            "symptoms": {
                "cough": 0.9, "fever": 0.8, "difficulty_breathing": 0.9, "chest_pain": 0.7,
                "fatigue": 0.6, "rapid_breathing": 0.8, "chills": 0.6
            },
            "treatment": [
                "Amoxicillin 15mg/kg twice daily for 5 days (children)",
                "Amoxicillin 500mg three times daily for 5 days (adults)",
                "Oxygen therapy if SpO2 < 90%", "Adequate fluid intake", "Follow-up in 2-3 days"
            ],
            "danger_signs": ["difficulty_breathing", "chest_pain", "high_fever"]
        }
        
        # Hypertension
        conditions["hypertension"] = {
            "name": "Hypertension",
            "symptoms": {
                "headache": 0.4, "dizziness": 0.5, "blurred_vision": 0.6, "chest_pain": 0.3, "fatigue": 0.3
            },
            "treatment": [
                "Lifestyle modifications (diet, exercise)", "Regular blood pressure monitoring",
                "Antihypertensive medication if indicated", "Reduce salt intake", "Regular follow-up"
            ],
            "danger_signs": ["severe_headache", "chest_pain", "difficulty_breathing"]
        }
        
        # Common Cold/Flu
        conditions["common_cold"] = {
            "name": "Common Cold/Flu",
            "symptoms": {
                "cough": 0.7, "runny_nose": 0.8, "sore_throat": 0.7, "headache": 0.5,
                "fatigue": 0.6, "muscle_aches": 0.4, "fever": 0.4
            },
            "treatment": [
                "Rest and adequate sleep", "Increase fluid intake", "Paracetamol for fever and pain",
                "Warm salt water gargling", "Return if symptoms worsen"
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

# Database Manager
class DatabaseManager:
    """Simple database manager for persistent storage"""
    
    def __init__(self, db_path: str = "aficare_medilink.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize database tables"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Users table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS users (
                        username TEXT PRIMARY KEY,
                        password_hash TEXT NOT NULL,
                        role TEXT NOT NULL,
                        full_name TEXT NOT NULL,
                        medilink_id TEXT UNIQUE,
                        phone TEXT,
                        email TEXT,
                        age INTEGER,
                        gender TEXT,
                        location TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Consultations table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS consultations (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        doctor_username TEXT NOT NULL,
                        consultation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        chief_complaint TEXT,
                        symptoms TEXT,
                        triage_level TEXT,
                        suspected_conditions TEXT,
                        recommendations TEXT,
                        confidence_score REAL
                    )
                ''')
                
                conn.commit()
        except Exception as e:
            st.error(f"Database initialization failed: {str(e)}")
    
    def hash_password(self, password: str) -> str:
        """Hash password"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def create_user(self, user_data: Dict[str, Any]) -> Tuple[bool, str]:
        """Create new user"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if username exists
                cursor.execute('SELECT username FROM users WHERE username = ?', (user_data['username'],))
                if cursor.fetchone():
                    return False, "Username already exists"
                
                # Hash password and insert
                password_hash = self.hash_password(user_data['password'])
                
                cursor.execute('''
                    INSERT INTO users (username, password_hash, role, full_name, medilink_id, phone, email, age, gender, location)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_data['username'], password_hash, user_data['role'], user_data['full_name'],
                    user_data.get('medilink_id'), user_data.get('phone'), user_data.get('email'),
                    user_data.get('age'), user_data.get('gender'), user_data.get('location')
                ))
                
                conn.commit()
                return True, "User created successfully"
        except Exception as e:
            return False, f"Database error: {str(e)}"
    
    def authenticate_user(self, username: str, password: str, role: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Authenticate user"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('SELECT * FROM users WHERE username = ? AND role = ?', (username, role))
                user_row = cursor.fetchone()
                
                if not user_row:
                    return False, None
                
                columns = [desc[0] for desc in cursor.description]
                user_data = dict(zip(columns, user_row))
                
                if self.hash_password(password) == user_data['password_hash']:
                    del user_data['password_hash']
                    return True, user_data
                else:
                    return False, None
        except Exception as e:
            return False, None
    
    def save_consultation(self, consultation_data: Dict[str, Any]) -> bool:
        """Save consultation to database"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO consultations (patient_medilink_id, doctor_username, chief_complaint, 
                                             symptoms, triage_level, suspected_conditions, 
                                             recommendations, confidence_score)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    consultation_data['patient_medilink_id'],
                    consultation_data['doctor_username'],
                    consultation_data.get('chief_complaint'),
                    json.dumps(consultation_data.get('symptoms', [])),
                    consultation_data.get('triage_level'),
                    json.dumps(consultation_data.get('suspected_conditions', [])),
                    json.dumps(consultation_data.get('recommendations', [])),
                    consultation_data.get('confidence_score', 0.0)
                ))
                
                conn.commit()
                return True
        except Exception as e:
            st.error(f"Failed to save consultation: {str(e)}")
            return False
    
    def get_patient_consultations(self, medilink_id: str) -> List[Dict[str, Any]]:
        """Get patient consultations"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM consultations 
                    WHERE patient_medilink_id = ? 
                    ORDER BY consultation_date DESC
                ''', (medilink_id,))
                
                rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                consultations = []
                for row in rows:
                    consultation = dict(zip(columns, row))
                    # Parse JSON fields
                    try:
                        if consultation.get('symptoms'):
                            consultation['symptoms'] = json.loads(consultation['symptoms'])
                        if consultation.get('suspected_conditions'):
                            consultation['suspected_conditions'] = json.loads(consultation['suspected_conditions'])
                        if consultation.get('recommendations'):
                            consultation['recommendations'] = json.loads(consultation['recommendations'])
                    except:
                        pass
                    consultations.append(consultation)
                
                return consultations
        except Exception as e:
            return []
    
    def get_stats(self) -> Dict[str, Any]:
        """Get database statistics"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('SELECT role, COUNT(*) FROM users GROUP BY role')
                user_counts = dict(cursor.fetchall())
                
                cursor.execute('SELECT COUNT(*) FROM consultations')
                total_consultations = cursor.fetchone()[0]
                
                return {
                    'user_counts': user_counts,
                    'total_consultations': total_consultations
                }
        except:
            return {}

# Initialize global instances
@st.cache_resource
def get_database():
    """Get database instance"""
    return DatabaseManager()

@st.cache_resource
def get_medical_ai():
    """Get medical AI instance"""
    return MedicalAI()

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink (Database Enhanced)",
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

# Get instances
db = get_database()
medical_ai = get_medical_ai()

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
    location_codes = {"nairobi": "NBO", "mombasa": "MSA", "kisumu": "KSM", "nakuru": "NKR", "eldoret": "ELD"}
    location_code = location_codes.get(location.lower(), "KEN")
    unique_id = secrets.token_hex(4).upper()
    return f"ML-{location_code}-{unique_id}"

def show_login_page():
    """Display login/registration page"""
    
    # Header
    st.markdown("""
    <div class="main-header patient-theme">
        <h1>🏥 AfiCare MediLink (Database Enhanced)</h1>
        <p>Your Health Records, Your Control - Now with Persistent Database Storage!</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Database info
    st.markdown("""
    <div class="database-info">
        <h4>💾 Database Enhanced Features:</h4>
        <p>✅ User accounts saved permanently to SQLite database<br>
        ✅ Consultations persist between app sessions<br>
        ✅ Medical history builds over time<br>
        ✅ Multi-user support with role-based access<br>
        ✅ All data survives app restarts</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Login/Register tabs
    tab1, tab2 = st.tabs(["🔐 Login", "📝 Register"])
    
    with tab1:
        show_login_form()
    
    with tab2:
        show_registration_form()

def show_login_form():
    """Login form"""
    st.subheader("Login to AfiCare MediLink")
    
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
                
                st.success(f"✅ Welcome back, {user_data['full_name']}!")
                st.rerun()
            else:
                st.error("❌ Login failed - Please check your credentials")

def show_registration_form():
    """Registration form"""
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
                st.markdown(f"""
                <div class="success-message">
                    <h3>🎉 Registration Successful!</h3>
                    <p><strong>Username:</strong> {username}{medilink_display}</p>
                    <p><strong>Role:</strong> {role.title()}</p>
                    <p><em>💾 Account saved to database permanently!</em></p>
                    <p><strong>👆 Click 'Login' tab to sign in!</strong></p>
                </div>
                """, unsafe_allow_html=True)
            else:
                st.error(f"❌ Registration failed: {message}")

def show_dashboard():
    """Role-based dashboard"""
    
    role = st.session_state.user_role
    user_data = st.session_state.user_data
    
    # Header
    theme_class = f"{role}-theme"
    st.markdown(f"""
    <div class="main-header {theme_class}">
        <h1>🏥 AfiCare MediLink (Database Enhanced)</h1>
        <p>{user_data['full_name']} - {role.title()}</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Sidebar
    with st.sidebar:
        st.write(f"**Logged in as:** {role.title()}")
        if role == "patient" and st.session_state.medilink_id:
            st.write(f"**MediLink ID:** {st.session_state.medilink_id}")
        
        # Database stats
        stats = db.get_stats()
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
    """Patient interface"""
    
    medilink_id = st.session_state.medilink_id
    
    st.info(f"📋 Your MediLink ID: **{medilink_id}** - All records stored in database permanently")
    
    # Get consultations from database
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
    
    # Show consultations
    if consultations:
        st.subheader("📈 Your Medical History (From Database)")
        for consultation in consultations[:5]:
            with st.expander(f"{consultation['consultation_date'][:16]} - {consultation['triage_level']}"):
                st.write(f"**Doctor:** {consultation['doctor_username']}")
                st.write(f"**Chief Complaint:** {consultation['chief_complaint'] or 'Not specified'}")
                st.write(f"**Triage Level:** {consultation['triage_level']}")
                if consultation['suspected_conditions']:
                    conditions = consultation['suspected_conditions']
                    if conditions:
                        st.write(f"**Top Diagnosis:** {conditions[0].get('display_name', 'Unknown')} ({conditions[0].get('confidence', 0):.1%})")
    else:
        st.info("No consultations found. Visit a healthcare provider to start building your medical history!")

def show_healthcare_provider_dashboard():
    """Healthcare provider interface"""
    
    st.subheader("👨‍⚕️ Healthcare Provider Dashboard")
    
    # Simple patient lookup
    medilink_id = st.text_input("Enter Patient MediLink ID", placeholder="ML-NBO-XXXX")
    
    if medilink_id and st.button("🔍 Load Patient"):
        # For demo, we'll show consultation form
        st.success(f"✅ Patient loaded: {medilink_id}")
        
        # Consultation form
        st.subheader("📋 New Consultation")
        
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
                # Create patient data
                patient_data = PatientData(
                    patient_id=medilink_id,
                    age=30,  # Default for demo
                    gender="unknown",
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
                        st.info("📋 This consultation is now part of the patient's permanent MediLink record")
                    else:
                        st.error("❌ Failed to save consultation")

def show_admin_dashboard():
    """Admin interface"""
    
    st.subheader("⚙️ System Administration")
    
    stats = db.get_stats()
    
    st.write("**📊 Database Statistics:**")
    col1, col2 = st.columns(2)
    
    with col1:
        if stats.get('user_counts'):
            for role, count in stats['user_counts'].items():
                st.metric(f"{role.title()}s", count)
    
    with col2:
        st.metric("Total Consultations", stats.get('total_consultations', 0))
    
    st.info("💾 **Database Enhanced Version Active** - All data persists permanently in SQLite database")

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        show_dashboard()

if __name__ == "__main__":
    main()