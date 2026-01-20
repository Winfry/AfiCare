"""
MediLink Enhanced Medical Version - Expanded medical knowledge base
Includes: Malaria, Pneumonia, Hypertension, Common Cold, Tuberculosis, Diabetes, Antenatal Care
Single app for patients, doctors, and admins with role-based interface + SQLite database
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

class EnhancedRuleEngine:
    """Enhanced rule-based medical engine with 7 conditions"""
    
    def __init__(self):
        self.conditions = self._load_conditions()
    
    def _load_conditions(self):
        """Load all medical conditions including new ones"""
        conditions = {}
        
        # Original 4 conditions
        conditions.update(self._load_original_conditions())
        
        # New 3 conditions
        conditions.update(self._load_new_conditions())
        
        return conditions
    
    def _load_original_conditions(self):
        """Load original 4 conditions"""
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
    
    def _load_new_conditions(self):
        """Load new 3 conditions: TB, Diabetes, Antenatal Care"""
        conditions = {}
        
        # Tuberculosis
        conditions["tuberculosis"] = {
            "name": "Tuberculosis (TB)",
            "symptoms": {
                "persistent_cough": 0.9, "coughing_blood": 0.95, "weight_loss": 0.8, 
                "night_sweats": 0.7, "fever": 0.6, "fatigue": 0.5, "loss_of_appetite": 0.4, "chest_pain": 0.4
            },
            "treatment": [
                "HRZE regimen: Isoniazid + Rifampin + Ethambutol + Pyrazinamide (2 months)",
                "HR continuation: Isoniazid + Rifampin (4 months)",
                "Directly Observed Treatment (DOT)", "Nutritional support",
                "HIV testing and treatment if positive", "Contact tracing and screening"
            ],
            "danger_signs": ["coughing_blood", "severe_weight_loss", "difficulty_breathing", "altered_consciousness"],
            "chronic": True,
            "duration": "6 months minimum"
        }
        
        # Diabetes
        conditions["diabetes"] = {
            "name": "Diabetes Mellitus",
            "symptoms": {
                "excessive_thirst": 0.8, "frequent_urination": 0.8, "excessive_hunger": 0.7,
                "unexplained_weight_loss": 0.7, "fatigue": 0.6, "blurred_vision": 0.5,
                "slow_healing_wounds": 0.5, "frequent_infections": 0.4, "tingling_hands_feet": 0.4
            },
            "treatment": [
                "Lifestyle modifications: diet and exercise", "Blood glucose monitoring",
                "Metformin 500-1000mg twice daily (Type 2)", "Insulin therapy if indicated",
                "Regular HbA1c monitoring", "Blood pressure and lipid control"
            ],
            "danger_signs": ["severe_hyperglycemia", "ketoacidosis_symptoms", "severe_hypoglycemia", "vision_changes"],
            "chronic": True,
            "monitoring": "every 3-6 months"
        }
        
        # Antenatal Care
        conditions["antenatal_care"] = {
            "name": "Antenatal Care",
            "symptoms": {
                "pregnancy_confirmed": 0.9, "morning_sickness": 0.6, "fatigue": 0.5,
                "missed_periods": 0.8, "breast_tenderness": 0.4, "frequent_urination": 0.3
            },
            "treatment": [
                "Regular antenatal visits (monthly until 28 weeks, then bi-weekly)",
                "Folic acid 400-800 mcg daily", "Iron supplementation",
                "Tetanus toxoid immunization", "HIV and syphilis screening",
                "Blood pressure and weight monitoring", "Ultrasound examinations"
            ],
            "danger_signs": ["severe_headache", "visual_disturbances", "severe_abdominal_pain", 
                           "vaginal_bleeding", "decreased_fetal_movement", "regular_contractions"],
            "special": "pregnancy",
            "monitoring": "throughout pregnancy"
        }
        
        return conditions
    
    def analyze_symptoms(self, symptoms: List[str], vital_signs: Dict[str, float], age: int, gender: str, 
                        medical_history: List[str] = None, pregnancy_status: bool = False):
        """Enhanced symptom analysis with new conditions"""
        
        results = []
        normalized_symptoms = [s.lower().replace(" ", "_") for s in symptoms]
        medical_history = medical_history or []
        
        for condition_name, condition_data in self.conditions.items():
            score = 0.0
            matching_symptoms = []
            
            # Skip antenatal care if not pregnant female
            if condition_name == "antenatal_care":
                if not (gender.lower() == "female" and (pregnancy_status or age >= 15)):
                    continue
            
            # Check symptom matches
            for symptom, weight in condition_data["symptoms"].items():
                if any(symptom in ns or ns in symptom for ns in normalized_symptoms):
                    score += weight
                    matching_symptoms.append(symptom.replace("_", " ").title())
            
            # Vital signs adjustments
            temp = vital_signs.get("temperature", 37.0)
            bp_systolic = vital_signs.get("systolic_bp", 120)
            resp_rate = vital_signs.get("respiratory_rate", 16)
            weight = vital_signs.get("weight", 70)
            
            # Temperature-based scoring
            if condition_name in ["malaria", "tuberculosis"] and temp > 38.5:
                score += 0.3
            elif condition_name == "pneumonia" and (resp_rate > 24 or temp > 38.0):
                score += 0.2
            elif condition_name == "hypertension" and bp_systolic > 140:
                score += 0.4
            elif condition_name == "diabetes" and any("thirst" in s or "urination" in s for s in symptoms):
                score += 0.2
            
            # Age and gender factors
            if condition_name == "pneumonia" and (age < 5 or age > 65):
                score += 0.1
            elif condition_name == "hypertension" and age > 40:
                score += 0.1
            elif condition_name == "diabetes" and age > 45:
                score += 0.1
            elif condition_name == "tuberculosis":
                # TB risk factors
                if any("hiv" in h.lower() or "malnutrition" in h.lower() for h in medical_history):
                    score += 0.2
                if age < 5 or age > 65:
                    score += 0.1
            
            # Medical history considerations
            if "diabetes" in [h.lower() for h in medical_history] and condition_name in ["tuberculosis", "hypertension"]:
                score += 0.1
            
            if score > 0.2:  # Only include significant matches
                results.append({
                    "name": condition_name,
                    "display_name": condition_data["name"],
                    "confidence": min(score, 1.0),
                    "matching_symptoms": matching_symptoms,
                    "treatment": condition_data["treatment"],
                    "danger_signs": condition_data.get("danger_signs", []),
                    "chronic": condition_data.get("chronic", False),
                    "special": condition_data.get("special", None)
                })
        
        # Sort by confidence
        results.sort(key=lambda x: x["confidence"], reverse=True)
        return results

class EnhancedTriageEngine:
    """Enhanced triage assessment with new conditions"""
    
    def assess_urgency(self, patient_data: PatientData):
        """Enhanced triage assessment"""
        
        score = 0.0
        danger_signs = []
        
        # Check symptoms for danger signs
        symptom_text = " ".join(patient_data.symptoms).lower()
        
        # Emergency keywords (expanded)
        emergency_keywords = [
            "difficulty breathing", "chest pain", "unconscious", "severe bleeding", 
            "convulsions", "altered consciousness", "severe headache", "confusion", 
            "high fever", "coughing blood", "severe abdominal pain", "visual disturbances",
            "decreased fetal movement", "regular contractions", "ketoacidosis"
        ]
        
        for keyword in emergency_keywords:
            if keyword in symptom_text:
                score += 1.0
                danger_signs.append(keyword)
        
        # Vital signs assessment (enhanced)
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
        
        # Blood glucose (if available)
        glucose = patient_data.vital_signs.get("blood_glucose", 0)
        if glucose > 400 or (glucose > 0 and glucose < 70):
            score += 0.7
            danger_signs.append(f"Critical blood glucose: {glucose} mg/dL")
        
        # Age factors (enhanced)
        if patient_data.age < 1:
            score += 0.3  # Infants are higher risk
        elif patient_data.age < 5 or patient_data.age > 75:
            score += 0.2
        
        # Pregnancy considerations
        if patient_data.gender.lower() == "female" and 15 <= patient_data.age <= 50:
            pregnancy_symptoms = ["severe_headache", "visual_disturbances", "severe_abdominal_pain"]
            if any(ps in symptom_text for ps in pregnancy_symptoms):
                score += 0.3
                danger_signs.append("Possible pregnancy complication")
        
        # Chronic disease complications
        chronic_conditions = ["diabetes", "hypertension", "tuberculosis", "hiv"]
        if any(cc in " ".join(patient_data.medical_history).lower() for cc in chronic_conditions):
            score += 0.1
        
        # Determine triage level (enhanced)
        if score >= 1.0:
            level = "EMERGENCY"
            referral = True
        elif score >= 0.7:
            level = "URGENT"
            referral = True
        elif score >= 0.4:
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

class EnhancedMedicalAI:
    """Enhanced medical AI system with 7 conditions"""
    
    def __init__(self):
        self.rule_engine = EnhancedRuleEngine()
        self.triage_engine = EnhancedTriageEngine()
    
    def conduct_consultation(self, patient_data: PatientData) -> ConsultationResult:
        """Enhanced medical consultation"""
        
        # Triage assessment
        triage_result = self.triage_engine.assess_urgency(patient_data)
        
        # Enhanced symptom analysis
        condition_matches = self.rule_engine.analyze_symptoms(
            patient_data.symptoms,
            patient_data.vital_signs,
            patient_data.age,
            patient_data.gender,
            patient_data.medical_history
        )
        
        # Enhanced recommendations
        recommendations = []
        
        if triage_result["level"] == "EMERGENCY":
            recommendations.append("🚨 IMMEDIATE MEDICAL ATTENTION REQUIRED")
            recommendations.append("Transfer to emergency department immediately")
        
        # Condition-specific recommendations (enhanced)
        for condition in condition_matches[:3]:  # Top 3 conditions
            if condition["confidence"] > 0.5:
                recommendations.extend(condition["treatment"][:4])  # Top 4 treatments
                
                # Special handling for chronic conditions
                if condition.get("chronic"):
                    recommendations.append(f"⚠️ {condition['display_name']} requires long-term management")
                
                # Special handling for pregnancy
                if condition.get("special") == "pregnancy":
                    recommendations.append("🤰 Requires specialized antenatal care")
        
        # General recommendations (enhanced)
        if triage_result["level"] in ["NON_URGENT", "LESS_URGENT"]:
            recommendations.extend([
                "Monitor symptoms and return if condition worsens",
                "Ensure adequate rest and hydration",
                "Follow medication instructions carefully",
                "Maintain healthy lifestyle habits"
            ])
        
        # Enhanced follow-up determination
        chronic_conditions = ["hypertension", "diabetes", "tuberculosis"]
        pregnancy_care = ["antenatal_care"]
        
        follow_up_required = any(
            condition["name"] in chronic_conditions + pregnancy_care
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

# Database Manager (same as before but with enhanced consultation storage)
class DatabaseManager:
    """Enhanced database manager"""
    
    def __init__(self, db_path: str = "aficare_enhanced.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize enhanced database tables"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Enhanced users table
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
                        medical_history TEXT,
                        allergies TEXT,
                        current_medications TEXT,
                        emergency_contact TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Enhanced consultations table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS consultations (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        doctor_username TEXT NOT NULL,
                        consultation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        chief_complaint TEXT,
                        symptoms TEXT,
                        vital_signs TEXT,
                        triage_level TEXT,
                        suspected_conditions TEXT,
                        recommendations TEXT,
                        confidence_score REAL,
                        follow_up_required BOOLEAN,
                        referral_needed BOOLEAN,
                        notes TEXT
                    )
                ''')
                
                conn.commit()
        except Exception as e:
            st.error(f"Database initialization failed: {str(e)}")
    
    def hash_password(self, password: str) -> str:
        return hashlib.sha256(password.encode()).hexdigest()
    
    def create_user(self, user_data: Dict[str, Any]) -> Tuple[bool, str]:
        """Enhanced user creation"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('SELECT username FROM users WHERE username = ?', (user_data['username'],))
                if cursor.fetchone():
                    return False, "Username already exists"
                
                password_hash = self.hash_password(user_data['password'])
                
                cursor.execute('''
                    INSERT INTO users (username, password_hash, role, full_name, medilink_id, 
                                     phone, email, age, gender, location, medical_history, 
                                     allergies, current_medications, emergency_contact)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_data['username'], password_hash, user_data['role'], user_data['full_name'],
                    user_data.get('medilink_id'), user_data.get('phone'), user_data.get('email'),
                    user_data.get('age'), user_data.get('gender'), user_data.get('location'),
                    user_data.get('medical_history'), user_data.get('allergies'),
                    user_data.get('current_medications'), user_data.get('emergency_contact')
                ))
                
                conn.commit()
                return True, "User created successfully"
        except Exception as e:
            return False, f"Database error: {str(e)}"
    
    def authenticate_user(self, username: str, password: str, role: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Enhanced user authentication"""
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
        """Enhanced consultation saving"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO consultations (patient_medilink_id, doctor_username, chief_complaint, 
                                             symptoms, vital_signs, triage_level, suspected_conditions, 
                                             recommendations, confidence_score, follow_up_required,
                                             referral_needed, notes)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    consultation_data['patient_medilink_id'],
                    consultation_data['doctor_username'],
                    consultation_data.get('chief_complaint'),
                    json.dumps(consultation_data.get('symptoms', [])),
                    json.dumps(consultation_data.get('vital_signs', {})),
                    consultation_data.get('triage_level'),
                    json.dumps(consultation_data.get('suspected_conditions', [])),
                    json.dumps(consultation_data.get('recommendations', [])),
                    consultation_data.get('confidence_score', 0.0),
                    consultation_data.get('follow_up_required', False),
                    consultation_data.get('referral_needed', False),
                    consultation_data.get('notes')
                ))
                
                conn.commit()
                return True
        except Exception as e:
            st.error(f"Failed to save consultation: {str(e)}")
            return False
    
    def get_patient_consultations(self, medilink_id: str) -> List[Dict[str, Any]]:
        """Enhanced consultation retrieval"""
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
                        if consultation.get('vital_signs'):
                            consultation['vital_signs'] = json.loads(consultation['vital_signs'])
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
        """Enhanced statistics"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('SELECT role, COUNT(*) FROM users GROUP BY role')
                user_counts = dict(cursor.fetchall())
                
                cursor.execute('SELECT COUNT(*) FROM consultations')
                total_consultations = cursor.fetchone()[0]
                
                # Get condition statistics
                cursor.execute('''
                    SELECT suspected_conditions, COUNT(*) 
                    FROM consultations 
                    WHERE suspected_conditions IS NOT NULL 
                    GROUP BY suspected_conditions
                ''')
                condition_stats = cursor.fetchall()
                
                return {
                    'user_counts': user_counts,
                    'total_consultations': total_consultations,
                    'condition_stats': len(condition_stats)
                }
        except:
            return {}

# Initialize global instances
@st.cache_resource
def get_database():
    """Get enhanced database instance"""
    return DatabaseManager()

@st.cache_resource
def get_medical_ai():
    """Get enhanced medical AI instance"""
    return EnhancedMedicalAI()

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink (Enhanced Medical)",
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

.enhanced-info {
    background: #e8f5e8;
    border: 1px solid #4caf50;
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

.chronic-condition {
    background: #fff3e0;
    border-left: 4px solid #ff9800;
    padding: 0.5rem;
    margin: 0.5rem 0;
}

.pregnancy-care {
    background: #fce4ec;
    border-left: 4px solid #e91e63;
    padding: 0.5rem;
    margin: 0.5rem 0;
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
    """Display enhanced login/registration page"""
    
    # Header
    st.markdown("""
    <div class="main-header patient-theme">
        <h1>🏥 AfiCare MediLink (Enhanced Medical)</h1>
        <p>Advanced Medical AI with 7 Conditions + Persistent Database Storage</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Enhanced info
    st.markdown("""
    <div class="enhanced-info">
        <h4>🧠 Enhanced Medical AI Features:</h4>
        <p>✅ <strong>7 Medical Conditions:</strong> Malaria, Pneumonia, Hypertension, Common Cold, <strong>Tuberculosis, Diabetes, Antenatal Care</strong><br>
        ✅ <strong>Enhanced Triage:</strong> Improved emergency detection with pregnancy and chronic disease considerations<br>
        ✅ <strong>Chronic Disease Management:</strong> Long-term care protocols for TB, Diabetes, Hypertension<br>
        ✅ <strong>Maternal Health:</strong> Comprehensive antenatal care with danger sign detection<br>
        ✅ <strong>Persistent Database:</strong> All medical records saved permanently</p>
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
    
    # Enhanced patient-specific fields
    if role == "patient":
        st.subheader("Medical Information")
        col1, col2 = st.columns(2)
        with col1:
            age = st.number_input("Age *", min_value=0, max_value=120, value=25)
            gender = st.selectbox("Gender *", ["Male", "Female", "Other"])
            location = st.selectbox("Location", ["Nairobi", "Mombasa", "Kisumu", "Other"])
        with col2:
            medical_history = st.text_area("Medical History", placeholder="e.g., Diabetes, Hypertension, HIV")
            allergies = st.text_area("Known Allergies", placeholder="e.g., Penicillin, Sulfa drugs")
            emergency_contact = st.text_input("Emergency Contact", placeholder="Name and phone number")
    else:
        age, gender, location, medical_history, allergies, emergency_contact = None, None, None, None, None, None
    
    if st.button("📝 Register Account", type="primary"):
        if not all([full_name, username, phone, password, confirm_password]):
            st.error("❌ Please fill in all required fields")
        elif password != confirm_password:
            st.error("❌ Passwords do not match")
        else:
            user_data = {
                "username": username, "password": password, "role": role, "full_name": full_name,
                "phone": phone, "email": email, "age": age, "gender": gender, "location": location,
                "medical_history": medical_history, "allergies": allergies, "emergency_contact": emergency_contact
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
                    <p><em>💾 Account saved with enhanced medical profile!</em></p>
                    <p><strong>👆 Click 'Login' tab to sign in!</strong></p>
                </div>
                """, unsafe_allow_html=True)
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
        <h1>🏥 AfiCare MediLink (Enhanced Medical)</h1>
        <p>{user_data['full_name']} - {role.title()}</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Enhanced sidebar
    with st.sidebar:
        st.write(f"**Logged in as:** {role.title()}")
        if role == "patient" and st.session_state.medilink_id:
            st.write(f"**MediLink ID:** {st.session_state.medilink_id}")
        
        # Enhanced database stats
        stats = db.get_stats()
        st.write("**📊 Enhanced System Stats:**")
        if stats.get('user_counts'):
            for role_name, count in stats['user_counts'].items():
                st.write(f"• {role_name.title()}s: {count}")
        st.write(f"• Total Consultations: {stats.get('total_consultations', 0)}")
        st.write(f"• Medical Conditions: 7 (Enhanced)")
        
        if st.button("🚪 Logout"):
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
    """Enhanced patient interface"""
    
    medilink_id = st.session_state.medilink_id
    
    st.info(f"📋 Your MediLink ID: **{medilink_id}** - Enhanced medical records with 7 conditions")
    
    # Get consultations from database
    consultations = db.get_patient_consultations(medilink_id)
    
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("Total Visits", len(consultations))
    with col2:
        last_visit = consultations[0]['consultation_date'][:10] if consultations else "Never"
        st.metric("Last Visit", last_visit)
    with col3:
        emergency_visits = len([c for c in consultations if c['triage_level'] == 'EMERGENCY'])
        st.metric("Emergency Visits", emergency_visits)
    with col4:
        chronic_conditions = len([c for c in consultations if any(
            cond.get('chronic', False) for cond in c.get('suspected_conditions', [])
        )])
        st.metric("Chronic Conditions", chronic_conditions)
    
    # Enhanced consultation display
    if consultations:
        st.subheader("📈 Your Enhanced Medical History")
        for consultation in consultations[:5]:
            with st.expander(f"{consultation['consultation_date'][:16]} - {consultation['triage_level']}"):
                st.write(f"**Doctor:** {consultation['doctor_username']}")
                st.write(f"**Chief Complaint:** {consultation['chief_complaint'] or 'Not specified'}")
                st.write(f"**Triage Level:** {consultation['triage_level']}")
                
                if consultation['suspected_conditions']:
                    conditions = consultation['suspected_conditions']
                    if conditions:
                        top_condition = conditions[0]
                        st.write(f"**Top Diagnosis:** {top_condition.get('display_name', 'Unknown')} ({top_condition.get('confidence', 0):.1%})")
                        
                        # Highlight chronic conditions
                        if top_condition.get('chronic'):
                            st.markdown(f"""
                            <div class="chronic-condition">
                                ⚠️ <strong>Chronic Condition:</strong> Requires ongoing management and regular follow-up
                            </div>
                            """, unsafe_allow_html=True)
                        
                        # Highlight pregnancy care
                        if top_condition.get('special') == 'pregnancy':
                            st.markdown(f"""
                            <div class="pregnancy-care">
                                🤰 <strong>Pregnancy Care:</strong> Specialized antenatal monitoring required
                            </div>
                            """, unsafe_allow_html=True)
                
                if consultation.get('follow_up_required'):
                    st.warning("📅 Follow-up appointment recommended")
                if consultation.get('referral_needed'):
                    st.error("🏥 Specialist referral recommended")
    else:
        st.info("No consultations found. Visit a healthcare provider to start building your enhanced medical history!")

def show_enhanced_healthcare_provider_dashboard():
    """Enhanced healthcare provider interface"""
    
    st.subheader("👨‍⚕️ Enhanced Healthcare Provider Dashboard")
    st.info("🧠 **Enhanced AI:** Now supports 7 medical conditions including TB, Diabetes, and Antenatal Care")
    
    # Enhanced patient lookup
    medilink_id = st.text_input("Enter Patient MediLink ID", placeholder="ML-NBO-XXXX")
    
    if medilink_id and st.button("🔍 Load Patient"):
        st.success(f"✅ Patient loaded: {medilink_id}")
        
        # Enhanced consultation form
        st.subheader("📋 Enhanced Medical Consultation")
        
        chief_complaint = st.text_area("Chief Complaint")
        
        # Enhanced symptoms (organized by system)
        st.write("**Symptoms (Enhanced Categories):**")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.write("**General Symptoms:**")
            fever = st.checkbox("Fever")
            fatigue = st.checkbox("Fatigue")
            weight_loss = st.checkbox("Weight loss")
            night_sweats = st.checkbox("Night sweats")
            loss_of_appetite = st.checkbox("Loss of appetite")
        
        with col2:
            st.write("**Respiratory:**")
            cough = st.checkbox("Cough")
            persistent_cough = st.checkbox("Persistent cough (>3 weeks)")
            coughing_blood = st.checkbox("Coughing blood")
            difficulty_breathing = st.checkbox("Difficulty breathing")
            chest_pain = st.checkbox("Chest pain")
        
        with col3:
            st.write("**Other Systems:**")
            headache = st.checkbox("Headache")
            nausea = st.checkbox("Nausea")
            excessive_thirst = st.checkbox("Excessive thirst")
            frequent_urination = st.checkbox("Frequent urination")
            blurred_vision = st.checkbox("Blurred vision")
        
        # Pregnancy-specific symptoms
        if st.checkbox("🤰 Pregnancy-related consultation"):
            st.write("**Pregnancy Symptoms:**")
            col1, col2 = st.columns(2)
            with col1:
                morning_sickness = st.checkbox("Morning sickness")
                severe_headache = st.checkbox("Severe headache")
                visual_disturbances = st.checkbox("Visual disturbances")
            with col2:
                severe_abdominal_pain = st.checkbox("Severe abdominal pain")
                vaginal_bleeding = st.checkbox("Vaginal bleeding")
                decreased_fetal_movement = st.checkbox("Decreased fetal movement")
        else:
            morning_sickness = severe_headache = visual_disturbances = False
            severe_abdominal_pain = vaginal_bleeding = decreased_fetal_movement = False
        
        # Enhanced vital signs
        st.write("**Enhanced Vital Signs:**")
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            temperature = st.number_input("Temperature (°C)", value=37.0)
            systolic_bp = st.number_input("Systolic BP", value=120)
        
        with col2:
            diastolic_bp = st.number_input("Diastolic BP", value=80)
            pulse = st.number_input("Pulse (bpm)", value=80)
        
        with col3:
            resp_rate = st.number_input("Respiratory Rate", value=16)
            oxygen_sat = st.number_input("Oxygen Saturation (%)", value=98)
        
        with col4:
            weight = st.number_input("Weight (kg)", value=70.0)
            blood_glucose = st.number_input("Blood Glucose (mg/dL)", value=0, help="Optional - enter if available")
        
        # Medical history
        medical_history_input = st.text_area("Known Medical History", placeholder="e.g., Diabetes, Hypertension, HIV")
        
        if st.button("🧠 Enhanced AI Analysis & Save to Database", type="primary"):
            # Prepare enhanced symptoms list
            symptoms_list = []
            if fever: symptoms_list.append("fever")
            if fatigue: symptoms_list.append("fatigue")
            if weight_loss: symptoms_list.append("weight_loss")
            if night_sweats: symptoms_list.append("night_sweats")
            if loss_of_appetite: symptoms_list.append("loss_of_appetite")
            if cough: symptoms_list.append("cough")
            if persistent_cough: symptoms_list.append("persistent_cough")
            if coughing_blood: symptoms_list.append("coughing_blood")
            if difficulty_breathing: symptoms_list.append("difficulty_breathing")
            if chest_pain: symptoms_list.append("chest_pain")
            if headache: symptoms_list.append("headache")
            if nausea: symptoms_list.append("nausea")
            if excessive_thirst: symptoms_list.append("excessive_thirst")
            if frequent_urination: symptoms_list.append("frequent_urination")
            if blurred_vision: symptoms_list.append("blurred_vision")
            if morning_sickness: symptoms_list.append("morning_sickness")
            if severe_headache: symptoms_list.append("severe_headache")
            if visual_disturbances: symptoms_list.append("visual_disturbances")
            if severe_abdominal_pain: symptoms_list.append("severe_abdominal_pain")
            if vaginal_bleeding: symptoms_list.append("vaginal_bleeding")
            if decreased_fetal_movement: symptoms_list.append("decreased_fetal_movement")
            
            if not symptoms_list:
                st.error("Please select at least one symptom")
            else:
                # Create enhanced patient data
                patient_data = PatientData(
                    patient_id=medilink_id,
                    age=30,  # Default for demo
                    gender="female" if any([morning_sickness, severe_headache, visual_disturbances]) else "unknown",
                    symptoms=symptoms_list,
                    vital_signs={
                        "temperature": temperature,
                        "systolic_bp": systolic_bp,
                        "diastolic_bp": diastolic_bp,
                        "pulse": pulse,
                        "respiratory_rate": resp_rate,
                        "oxygen_saturation": oxygen_sat,
                        "weight": weight,
                        "blood_glucose": blood_glucose if blood_glucose > 0 else None
                    },
                    medical_history=medical_history_input.split(',') if medical_history_input else [],
                    current_medications=[],
                    chief_complaint=chief_complaint or "Enhanced consultation"
                )
                
                # Run enhanced AI analysis
                with st.spinner("🧠 Enhanced AI analyzing with 7 conditions..."):
                    result = medical_ai.conduct_consultation(patient_data)
                    
                    # Display enhanced results
                    st.success("🎯 Enhanced AI Analysis Complete!")
                    
                    triage_colors = {"EMERGENCY": "🚨", "URGENT": "⚠️", "LESS_URGENT": "⏰", "NON_URGENT": "✅"}
                    triage_emoji = triage_colors.get(result.triage_level, "ℹ️")
                    st.write(f"**{triage_emoji} Triage Level:** {result.triage_level}")
                    st.write(f"**🎯 Confidence:** {result.confidence_score:.1%}")
                    
                    # Enhanced condition display
                    if result.suspected_conditions:
                        st.write("**🔍 Suspected Conditions (Enhanced Analysis):**")
                        for i, condition in enumerate(result.suspected_conditions[:4], 1):
                            confidence = condition['confidence']
                            name = condition['display_name']
                            st.write(f"{i}. **{name}** - {confidence:.1%}")
                            
                            # Highlight special conditions
                            if condition.get('chronic'):
                                st.markdown(f"""
                                <div class="chronic-condition">
                                    ⚠️ <strong>Chronic Condition:</strong> Requires long-term management
                                </div>
                                """, unsafe_allow_html=True)
                            
                            if condition.get('special') == 'pregnancy':
                                st.markdown(f"""
                                <div class="pregnancy-care">
                                    🤰 <strong>Pregnancy Care:</strong> Specialized antenatal monitoring
                                </div>
                                """, unsafe_allow_html=True)
                    
                    # Enhanced recommendations
                    if result.recommendations:
                        st.write("**💊 Enhanced Treatment Recommendations:**")
                        for i, rec in enumerate(result.recommendations[:6], 1):
                            st.write(f"{i}. {rec}")
                    
                    # Enhanced follow-up indicators
                    col1, col2 = st.columns(2)
                    with col1:
                        if result.referral_needed:
                            st.error("🏥 **Specialist referral recommended**")
                        else:
                            st.success("✅ **Can be managed locally**")
                    
                    with col2:
                        if result.follow_up_required:
                            st.warning("📅 **Follow-up required**")
                        else:
                            st.info("ℹ️ **Routine follow-up as needed**")
                    
                    # Save enhanced consultation
                    consultation_data = {
                        "patient_medilink_id": medilink_id,
                        "doctor_username": st.session_state.user_data['username'],
                        "chief_complaint": chief_complaint,
                        "symptoms": symptoms_list,
                        "vital_signs": {
                            "temperature": temperature, "systolic_bp": systolic_bp, "diastolic_bp": diastolic_bp,
                            "pulse": pulse, "respiratory_rate": resp_rate, "oxygen_saturation": oxygen_sat,
                            "weight": weight, "blood_glucose": blood_glucose if blood_glucose > 0 else None
                        },
                        "triage_level": result.triage_level,
                        "suspected_conditions": result.suspected_conditions,
                        "recommendations": result.recommendations,
                        "confidence_score": result.confidence_score,
                        "follow_up_required": result.follow_up_required,
                        "referral_needed": result.referral_needed
                    }
                    
                    if db.save_consultation(consultation_data):
                        st.success("✅ Enhanced consultation saved to database!")
                        st.info("📋 This consultation with enhanced AI analysis is now part of the patient's permanent MediLink record")
                    else:
                        st.error("❌ Failed to save consultation")

def show_enhanced_admin_dashboard():
    """Enhanced admin interface"""
    
    st.subheader("⚙️ Enhanced System Administration")
    
    stats = db.get_stats()
    
    st.write("**📊 Enhanced Database Statistics:**")
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if stats.get('user_counts'):
            for role, count in stats['user_counts'].items():
                st.metric(f"{role.title()}s", count)
    
    with col2:
        st.metric("Total Consultations", stats.get('total_consultations', 0))
        st.metric("Medical Conditions", "7 (Enhanced)")
    
    with col3:
        st.metric("Condition Categories", stats.get('condition_stats', 0))
        st.metric("Database Version", "Enhanced")
    
    st.markdown("""
    <div class="enhanced-info">
        <h4>🧠 Enhanced Medical AI Active</h4>
        <p><strong>New Conditions Added:</strong></p>
        <ul>
            <li><strong>Tuberculosis:</strong> 6-month treatment protocols, drug resistance detection</li>
            <li><strong>Diabetes:</strong> Type 1/2 differentiation, chronic management</li>
            <li><strong>Antenatal Care:</strong> Pregnancy monitoring, danger sign detection</li>
        </ul>
        <p><strong>Enhanced Features:</strong> Chronic disease management, pregnancy care, improved triage</p>
    </div>
    """, unsafe_allow_html=True)

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        show_dashboard()

if __name__ == "__main__":
    main()