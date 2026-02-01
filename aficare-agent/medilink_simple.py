"""
MediLink Simple - Simplified version to avoid port issues
Single app for patients, doctors, and admins with role-based interface
Includes rule-based medical AI for consultations
Now with PWA support for mobile installation!
Enhanced with proper QR code generation and mobile optimization
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

# PWA Configuration
def configure_pwa():
    """Configure Progressive Web App features"""
    st.set_page_config(
        page_title="AfiCare MediLink",
        page_icon="🏥",
        layout="wide",
        initial_sidebar_state="collapsed",
        menu_items={
            'Get Help': 'https://github.com/aficare/medilink',
            'Report a bug': 'https://github.com/aficare/medilink/issues',
            'About': "AfiCare MediLink - Patient-Owned Healthcare Records for Africa"
        }
    )
    
    # Configure PWA with proper HTML injection using components
    import streamlit.components.v1 as components
    
    components.html("""
    <script>
        // PWA Install prompt
        let deferredPrompt;
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            
            // Create install button
            const installBtn = document.createElement('button');
            installBtn.innerHTML = '📱 Install App';
            installBtn.style.cssText = `
                position: fixed; bottom: 20px; right: 20px; z-index: 9999;
                background: #2E7D32; color: white; border: none;
                padding: 12px 16px; border-radius: 25px; font-size: 14px;
                font-weight: bold; cursor: pointer; box-shadow: 0 4px 12px rgba(46,125,50,0.3);
            `;
            
            installBtn.onclick = async () => {
                if (deferredPrompt) {
                    deferredPrompt.prompt();
                    const { outcome } = await deferredPrompt.userChoice;
                    deferredPrompt = null;
                    installBtn.remove();
                }
            };
            
            document.body.appendChild(installBtn);
            setTimeout(() => installBtn.remove(), 10000);
        });
        
        // Register service worker
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('/static/sw.js').catch(console.error);
        }
    </script>
    
    <style>
        /* Mobile optimization */
        @media (max-width: 768px) {
            .main .block-container { padding: 1rem; max-width: 100%; }
            .stButton > button { width: 100%; min-height: 44px; margin-bottom: 0.5rem; }
            .stSelectbox > div > div, .stTextInput > div > div > input { font-size: 16px; }
        }
        
        /* PWA mode */
        @media (display-mode: standalone) {
            .main { padding-top: env(safe-area-inset-top); padding-bottom: env(safe-area-inset-bottom); }
        }
    </style>
    """, height=0)

# Configure PWA on app start
configure_pwa()

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
    print("[OK] Real AfiCare AI Agent loaded successfully!")
except ImportError as e:
    print(f"[--] Could not load real AI Agent: {e}")
    print("[..] Using simplified AI instead...")
    REAL_AI_AVAILABLE = False

# Import Hybrid AI (LangChain/Groq/Ollama)
HYBRID_AI_AVAILABLE = False
try:
    from ai.hybrid_medical_agent import (
        HybridMedicalAgent,
        AIBackend,
        MedicalAnalysis,
        GROQ_AVAILABLE,
        OLLAMA_AVAILABLE
    )
    HYBRID_AI_AVAILABLE = True
    if GROQ_AVAILABLE:
        print("[OK] Hybrid AI: Groq Cloud connected (FREE)")
    elif OLLAMA_AVAILABLE:
        print("[OK] Hybrid AI: Ollama Local connected (FREE)")
    else:
        print("[OK] Hybrid AI: Rule-based mode (offline)")
except ImportError as e:
    print(f"[--] Hybrid AI not available: {e}")

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
        
        # PCOS (Polycystic Ovary Syndrome)
        conditions["pcos"] = {
            "name": "Polycystic Ovary Syndrome (PCOS)",
            "symptoms": {
                "irregular_periods": 0.9,
                "excessive_hair_growth": 0.8,
                "acne": 0.6,
                "weight_gain": 0.7,
                "hair_loss": 0.5,
                "difficulty_conceiving": 0.8
            },
            "treatment": [
                "Lifestyle modifications (diet and exercise)",
                "Metformin for insulin resistance",
                "Hormonal contraceptives for cycle regulation",
                "Anti-androgen therapy for hirsutism",
                "Fertility treatments if trying to conceive"
            ],
            "danger_signs": ["severe_pelvic_pain", "heavy_bleeding"]
        }
        
        # Endometriosis
        conditions["endometriosis"] = {
            "name": "Endometriosis",
            "symptoms": {
                "severe_menstrual_cramps": 0.9,
                "chronic_pelvic_pain": 0.8,
                "pain_during_intercourse": 0.7,
                "heavy_menstrual_bleeding": 0.6,
                "infertility": 0.5,
                "gastrointestinal_symptoms": 0.4
            },
            "treatment": [
                "Pain management with NSAIDs",
                "Hormonal therapy (birth control, GnRH agonists)",
                "Surgical treatment (laparoscopy)",
                "Fertility preservation if needed",
                "Physical therapy for pelvic pain"
            ],
            "danger_signs": ["severe_abdominal_pain", "heavy_bleeding", "fever"]
        }
        
        # Uterine Fibroids
        conditions["uterine_fibroids"] = {
            "name": "Uterine Fibroids",
            "symptoms": {
                "heavy_menstrual_bleeding": 0.9,
                "prolonged_periods": 0.8,
                "pelvic_pressure": 0.7,
                "frequent_urination": 0.6,
                "constipation": 0.5,
                "back_pain": 0.4
            },
            "treatment": [
                "Watchful waiting for small, asymptomatic fibroids",
                "Hormonal medications to control bleeding",
                "Uterine artery embolization",
                "Myomectomy (surgical removal)",
                "Hysterectomy for severe cases"
            ],
            "danger_signs": ["severe_bleeding", "severe_pain", "rapid_growth"]
        }
        
        # Gestational Diabetes
        conditions["gestational_diabetes"] = {
            "name": "Gestational Diabetes",
            "symptoms": {
                "excessive_thirst": 0.6,
                "frequent_urination": 0.7,
                "fatigue": 0.5,
                "blurred_vision": 0.4,
                "nausea": 0.3
            },
            "treatment": [
                "Dietary modifications and carbohydrate counting",
                "Regular blood glucose monitoring",
                "Moderate exercise as approved by doctor",
                "Insulin therapy if diet/exercise insufficient",
                "Fetal monitoring for growth and wellbeing"
            ],
            "danger_signs": ["very_high_blood_sugar", "ketones_in_urine", "severe_nausea"]
        }
        
        # Preeclampsia
        conditions["preeclampsia"] = {
            "name": "Preeclampsia",
            "symptoms": {
                "high_blood_pressure": 0.9,
                "protein_in_urine": 0.9,
                "severe_headache": 0.8,
                "visual_changes": 0.7,
                "upper_abdominal_pain": 0.6,
                "swelling": 0.5
            },
            "treatment": [
                "Close blood pressure monitoring",
                "Antihypertensive medications",
                "Corticosteroids for fetal lung maturity",
                "Magnesium sulfate to prevent seizures",
                "Delivery planning (may need early delivery)"
            ],
            "danger_signs": ["severe_headache", "visual_disturbances", "epigastric_pain", "seizures"]
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

# Initialize the medical AI system - REAL AfiCare Agent with LangChain
@st.cache_resource
def get_medical_ai():
    """Get cached medical AI instance - Real AfiCare Agent with LangChain support"""
    try:
        # Try to load the LangChain-powered agent first
        from core.langchain_agent import create_medical_agent
        
        agent = create_medical_agent(use_langchain=True)
        
        if hasattr(agent, 'reasoning_chain'):
            # LangChain agent loaded successfully
            class LangChainAgentWrapper:
                def __init__(self, agent):
                    self.agent = agent
                    self.name = "AfiCare AI Agent (LangChain + RAG Powered)"
                
                def conduct_consultation(self, patient_data):
                    """Run LangChain consultation with RAG and multi-agent reasoning"""
                    import asyncio
                    
                    # Convert to LangChain agent format
                    from core.langchain_agent import PatientData as LCPatientData
                    
                    lc_patient_data = LCPatientData(
                        patient_id=patient_data.patient_id,
                        age=patient_data.age,
                        gender=patient_data.gender,
                        symptoms=patient_data.symptoms,
                        vital_signs=patient_data.vital_signs,
                        medical_history=patient_data.medical_history,
                        current_medications=patient_data.current_medications,
                        chief_complaint=patient_data.chief_complaint
                    )
                    
                    # Run the LangChain consultation
                    lc_result = asyncio.run(self.agent.conduct_consultation(lc_patient_data))
                    
                    # Convert back to simple format
                    simple_result = ConsultationResult(
                        patient_id=lc_result.patient_id,
                        timestamp=lc_result.timestamp,
                        triage_level=lc_result.triage_level,
                        suspected_conditions=lc_result.suspected_conditions,
                        recommendations=lc_result.recommendations,
                        referral_needed=lc_result.referral_needed,
                        follow_up_required=lc_result.follow_up_required,
                        confidence_score=lc_result.confidence_score
                    )
                    
                    # Add LangChain-specific data
                    simple_result.reasoning_chain = lc_result.reasoning_chain
                    simple_result.evidence_sources = lc_result.evidence_sources
                    
                    return simple_result
            
            wrapper = LangChainAgentWrapper(agent)
            print(f"✅ LangChain Medical Agent loaded with RAG and multi-agent reasoning!")
            return wrapper
        
        else:
            # Fallback agent loaded
            class AfiCareAgentWrapper:
                def __init__(self, agent):
                    self.agent = agent
                    self.name = "AfiCare AI Agent (Custom Framework)"
                
                def conduct_consultation(self, patient_data):
                    """Convert simple patient data to real agent format and run consultation"""
                    import asyncio
                    
                    # Convert to real agent format
                    from core.agent import PatientData as RealPatientData
                    
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
            print(f"✅ Custom AfiCare AI Agent loaded with {len(agent.plugin_manager.plugins)} plugins!")
            return wrapper
        
    except Exception as e:
        print(f"[--] Could not load advanced AI agents: {e}")
        print("[..] Using simplified AI instead...")
        return MedicalAI()

# ============================================
# HYBRID AI INTEGRATION (FREE: Groq/Ollama)
# ============================================

@st.cache_resource
def get_hybrid_ai_agent():
    """Get the hybrid AI agent (Rule-based + LLM enhancement)"""
    if not HYBRID_AI_AVAILABLE:
        return None

    # Auto-select best available backend
    if GROQ_AVAILABLE:
        backend = AIBackend.GROQ
    elif OLLAMA_AVAILABLE:
        backend = AIBackend.OLLAMA
    else:
        backend = AIBackend.RULE_BASED

    return HybridMedicalAgent(preferred_backend=backend)

def get_ai_backend_status():
    """Get status of AI backends for display"""
    status = {
        "rule_based": True,
        "groq": GROQ_AVAILABLE if HYBRID_AI_AVAILABLE else False,
        "ollama": OLLAMA_AVAILABLE if HYBRID_AI_AVAILABLE else False,
        "hybrid_available": HYBRID_AI_AVAILABLE
    }
    return status

def display_ai_backend_selector():
    """Display AI backend selection in sidebar"""
    status = get_ai_backend_status()

    with st.sidebar:
        st.markdown("---")
        st.markdown("### AI Engine")

        if status["groq"]:
            st.success("Groq Cloud (FREE)")
            st.caption("30 requests/min")
        elif status["ollama"]:
            st.success("Ollama Local (FREE)")
            st.caption("Unlimited, offline")
        else:
            st.info("Rule-Based Engine")
            st.caption("Always available")

        # Show setup instructions if no LLM
        if not status["groq"] and not status["ollama"]:
            with st.expander("Enable AI Enhancement"):
                st.markdown("""
**Get FREE AI in 2 minutes:**

**Option 1: Groq Cloud**
1. Go to [console.groq.com](https://console.groq.com)
2. Create free account
3. Copy API key
4. Set: `GROQ_API_KEY=your-key`

**Option 2: Ollama Local**
1. Download [ollama.ai](https://ollama.ai)
2. Run: `ollama pull llama3.2`
3. Done!
                """)

def run_hybrid_analysis(patient_data, use_llm=True):
    """Run analysis with hybrid AI"""
    import asyncio

    agent = get_hybrid_ai_agent()

    if agent is None:
        # Fallback to simple rule engine
        medical_ai = get_medical_ai()
        return medical_ai.conduct_consultation(patient_data)

    # Run async analysis
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        result = loop.run_until_complete(agent.analyze(
            symptoms=patient_data.symptoms,
            vital_signs=patient_data.vital_signs,
            age=patient_data.age,
            gender=patient_data.gender,
            chief_complaint=patient_data.chief_complaint,
            medical_history=patient_data.medical_history
        ))

        # Convert to ConsultationResult format
        suspected_conditions = []
        for diag in result.diagnoses:
            suspected_conditions.append({
                "name": diag.get("condition", "Unknown"),
                "display_name": diag.get("condition", "Unknown"),
                "confidence": diag.get("confidence", 0.5),
                "matching_symptoms": diag.get("matching_symptoms", []),
                "treatment": diag.get("treatment", [])
            })

        return ConsultationResult(
            patient_id=patient_data.patient_id,
            timestamp=datetime.now(),
            triage_level=result.triage_level,
            suspected_conditions=suspected_conditions,
            recommendations=result.recommendations,
            referral_needed=result.triage_level in ["emergency", "urgent"],
            follow_up_required=True,
            confidence_score=result.confidence
        )
    finally:
        loop.close()

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
            "full_name": "Jane Doe",
            "medilink_id": "ML-NBO-DEMO1",
            "phone": "+254712345678",
            "email": "jane.doe@example.com",
            "gender": "Female",
            "age": 28
        },
        "ML-NBO-DEMO1": {  # Allow login with MediLink ID
            "password": "demo123",
            "role": "patient", 
            "full_name": "Jane Doe",
            "medilink_id": "ML-NBO-DEMO1",
            "phone": "+254712345678",
            "email": "jane.doe@example.com",
            "gender": "Female",
            "age": 28
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
    
    # Navigation tabs - Enhanced for women's health
    if st.session_state.user_data.get('gender') == 'Female':
        tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs([
            "📊 Health Summary", "🏥 My Visits", "🤱 Maternal Health", "👩‍⚕️ Women's Health", "🔐 Share with Hospital", "⚙️ Settings"
        ])
        
        with tab3:
            show_maternal_health_dashboard()
        
        with tab4:
            show_womens_health_dashboard()
    else:
        tab1, tab2, tab3, tab4 = st.tabs([
            "📊 Health Summary", "🏥 My Visits", "🔐 Share with Hospital", "⚙️ Settings"
        ])
    
    with tab1:
        show_patient_health_summary()
    
    with tab2:
        show_patient_visit_history()
    
    with tab3 if st.session_state.user_data.get('gender') != 'Female' else tab5:
        show_patient_sharing_options()
    
    with tab4 if st.session_state.user_data.get('gender') != 'Female' else tab6:
        show_patient_settings()

def show_patient_health_summary():
    """Enhanced patient health summary with comprehensive medical data"""
    
    st.subheader("📊 Your Comprehensive Health Dashboard")
    
    # Health Score and Key Metrics
    col1, col2, col3, col4, col5 = st.columns(5)
    
    with col1:
        st.metric("Health Score", "87%", "+3% this month", help="AI-calculated overall health score based on all medical data")
    
    with col2:
        st.metric("Total Visits", "23", "+3 this month", help="Complete medical visit history across all facilities")
    
    with col3:
        st.metric("Active Medications", "4", "Well managed", help="Current prescription medications being taken")
    
    with col4:
        st.metric("Risk Level", "Low", "Stable", help="AI-assessed health risk based on medical history and trends")
    
    with col5:
        st.metric("Last Checkup", "5 days ago", "Routine", help="Most recent medical consultation")
    
    # Critical Health Alerts
    st.markdown("---")
    st.subheader("🚨 Health Alerts & Reminders")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.success("✅ **Blood Pressure:** Well controlled (Last: 125/82)")
        st.info("💊 **Medication Adherence:** 95% compliance rate")
        st.warning("⚠️ **Cholesterol Check:** Due in 2 weeks")
    
    with col2:
        st.success("✅ **Diabetes Management:** HbA1c 6.8% (Good control)")
        st.info("🩺 **Next Appointment:** Dr. Wanjiku - Feb 5, 2024")
        st.error("🚨 **Allergy Alert:** Penicillin, Sulfa drugs - CRITICAL")
    
    # Detailed Vital Signs Trends
    st.markdown("---")
    st.subheader("📈 Vital Signs Trends (Last 6 Months)")
    
    # Simulated trend data
    import pandas as pd
    import numpy as np
    
    dates = pd.date_range(start='2023-08-01', end='2024-01-28', freq='W')
    
    # Blood Pressure Trends
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🩺 Blood Pressure Trends**")
        bp_data = pd.DataFrame({
            'Date': dates,
            'Systolic': np.random.normal(125, 8, len(dates)),
            'Diastolic': np.random.normal(82, 5, len(dates))
        })
        st.line_chart(bp_data.set_index('Date')[['Systolic', 'Diastolic']])
        
        # Latest readings
        st.write("**Recent Readings:**")
        st.write("• Jan 28: 125/82 mmHg (Normal)")
        st.write("• Jan 21: 128/85 mmHg (Normal)")
        st.write("• Jan 14: 122/80 mmHg (Optimal)")
    
    with col2:
        st.write("**🌡️ Temperature & Weight Trends**")
        temp_weight_data = pd.DataFrame({
            'Date': dates,
            'Weight (kg)': np.random.normal(74, 2, len(dates)),
            'BMI': np.random.normal(24.5, 0.5, len(dates))
        })
        st.line_chart(temp_weight_data.set_index('Date'))
        
        # Current status
        st.write("**Current Status:**")
        st.write("• Weight: 74.2 kg (Stable)")
        st.write("• BMI: 24.3 (Normal range)")
        st.write("• Body Fat: 18% (Healthy)")
    
    # Comprehensive Medical Profile
    st.markdown("---")
    st.subheader("🧬 Complete Medical Profile")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.write("**🩸 Blood Work (Latest)**")
        st.write("• **HbA1c:** 6.8% (Good)")
        st.write("• **Cholesterol:** 185 mg/dL")
        st.write("• **HDL:** 45 mg/dL")
        st.write("• **LDL:** 120 mg/dL")
        st.write("• **Triglycerides:** 150 mg/dL")
        st.write("• **Creatinine:** 0.9 mg/dL (Normal)")
        st.write("• **eGFR:** >90 (Excellent)")
        
    with col2:
        st.write("**🫀 Cardiovascular Health**")
        st.write("• **Resting HR:** 68 bpm (Good)")
        st.write("• **BP Control:** Excellent")
        st.write("• **Exercise Tolerance:** Good")
        st.write("• **ECG:** Normal sinus rhythm")
        st.write("• **Echo:** Normal EF 60%")
        st.write("• **Risk Score:** Low (2%)")
        
    with col3:
        st.write("**🧠 Mental Health & Lifestyle**")
        st.write("• **Stress Level:** Moderate")
        st.write("• **Sleep Quality:** 7.5/10")
        st.write("• **Exercise:** 4x/week")
        st.write("• **Diet Score:** 8/10")
        st.write("• **Smoking:** Never")
        st.write("• **Alcohol:** Occasional")
    
    # Medication Management
    st.markdown("---")
    st.subheader("💊 Active Medication Management")
    
    medications = [
        {
            "name": "Metformin XR",
            "dosage": "1000mg",
            "frequency": "Once daily",
            "purpose": "Type 2 Diabetes",
            "adherence": "98%",
            "side_effects": "None reported",
            "next_refill": "Feb 15, 2024"
        },
        {
            "name": "Lisinopril",
            "dosage": "10mg",
            "frequency": "Once daily",
            "purpose": "Hypertension",
            "adherence": "95%",
            "side_effects": "Mild dry cough",
            "next_refill": "Feb 20, 2024"
        },
        {
            "name": "Atorvastatin",
            "dosage": "20mg",
            "frequency": "Once daily (evening)",
            "purpose": "Cholesterol management",
            "adherence": "92%",
            "side_effects": "None reported",
            "next_refill": "Feb 10, 2024"
        },
        {
            "name": "Aspirin",
            "dosage": "81mg",
            "frequency": "Once daily",
            "purpose": "Cardiovascular protection",
            "adherence": "97%",
            "side_effects": "None reported",
            "next_refill": "Feb 25, 2024"
        }
    ]
    
    for med in medications:
        with st.expander(f"💊 {med['name']} {med['dosage']} - {med['adherence']} adherence"):
            col1, col2 = st.columns(2)
            
            with col1:
                st.write(f"**Purpose:** {med['purpose']}")
                st.write(f"**Dosage:** {med['dosage']}")
                st.write(f"**Frequency:** {med['frequency']}")
                st.write(f"**Adherence:** {med['adherence']}")
            
            with col2:
                st.write(f"**Side Effects:** {med['side_effects']}")
                st.write(f"**Next Refill:** {med['next_refill']}")
                if med['adherence'] == "98%":
                    st.success("Excellent adherence!")
                elif med['adherence'] == "95%":
                    st.success("Good adherence")
                else:
                    st.warning("Could improve adherence")
    
    # Health Goals and Progress
    st.markdown("---")
    st.subheader("🎯 Health Goals & Progress")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Current Health Goals:**")
        
        # Weight management
        st.write("**1. Weight Management**")
        st.progress(0.8)
        st.write("Target: 72kg | Current: 74.2kg | Progress: 80%")
        
        # Exercise
        st.write("**2. Exercise Routine**")
        st.progress(0.9)
        st.write("Target: 5x/week | Current: 4x/week | Progress: 90%")
        
        # Blood Sugar Control
        st.write("**3. Blood Sugar Control**")
        st.progress(0.85)
        st.write("Target: HbA1c <7% | Current: 6.8% | Progress: 85%")
    
    with col2:
        st.write("**Achievements This Year:**")
        st.success("🏆 Maintained HbA1c below 7% for 8 months")
        st.success("🏆 Lost 3kg and maintained weight")
        st.success("🏆 100% medication adherence for 6 months")
        st.success("🏆 Completed annual health screening")
        st.info("🎯 Next goal: Reduce cholesterol to <180 mg/dL")
    
    # Family Medical History
    st.markdown("---")
    st.subheader("👨‍👩‍👧‍👦 Family Medical History")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Paternal Side:**")
        st.write("• **Father:** Type 2 Diabetes (age 45), Hypertension")
        st.write("• **Grandfather:** Heart disease (deceased age 72)")
        st.write("• **Grandmother:** Stroke (deceased age 78)")
        
    with col2:
        st.write("**Maternal Side:**")
        st.write("• **Mother:** Hypertension, Arthritis")
        st.write("• **Grandfather:** Diabetes (deceased age 80)")
        st.write("• **Grandmother:** Healthy (living, age 85)")
    
    # Risk Assessment
    st.markdown("---")
    st.subheader("⚠️ AI-Powered Risk Assessment")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.write("**🫀 Cardiovascular Risk**")
        st.progress(0.2)
        st.write("**Low Risk (15%)**")
        st.write("Factors: Well-controlled BP, good cholesterol, regular exercise")
    
    with col2:
        st.write("**🍯 Diabetes Complications**")
        st.progress(0.25)
        st.write("**Low Risk (20%)**")
        st.write("Factors: Good HbA1c control, regular monitoring, healthy lifestyle")
    
    with col3:
        st.write("**🧠 Stroke Risk**")
        st.progress(0.15)
        st.write("**Very Low Risk (10%)**")
        st.write("Factors: Controlled BP, aspirin therapy, no smoking")
    
    # Health Recommendations
    st.markdown("---")
    st.subheader("💡 Personalized Health Recommendations")
    
    recommendations = [
        "🥗 **Nutrition:** Continue Mediterranean diet, reduce sodium to <2300mg/day",
        "🏃‍♂️ **Exercise:** Add 1 more cardio session per week to reach 5x/week goal",
        "💊 **Medications:** Consider discussing statin timing with doctor for better cholesterol control",
        "🩺 **Monitoring:** Schedule eye exam for diabetic retinopathy screening",
        "😴 **Sleep:** Maintain 7-8 hours nightly, consider sleep study if snoring persists",
        "🧘‍♂️ **Stress:** Continue stress management techniques, consider meditation app",
        "📱 **Technology:** Use glucose monitoring app for better tracking"
    ]
    
    for rec in recommendations:
        st.info(rec)

def show_patient_visit_history():
    """Enhanced patient visit history with comprehensive medical records"""
    
    st.subheader("🏥 Complete Medical Visit History")
    
    # Summary statistics
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Total Visits", "23", "Across 8 facilities")
    
    with col2:
        st.metric("Emergency Visits", "2", "Last: 8 months ago")
    
    with col3:
        st.metric("Specialists Seen", "6", "Endocrinologist, Cardiologist, etc.")
    
    with col4:
        st.metric("Procedures Done", "12", "Lab tests, imaging, etc.")
    
    st.markdown("---")
    
    # Detailed visit history
    visits = [
        {
            "date": "Jan 28, 2024",
            "hospital": "Nairobi General Hospital",
            "department": "Internal Medicine",
            "doctor": "Dr. Mary Wanjiku",
            "visit_type": "Follow-up",
            "complaint": "Routine diabetes and hypertension follow-up",
            "symptoms": ["None - routine checkup"],
            "vital_signs": {
                "BP": "125/82 mmHg",
                "Weight": "74.2 kg",
                "BMI": "24.3",
                "Temperature": "36.8°C",
                "Pulse": "68 bpm",
                "SpO2": "98%"
            },
            "diagnosis": "Type 2 Diabetes Mellitus - well controlled, Essential Hypertension - well controlled",
            "treatment": [
                "Continue Metformin XR 1000mg daily",
                "Continue Lisinopril 10mg daily",
                "Lifestyle modifications reinforced"
            ],
            "lab_results": {
                "HbA1c": "6.8% (Good control)",
                "Creatinine": "0.9 mg/dL (Normal)",
                "Cholesterol": "185 mg/dL"
            },
            "triage": "ROUTINE",
            "cost": "KES 2,500",
            "insurance": "NHIF covered 80%",
            "next_appointment": "Feb 28, 2024"
        },
        {
            "date": "Jan 15, 2024",
            "hospital": "Nairobi General Hospital",
            "department": "Emergency Department",
            "doctor": "Dr. James Kiprotich",
            "visit_type": "Emergency",
            "complaint": "High fever, severe headache, and body aches for 3 days",
            "symptoms": ["Fever (39.2°C)", "Severe headache", "Muscle aches", "Chills", "Sweating", "Nausea"],
            "vital_signs": {
                "BP": "140/90 mmHg",
                "Weight": "74.5 kg",
                "Temperature": "39.2°C",
                "Pulse": "98 bpm",
                "SpO2": "97%",
                "RR": "20/min"
            },
            "diagnosis": "Malaria (P. falciparum confirmed by rapid test)",
            "treatment": [
                "Artemether-Lumefantrine 80/480mg - 6 tablets over 3 days",
                "Paracetamol 1g QID for fever",
                "ORS for hydration",
                "Bed rest advised"
            ],
            "lab_results": {
                "Malaria RDT": "Positive (P. falciparum)",
                "FBC": "Mild anemia (Hb 10.2 g/dL)",
                "Blood glucose": "8.2 mmol/L (elevated due to stress)"
            },
            "triage": "URGENT",
            "cost": "KES 4,800",
            "insurance": "NHIF covered 70%",
            "outcome": "Full recovery in 5 days",
            "follow_up": "Completed - patient recovered fully"
        },
        {
            "date": "Dec 10, 2023",
            "hospital": "Kenyatta National Hospital",
            "department": "Endocrinology",
            "doctor": "Dr. Sarah Muthoni",
            "visit_type": "Specialist Consultation",
            "complaint": "Diabetes management review and optimization",
            "symptoms": ["Occasional fatigue", "Mild polyuria"],
            "vital_signs": {
                "BP": "128/85 mmHg",
                "Weight": "75.1 kg",
                "BMI": "24.6",
                "Temperature": "36.9°C",
                "Pulse": "72 bpm"
            },
            "diagnosis": "Type 2 Diabetes Mellitus - suboptimal control",
            "treatment": [
                "Increased Metformin to 1000mg XR daily",
                "Added Atorvastatin 20mg for cholesterol",
                "Dietary counseling provided",
                "Exercise plan developed"
            ],
            "lab_results": {
                "HbA1c": "7.8% (Needs improvement)",
                "Lipid profile": "Total cholesterol 220 mg/dL",
                "Microalbumin": "Normal",
                "Fundoscopy": "No diabetic retinopathy"
            },
            "triage": "ROUTINE",
            "cost": "KES 6,500",
            "insurance": "NHIF covered 60%",
            "next_appointment": "Mar 10, 2024"
        },
        {
            "date": "Nov 05, 2023",
            "hospital": "Westlands Health Centre",
            "department": "Preventive Care",
            "doctor": "Nurse Peter Otieno",
            "visit_type": "Vaccination",
            "complaint": "Annual flu vaccination and health screening",
            "symptoms": ["None - preventive care"],
            "vital_signs": {
                "BP": "122/80 mmHg",
                "Weight": "75.8 kg",
                "Temperature": "36.7°C",
                "Pulse": "70 bpm"
            },
            "diagnosis": "Healthy adult - preventive care",
            "treatment": [
                "Influenza vaccine administered",
                "Health education provided",
                "Lifestyle counseling"
            ],
            "lab_results": {
                "Basic screening": "All normal",
                "BMI": "24.8 (Normal range)"
            },
            "triage": "PREVENTIVE",
            "cost": "KES 1,200",
            "insurance": "NHIF covered 100%",
            "side_effects": "None reported"
        },
        {
            "date": "Sep 20, 2023",
            "hospital": "Aga Khan Hospital",
            "department": "Cardiology",
            "doctor": "Dr. Ahmed Hassan",
            "visit_type": "Specialist Consultation",
            "complaint": "Cardiovascular risk assessment for diabetes patient",
            "symptoms": ["Occasional chest tightness during exercise"],
            "vital_signs": {
                "BP": "135/88 mmHg",
                "Weight": "76.2 kg",
                "Pulse": "75 bpm",
                "SpO2": "99%"
            },
            "diagnosis": "Low cardiovascular risk, Exercise-induced chest discomfort (non-cardiac)",
            "treatment": [
                "Started Lisinopril 10mg daily",
                "Low-dose aspirin 81mg daily",
                "Exercise stress test recommended"
            ],
            "lab_results": {
                "ECG": "Normal sinus rhythm",
                "Echo": "Normal EF 60%",
                "Stress test": "Negative for ischemia"
            },
            "procedures": [
                "Echocardiogram",
                "Exercise stress test",
                "12-lead ECG"
            ],
            "triage": "ROUTINE",
            "cost": "KES 15,800",
            "insurance": "Private insurance covered 80%",
            "outcome": "Cleared for regular exercise"
        }
    ]
    
    # Display visits with rich details
    for visit in visits:
        # Color coding based on triage level
        if visit['triage'] == 'URGENT':
            border_color = "#ff6b6b"
        elif visit['triage'] == 'ROUTINE':
            border_color = "#4ecdc4"
        elif visit['triage'] == 'PREVENTIVE':
            border_color = "#45b7d1"
        else:
            border_color = "#96ceb4"
        
        with st.expander(f"🏥 {visit['date']} - {visit['hospital']} ({visit['triage']})"):
            # Visit overview
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.write(f"**🏥 Hospital:** {visit['hospital']}")
                st.write(f"**🏢 Department:** {visit['department']}")
                st.write(f"**👨‍⚕️ Doctor:** {visit['doctor']}")
                st.write(f"**📋 Visit Type:** {visit['visit_type']}")
            
            with col2:
                st.write(f"**💰 Cost:** {visit['cost']}")
                if 'insurance' in visit:
                    st.write(f"**🛡️ Insurance:** {visit['insurance']}")
                if 'next_appointment' in visit:
                    st.write(f"**📅 Next Visit:** {visit['next_appointment']}")
            
            with col3:
                st.write(f"**🚨 Triage:** {visit['triage']}")
                if 'outcome' in visit:
                    st.write(f"**✅ Outcome:** {visit['outcome']}")
                if 'follow_up' in visit:
                    st.write(f"**📋 Follow-up:** {visit['follow_up']}")
            
            st.markdown("---")
            
            # Clinical details
            col1, col2 = st.columns(2)
            
            with col1:
                st.write("**🗣️ Chief Complaint:**")
                st.write(visit['complaint'])
                
                st.write("**🔍 Symptoms:**")
                for symptom in visit['symptoms']:
                    st.write(f"• {symptom}")
                
                st.write("**🩺 Vital Signs:**")
                for sign, value in visit['vital_signs'].items():
                    st.write(f"• **{sign}:** {value}")
            
            with col2:
                st.write("**🎯 Diagnosis:**")
                st.write(visit['diagnosis'])
                
                st.write("**💊 Treatment:**")
                for treatment in visit['treatment']:
                    st.write(f"• {treatment}")
                
                if 'procedures' in visit:
                    st.write("**🔬 Procedures:**")
                    for procedure in visit['procedures']:
                        st.write(f"• {procedure}")
            
            # Lab results
            if 'lab_results' in visit:
                st.write("**🧪 Laboratory Results:**")
                col1, col2, col3 = st.columns(3)
                
                items = list(visit['lab_results'].items())
                for i, (test, result) in enumerate(items):
                    with [col1, col2, col3][i % 3]:
                        st.write(f"**{test}:** {result}")
    
    # Visit analytics
    st.markdown("---")
    st.subheader("📊 Visit Analytics")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🏥 Hospitals Visited:**")
        hospitals = ["Nairobi General Hospital (8 visits)", 
                    "Kenyatta National Hospital (6 visits)",
                    "Aga Khan Hospital (4 visits)",
                    "Westlands Health Centre (3 visits)",
                    "MP Shah Hospital (2 visits)"]
        for hospital in hospitals:
            st.write(f"• {hospital}")
    
    with col2:
        st.write("**👨‍⚕️ Healthcare Providers:**")
        providers = ["Dr. Mary Wanjiku - Internal Medicine (8 visits)",
                    "Dr. Sarah Muthoni - Endocrinology (4 visits)", 
                    "Dr. Ahmed Hassan - Cardiology (3 visits)",
                    "Dr. James Kiprotich - Emergency (2 visits)",
                    "Nurse Peter Otieno - Preventive Care (6 visits)"]
        for provider in providers:
            st.write(f"• {provider}")
    
    # Cost analysis
    st.markdown("---")
    st.subheader("💰 Healthcare Cost Analysis")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Total Healthcare Costs", "KES 89,400", "Last 12 months")
        st.write("**Breakdown:**")
        st.write("• Consultations: KES 45,200")
        st.write("• Medications: KES 28,800")
        st.write("• Lab tests: KES 15,400")
    
    with col2:
        st.metric("Insurance Coverage", "74%", "Average across visits")
        st.write("**Coverage by Type:**")
        st.write("• NHIF: 70% average")
        st.write("• Private: 80% average")
        st.write("• Out-of-pocket: KES 23,244")
    
    with col3:
        st.metric("Cost per Visit", "KES 3,887", "Average")
        st.write("**Visit Type Costs:**")
        st.write("• Emergency: KES 6,200 avg")
        st.write("• Specialist: KES 8,500 avg")
        st.write("• Routine: KES 2,100 avg")

def show_patient_sharing_options():
    """Enhanced patient sharing interface with advanced security features"""
    
    st.subheader("🔐 Advanced Medical Record Sharing")
    
    st.info("🛡️ **Your Privacy is Protected:** All sharing uses military-grade encryption and temporary access codes. You maintain complete control over who sees your data and for how long.")
    
    # Quick sharing options
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 🔢 Generate Secure Access Code")
        st.write("Create a temporary code for healthcare providers")
        
        # Access level selection
        access_level = st.selectbox(
            "Select access level:",
            ["Full Medical History", "Current Visit Only", "Emergency Info Only", "Specific Conditions Only"],
            help="Choose what information the provider can access"
        )
        
        # Duration selection
        duration = st.selectbox(
            "Access duration:",
            ["1 hour", "4 hours", "24 hours", "48 hours", "1 week"],
            index=2,
            help="How long the access code remains valid"
        )
        
        if st.button("🔢 Generate Secure Code", type="primary"):
            import random
            access_code = f"{random.randint(100000, 999999)}"
            
            st.markdown(f"""
            <div style="background: linear-gradient(135deg, #e8f5e8, #c8e6c9); 
                        padding: 20px; border-radius: 15px; text-align: center; 
                        border: 2px solid #4CAF50; margin: 15px 0;">
                <h2 style="color: #2E7D32; margin: 0;">🔐 Access Code</h2>
                <h1 style="color: #1B5E20; font-size: 48px; margin: 10px 0; 
                           font-family: monospace; letter-spacing: 8px;">{access_code}</h1>
                <p style="color: #666; margin: 5px 0;"><strong>Access Level:</strong> {access_level}</p>
                <p style="color: #666; margin: 5px 0;"><strong>Valid for:</strong> {duration}</p>
                <p style="color: #666; margin: 5px 0;"><strong>Patient:</strong> John Doe (ML-NBO-DEMO1)</p>
                <p style="color: #d32f2f; margin: 10px 0; font-size: 12px;">
                    ⚠️ Share this code only with authorized healthcare providers
                </p>
            </div>
            """, unsafe_allow_html=True)
            
            st.success(f"✅ Secure access code generated! Valid for {duration}")
            
            # Show what's included
            st.write("**📋 This code provides access to:**")
            if access_level == "Full Medical History":
                st.write("• Complete medical history and all visits")
                st.write("• Current medications and allergies")
                st.write("• Lab results and vital signs trends")
                st.write("• Family medical history")
                st.write("• Emergency contact information")
            elif access_level == "Current Visit Only":
                st.write("• Today's consultation information only")
                st.write("• Current symptoms and vital signs")
                st.write("• Active medications")
                st.write("• Critical allergies")
            elif access_level == "Emergency Info Only":
                st.write("• Critical allergies and medical alerts")
                st.write("• Emergency contact information")
                st.write("• Current medications")
                st.write("• Blood type and critical conditions")
            else:
                st.write("• Selected medical conditions only")
                st.write("• Related medications and treatments")
                st.write("• Relevant lab results")
    
    with col2:
        st.markdown("### 📱 QR Code Sharing")
        st.write("Generate QR code for instant, secure access")
        
        # QR code options
        qr_type = st.selectbox(
            "QR Code Type:",
            ["Emergency Access", "Full Records", "Appointment Check-in", "Prescription Pickup"],
            help="Different QR codes for different purposes"
        )
        
        if st.button("📱 Generate QR Code", type="primary"):
            # Generate actual QR code
            try:
                import qrcode
                from io import BytesIO
                import base64
                import json
                from datetime import datetime, timedelta
                
                # Set permissions based on QR type
                permissions = {
                    "Emergency Access": {"emergency_info": True, "allergies": True, "medications": True},
                    "Full Records": {"full_access": True},
                    "Appointment Check-in": {"basic_info": True, "appointment_history": True},
                    "Prescription Pickup": {"medications": True, "prescriptions": True}
                }.get(qr_type, {"basic_info": True})
                
                # Create QR data
                qr_data = {
                    "medilink_id": "ML-NBO-DEMO1",
                    "access_code": access_code,
                    "type": qr_type,
                    "permissions": permissions,
                    "expires": expiry_time,
                    "generated_at": datetime.now().isoformat(),
                    "system": "AfiCare MediLink"
                }
                
                # Generate QR code
                qr = qrcode.QRCode(
                    version=1,
                    error_correction=qrcode.constants.ERROR_CORRECT_L,
                    box_size=10,
                    border=4,
                )
                qr.add_data(json.dumps(qr_data))
                qr.make(fit=True)
                
                # Create image
                img = qr.make_image(fill_color="black", back_color="white")
                img_buffer = BytesIO()
                img.save(img_buffer, format='PNG')
                img_b64 = base64.b64encode(img_buffer.getvalue()).decode()
                
                st.success("🎯 QR Code Generated!")
                
                # Display actual QR code
                st.markdown(f"""
                <div style="background: white; padding: 20px; border-radius: 15px; 
                            text-align: center; border: 2px solid #2196F3; margin: 15px 0;">
                    <h3 style="color: #1976D2; margin: 0 0 15px 0;">📱 {qr_type} QR Code</h3>
                    <img src="data:image/png;base64,{img_b64}" style="width: 200px; height: 200px; border-radius: 10px;"/>
                    <p style="margin: 15px 0 5px 0; color: #1976D2; font-weight: bold;">
                        Access Code: {access_code}
                    </p>
                    <p style="color: #666; margin: 5px 0; font-size: 12px;">
                        Valid until: {expiry_time} | Patient: ML-NBO-DEMO1
                    </p>
                    <p style="color: #d32f2f; margin: 5px 0; font-size: 11px;">
                        ⚠️ Show only to authorized healthcare staff
                    </p>
                </div>
                """, unsafe_allow_html=True)
                
            except ImportError:
                st.error("QR code library not installed. Run: pip install qrcode[pil]")
                # Show fallback placeholder
                st.markdown(f"""
                <div style="background: white; padding: 20px; border-radius: 15px; 
                            text-align: center; border: 2px solid #2196F3; margin: 15px 0;">
                    <h3 style="color: #1976D2; margin: 0 0 15px 0;">📱 {qr_type} QR Code</h3>
                    <div style="width: 200px; height: 200px; background: #f0f0f0; 
                               margin: 0 auto; border-radius: 10px; display: flex; 
                               align-items: center; justify-content: center; 
                               font-size: 14px; color: #666;">
                        QR Code<br/>
                        (Install qrcode library)
                    </div>
                    <p style="color: #666; margin: 15px 0 5px 0; font-size: 12px;">
                        Valid for 24 hours | Patient: ML-NBO-DEMO1
                    </p>
                    <p style="color: #d32f2f; margin: 5px 0; font-size: 11px;">
                        ⚠️ Show only to authorized healthcare staff
                    </p>
                </div>
                """, unsafe_allow_html=True)
            except Exception as e:
                st.error(f"Failed to generate QR code: {str(e)}")
                st.info("Using fallback display")
                # Show fallback placeholder
                st.markdown(f"""
                <div style="background: white; padding: 20px; border-radius: 15px; 
                            text-align: center; border: 2px solid #2196F3; margin: 15px 0;">
                    <h3 style="color: #1976D2; margin: 0 0 15px 0;">📱 {qr_type} QR Code</h3>
                    <div style="width: 200px; height: 200px; background: #f0f0f0; 
                               margin: 0 auto; border-radius: 10px; display: flex; 
                               align-items: center; justify-content: center; 
                               font-size: 14px; color: #666;">
                        QR Code<br/>
                        (Scan with phone)
                    </div>
                    <p style="color: #666; margin: 15px 0 5px 0; font-size: 12px;">
                        Valid for 24 hours | Patient: ML-NBO-DEMO1
                    </p>
                    <p style="color: #d32f2f; margin: 5px 0; font-size: 11px;">
                        ⚠️ Show only to authorized healthcare staff
                    </p>
                </div>
                """, unsafe_allow_html=True)
            
            st.info("📱 **How to use:** Show this QR code to hospital staff. They can scan it with their medical app to instantly access your records.")
    
    # Active sharing sessions
    st.markdown("---")
    st.subheader("🔄 Active Sharing Sessions")
    
    active_sessions = [
        {
            "provider": "Dr. Mary Wanjiku",
            "hospital": "Nairobi General Hospital",
            "access_level": "Full Medical History",
            "granted": "2 hours ago",
            "expires": "22 hours",
            "status": "Active"
        },
        {
            "provider": "Pharmacy - Westlands",
            "hospital": "Westlands Medical Centre",
            "access_level": "Prescription Only",
            "granted": "1 day ago",
            "expires": "6 hours",
            "status": "Active"
        }
    ]
    
    if active_sessions:
        for session in active_sessions:
            col1, col2, col3 = st.columns([3, 2, 1])
            
            with col1:
                st.write(f"**👨‍⚕️ {session['provider']}**")
                st.write(f"🏥 {session['hospital']}")
                st.write(f"📋 Access: {session['access_level']}")
            
            with col2:
                st.write(f"**⏰ Granted:** {session['granted']}")
                st.write(f"**⏳ Expires:** {session['expires']}")
                st.write(f"**📊 Status:** {session['status']}")
            
            with col3:
                if st.button("🚫 Revoke", key=f"revoke_{session['provider']}"):
                    st.success(f"✅ Access revoked for {session['provider']}")
                    st.rerun()
    else:
        st.info("ℹ️ No active sharing sessions")
    
    # Sharing history
    st.markdown("---")
    st.subheader("📜 Sharing History (Last 30 Days)")
    
    sharing_history = [
        {"date": "Jan 28, 2024", "provider": "Dr. Mary Wanjiku", "access": "Full History", "duration": "4 hours"},
        {"date": "Jan 25, 2024", "provider": "Lab Technician", "access": "Lab Results Only", "duration": "1 hour"},
        {"date": "Jan 20, 2024", "provider": "Pharmacy Staff", "access": "Prescriptions Only", "duration": "2 hours"},
        {"date": "Jan 15, 2024", "provider": "Emergency Doctor", "access": "Emergency Info", "duration": "24 hours"},
        {"date": "Jan 10, 2024", "provider": "Dr. Sarah Muthoni", "access": "Diabetes Records", "duration": "1 week"}
    ]
    
    for history in sharing_history:
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.write(f"**📅 {history['date']}**")
        
        with col2:
            st.write(f"👨‍⚕️ {history['provider']}")
        
        with col3:
            st.write(f"📋 {history['access']}")
        
        with col4:
            st.write(f"⏱️ {history['duration']}")
    
    # Privacy settings
    st.markdown("---")
    st.subheader("🛡️ Privacy & Security Settings")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🔒 Access Control Settings**")
        
        auto_expire = st.checkbox("Auto-expire codes after 24 hours", value=True)
        require_photo_id = st.checkbox("Require photo ID verification", value=True)
        notify_access = st.checkbox("Notify me when records are accessed", value=True)
        emergency_override = st.checkbox("Allow emergency access when unconscious", value=True)
        
    with col2:
        st.write("**📱 Notification Preferences**")
        
        sms_notifications = st.checkbox("SMS notifications", value=True)
        email_notifications = st.checkbox("Email notifications", value=True)
        app_notifications = st.checkbox("In-app notifications", value=True)
        
        st.write("**📞 Emergency Contact**")
        emergency_contact = st.text_input("Emergency Contact", value="Jane Doe (+254712345679)")
    
    if st.button("💾 Save Privacy Settings", type="primary"):
        st.success("✅ Privacy settings saved successfully!")
        st.info("🔐 Your medical data remains secure and under your complete control.")

def show_patient_settings():
    """Enhanced patient settings with comprehensive health management"""

    st.subheader("⚙️ Comprehensive Health Management Settings")

    # Personal Information Management
    st.markdown("### 👤 Personal Information")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.text_input("Full Name", value="John Doe", help="Legal name as it appears on ID")
        st.text_input("Phone Number", value="+254712345678", help="Primary contact number")
        st.text_input("Email Address", value="john.doe@example.com", help="For notifications and reports")
        st.selectbox("Preferred Language", ["English", "Swahili", "Luganda"], help="Language for medical communications")
        
    with col2:
        st.date_input("Date of Birth", help="Used for age-specific medical recommendations")
        st.selectbox("Gender", ["Male", "Female", "Other"], help="Important for medical assessments")
        st.text_input("National ID", value="12345678", help="For identity verification")
        st.text_input("Occupation", value="Software Engineer", help="May affect health risks and recommendations")

    # Medical Profile Settings
    st.markdown("---")
    st.markdown("### 🩺 Medical Profile Settings")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🩸 Blood Information**")
        blood_type = st.selectbox("Blood Type", ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"], index=0)
        rh_factor = st.selectbox("Rh Factor", ["Positive", "Negative"], index=0)
        
        st.write("**⚠️ Critical Allergies**")
        allergies = st.text_area("Known Allergies", 
                                value="Penicillin - Severe reaction (rash, difficulty breathing)\nSulfa drugs - Moderate reaction (skin rash)\nShellfish - Mild reaction (hives)",
                                help="List all known allergies with severity")
        
        st.write("**🏥 Medical Conditions**")
        conditions = st.text_area("Chronic Conditions",
                                 value="Type 2 Diabetes Mellitus (diagnosed 2019)\nEssential Hypertension (diagnosed 2020)\nMild Asthma (childhood, well-controlled)",
                                 help="List ongoing medical conditions")
    
    with col2:
        st.write("**💊 Current Medications**")
        medications = st.text_area("Active Medications",
                                  value="Metformin XR 1000mg - Once daily (morning)\nLisinopril 10mg - Once daily (morning)\nAtorvastatin 20mg - Once daily (evening)\nAspirin 81mg - Once daily (morning)",
                                  help="Include dosage and frequency")
        
        st.write("**🚫 Drug Intolerances**")
        intolerances = st.text_area("Drug Intolerances",
                                   value="Codeine - Causes severe nausea\nIbuprofen - Stomach upset",
                                   help="Medications that cause adverse reactions")
        
        st.write("**🧬 Family History**")
        family_history = st.text_area("Family Medical History",
                                     value="Father: Type 2 Diabetes, Hypertension\nMother: Hypertension, Arthritis\nPaternal Grandfather: Heart disease\nMaternal Grandmother: Stroke",
                                     help="Important for risk assessment")

    # Emergency Information
    st.markdown("---")
    st.markdown("### 🚨 Emergency Information")

    col1, col2 = st.columns(2)

    with col1:
        st.write("**👥 Emergency Contacts**")
        emergency_contact_1 = st.text_input("Primary Emergency Contact", value="Jane Doe (Wife)")
        emergency_phone_1 = st.text_input("Primary Contact Phone", value="+254712345679")
        emergency_contact_2 = st.text_input("Secondary Emergency Contact", value="Peter Doe (Brother)")
        emergency_phone_2 = st.text_input("Secondary Contact Phone", value="+254712345680")
        
    with col2:
        st.write("**🏥 Preferred Hospital**")
        preferred_hospital = st.selectbox("Preferred Hospital", 
                                        ["Nairobi General Hospital", "Kenyatta National Hospital", "Aga Khan Hospital", "MP Shah Hospital"])
        preferred_doctor = st.text_input("Preferred Doctor", value="Dr. Mary Wanjiku")
        
        st.write("**🛡️ Insurance Information**")
        insurance_provider = st.selectbox("Insurance Provider", ["NHIF", "AAR", "Jubilee", "CIC", "Other"])
        insurance_number = st.text_input("Insurance Number", value="NHIF-123456789")

    # Privacy & Security Settings
    st.markdown("---")
    st.markdown("### 🔒 Privacy & Security Settings")

    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🔐 Access Control**")
        emergency_access = st.checkbox("Allow emergency access when unconscious", value=True, 
                                     help="Allows medical staff to access critical info in emergencies")
        research_data = st.checkbox("Allow anonymized data for medical research", value=False,
                                  help="Help improve healthcare through anonymous data sharing")
        ai_recommendations = st.checkbox("Enable AI health recommendations", value=True,
                                       help="Get personalized health insights from AI analysis")
        
        st.write("**📱 Notification Preferences**")
        sms_notifications = st.checkbox("SMS notifications", value=True)
        email_notifications = st.checkbox("Email notifications", value=True)
        medication_reminders = st.checkbox("Medication reminders", value=True)
        appointment_reminders = st.checkbox("Appointment reminders", value=True)
        
    with col2:
        st.write("**🔄 Data Sharing Preferences**")
        auto_share_emergency = st.checkbox("Auto-share emergency info with first responders", value=True)
        share_with_specialists = st.checkbox("Auto-share relevant history with specialists", value=True)
        pharmacy_access = st.checkbox("Allow pharmacy access to prescriptions", value=True)
        
        st.write("**⏰ Session Settings**")
        session_timeout = st.selectbox("Auto-logout after:", ["15 minutes", "30 minutes", "1 hour", "2 hours"], index=1)
        require_biometric = st.checkbox("Require biometric authentication", value=False)

    # Health Goals and Preferences
    st.markdown("---")
    st.markdown("### 🎯 Health Goals & Preferences")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🏃‍♂️ Fitness Goals**")
        target_weight = st.number_input("Target Weight (kg)", value=72.0, min_value=40.0, max_value=200.0)
        exercise_goal = st.selectbox("Exercise Goal", ["3x per week", "4x per week", "5x per week", "Daily"])
        activity_level = st.selectbox("Current Activity Level", ["Sedentary", "Lightly Active", "Moderately Active", "Very Active"])
        
        st.write("**🍎 Dietary Preferences**")
        dietary_restrictions = st.multiselect("Dietary Restrictions", 
                                            ["None", "Vegetarian", "Vegan", "Halal", "Kosher", "Gluten-free", "Dairy-free"])
        
    with col2:
        st.write("**🎯 Health Targets**")
        bp_target = st.text_input("Blood Pressure Target", value="<130/80 mmHg")
        hba1c_target = st.text_input("HbA1c Target", value="<7.0%")
        cholesterol_target = st.text_input("Cholesterol Target", value="<180 mg/dL")
        
        st.write("**📊 Monitoring Preferences**")
        daily_bp_monitoring = st.checkbox("Daily BP monitoring reminders", value=True)
        weekly_weight_tracking = st.checkbox("Weekly weight tracking", value=True)
        monthly_lab_reminders = st.checkbox("Monthly lab test reminders", value=True)

    # Advanced Settings
    st.markdown("---")
    st.markdown("### ⚙️ Advanced Settings")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🔄 Data Backup & Export**")
        auto_backup = st.checkbox("Automatic data backup", value=True)
        backup_frequency = st.selectbox("Backup Frequency", ["Daily", "Weekly", "Monthly"])
        
        if st.button("📤 Export My Complete Medical Records"):
            st.success("✅ Export initiated! You'll receive a secure download link via email.")
            st.info("📧 Check your email for the download link (expires in 24 hours)")
        
        if st.button("💾 Create Manual Backup"):
            st.success("✅ Manual backup created successfully!")
            
    with col2:
        st.write("**🔧 System Preferences**")
        theme = st.selectbox("App Theme", ["Light", "Dark", "Auto"])
        units = st.selectbox("Measurement Units", ["Metric (kg, cm)", "Imperial (lbs, ft)"])
        date_format = st.selectbox("Date Format", ["DD/MM/YYYY", "MM/DD/YYYY", "YYYY-MM-DD"])
        
        st.write("**🔔 Alert Settings**")
        critical_alerts = st.checkbox("Critical health alerts", value=True)
        medication_interactions = st.checkbox("Drug interaction warnings", value=True)
        abnormal_vitals = st.checkbox("Abnormal vital signs alerts", value=True)

    # Save Settings
    st.markdown("---")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("💾 Save All Settings", type="primary"):
            st.success("✅ All settings saved successfully!")
            st.info("🔐 Your medical data and preferences have been securely updated.")
    
    with col2:
        if st.button("🔄 Reset to Defaults"):
            st.warning("⚠️ This will reset all settings to default values.")
            if st.button("Confirm Reset"):
                st.success("✅ Settings reset to defaults")
    
    with col3:
        if st.button("📋 View Privacy Policy"):
            st.info("📄 Privacy Policy: Your data is encrypted and never shared without your explicit consent.")

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
    """New consultation interface with Hybrid AI"""

    st.subheader("New Patient Consultation")

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
        
        # AI Backend selection
        use_hybrid = st.checkbox("Use Hybrid AI (LLM + Rules)", value=True,
                                 help="Combines rule-based engine with LLM for better analysis")

        if st.button("Analyze with AI", type="primary"):
            # Use hybrid AI if available and selected
            use_llm = use_hybrid and HYBRID_AI_AVAILABLE
            
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
                with st.spinner("Analyzing..."):
                    try:
                        # Use Hybrid AI if selected and available
                        if use_llm and HYBRID_AI_AVAILABLE:
                            result = run_hybrid_analysis(patient_data, use_llm=True)
                        else:
                            # Fallback to standard medical AI
                            medical_ai = get_medical_ai()
                            result = medical_ai.conduct_consultation(patient_data)

                        # Display results
                        st.success("Analysis Complete!")

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

def show_maternal_health_dashboard():
    """Comprehensive maternal health dashboard for women"""
    
    st.subheader("🤱 Maternal Health Dashboard")
    
    # Pregnancy Status Check
    col1, col2, col3 = st.columns(3)
    
    with col1:
        pregnancy_status = st.selectbox(
            "Current Status:",
            ["Not Pregnant", "Trying to Conceive", "Pregnant", "Postpartum", "Breastfeeding"],
            help="Select your current maternal health status"
        )
    
    with col2:
        if pregnancy_status == "Pregnant":
            weeks_pregnant = st.number_input("Weeks Pregnant:", min_value=1, max_value=42, value=20)
            trimester = "First" if weeks_pregnant <= 12 else "Second" if weeks_pregnant <= 28 else "Third"
            st.write(f"**Trimester:** {trimester}")
        elif pregnancy_status == "Postpartum":
            weeks_postpartum = st.number_input("Weeks Postpartum:", min_value=0, max_value=52, value=6)
    
    with col3:
        if pregnancy_status in ["Pregnant", "Postpartum", "Breastfeeding"]:
            due_date = st.date_input("Due Date/Birth Date:")
    
    # Display relevant dashboard based on status
    if pregnancy_status == "Trying to Conceive":
        show_preconception_care()
    elif pregnancy_status == "Pregnant":
        show_antenatal_care(weeks_pregnant if 'weeks_pregnant' in locals() else 20)
    elif pregnancy_status == "Postpartum":
        show_postpartum_care(weeks_postpartum if 'weeks_postpartum' in locals() else 6)
    elif pregnancy_status == "Breastfeeding":
        show_breastfeeding_support()
    else:
        show_general_reproductive_health()

def show_preconception_care():
    """Preconception care dashboard"""
    
    st.markdown("### 🌱 Preconception Care")
    
    # Health optimization checklist
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🎯 Preconception Checklist**")
        
        checklist_items = [
            "Taking folic acid 400mcg daily",
            "Maintaining healthy weight (BMI 18.5-24.9)",
            "Regular exercise routine",
            "Balanced nutrition",
            "No smoking or alcohol",
            "Up-to-date vaccinations",
            "Managing chronic conditions",
            "Dental health check"
        ]
        
        completed_items = 0
        for item in checklist_items:
            if st.checkbox(item, key=f"precon_{item}"):
                completed_items += 1
        
        progress = completed_items / len(checklist_items)
        st.progress(progress)
        st.write(f"**Progress:** {completed_items}/{len(checklist_items)} items completed ({progress:.0%})")
    
    with col2:
        st.write("**📊 Health Metrics**")
        
        # Key metrics for preconception
        current_weight = st.number_input("Current Weight (kg):", value=65.0)
        height = st.number_input("Height (cm):", value=165.0)
        bmi = current_weight / ((height/100) ** 2)
        
        st.metric("BMI", f"{bmi:.1f}", help="Optimal range: 18.5-24.9")
        
        if bmi < 18.5:
            st.warning("⚠️ Underweight - Consider nutritional counseling")
        elif bmi > 24.9:
            st.warning("⚠️ Overweight - Consider weight management")
        else:
            st.success("✅ Healthy weight range")
        
        # Cycle tracking
        st.write("**📅 Menstrual Cycle Tracking**")
        cycle_length = st.number_input("Average cycle length (days):", value=28, min_value=21, max_value=35)
        last_period = st.date_input("Last menstrual period:")
        
        if cycle_length:
            import datetime
            next_ovulation = last_period + datetime.timedelta(days=cycle_length-14)
            st.write(f"**Estimated next ovulation:** {next_ovulation}")
    
    # Recommendations
    st.markdown("---")
    st.subheader("💡 Personalized Recommendations")
    
    recommendations = [
        "🍃 **Folic Acid:** Start taking 400mcg daily at least 1 month before conception",
        "🥗 **Nutrition:** Focus on folate-rich foods (leafy greens, citrus, beans)",
        "🏃‍♀️ **Exercise:** Maintain regular moderate exercise (150 min/week)",
        "🚭 **Lifestyle:** Avoid smoking, alcohol, and limit caffeine (<200mg/day)",
        "💊 **Medications:** Review all medications with healthcare provider",
        "🩺 **Health Screening:** Complete preconception health assessment",
        "🧬 **Genetic Counseling:** Consider if family history of genetic conditions"
    ]
    
    for rec in recommendations:
        st.info(rec)

def show_antenatal_care(weeks_pregnant):
    """Antenatal care dashboard"""
    
    st.markdown(f"### 🤰 Antenatal Care - Week {weeks_pregnant}")
    
    # Pregnancy progress
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Gestational Age", f"{weeks_pregnant} weeks")
        trimester = "First" if weeks_pregnant <= 12 else "Second" if weeks_pregnant <= 28 else "Third"
        st.metric("Trimester", trimester)
    
    with col2:
        progress = weeks_pregnant / 40
        st.metric("Pregnancy Progress", f"{progress:.0%}")
        st.progress(progress)
    
    with col3:
        weeks_remaining = 40 - weeks_pregnant
        st.metric("Weeks to Due Date", f"{weeks_remaining} weeks")
    
    # Danger signs
    st.markdown("---")
    st.error("🚨 **DANGER SIGNS - Contact Healthcare Provider Immediately:**")
    
    danger_signs = [
        "Severe headache that won't go away",
        "Changes in vision (blurry, seeing spots)",
        "Severe swelling of face, hands, or feet",
        "Severe abdominal pain",
        "Vaginal bleeding",
        "Fluid leaking from vagina",
        "Severe nausea and vomiting",
        "Fever over 38°C",
        "Decreased or no fetal movement (after 20 weeks)"
    ]
    
    col1, col2 = st.columns(2)
    
    with col1:
        for i, sign in enumerate(danger_signs[:5]):
            st.write(f"• {sign}")
    
    with col2:
        for sign in danger_signs[5:]:
            st.write(f"• {sign}")

def show_postpartum_care(weeks_postpartum):
    """Postpartum care dashboard"""
    
    st.markdown(f"### 🤱 Postpartum Care - Week {weeks_postpartum}")
    
    # Recovery progress
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Weeks Postpartum", weeks_postpartum)
        
    with col2:
        recovery_phase = "Immediate" if weeks_postpartum <= 1 else "Early" if weeks_postpartum <= 6 else "Extended"
        st.metric("Recovery Phase", recovery_phase)
    
    with col3:
        if weeks_postpartum <= 6:
            st.metric("Until 6-week Check", f"{6-weeks_postpartum} weeks")
        else:
            st.metric("Post 6-week Check", "✅ Complete")

def show_breastfeeding_support():
    """Breastfeeding support dashboard"""
    
    st.markdown("### 🤱 Breastfeeding Support")
    
    st.info("💡 **Lactation Support Available** - Consider consulting a lactation specialist for any feeding challenges")

def show_womens_health_dashboard():
    """Comprehensive women's health dashboard"""
    
    st.subheader("👩‍⚕️ Women's Health Dashboard")
    
    # Health screening overview
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Last Pap Smear", "8 months ago", "Due in 4 months")
    
    with col2:
        st.metric("Last Mammogram", "14 months ago", "Overdue")
    
    with col3:
        st.metric("Bone Density", "Normal", "T-score: -0.5")
    
    with col4:
        st.metric("Menstrual Cycle", "Regular", "28-day cycle")
    
    # Women's health conditions monitoring
    st.markdown("---")
    st.subheader("🩺 Reproductive Health Conditions")
    
    # PCOS Management
    with st.expander("🔍 PCOS (Polycystic Ovary Syndrome) Management"):
        pcos_diagnosed = st.checkbox("Diagnosed with PCOS")
        
        if pcos_diagnosed:
            col1, col2 = st.columns(2)
            
            with col1:
                st.write("**Current Symptoms:**")
                pcos_symptoms = st.multiselect("Select current symptoms:", [
                    "Irregular periods",
                    "Excessive hair growth",
                    "Acne",
                    "Weight gain",
                    "Hair loss",
                    "Difficulty conceiving"
                ])
                
                st.write("**Current Management:**")
                pcos_treatments = st.multiselect("Current treatments:", [
                    "Metformin",
                    "Birth control pills",
                    "Anti-androgen therapy",
                    "Lifestyle modifications",
                    "Fertility treatments"
                ])
            
            with col2:
                st.write("**Monitoring:**")
                last_glucose_test = st.date_input("Last glucose screening:")
                last_lipid_panel = st.date_input("Last lipid panel:")
                
                st.write("**Lifestyle Factors:**")
                exercise_frequency = st.selectbox("Exercise frequency:", ["Daily", "4-6x/week", "2-3x/week", "1x/week", "Rarely"])
                diet_type = st.selectbox("Diet approach:", ["Mediterranean", "Low-carb", "DASH", "Standard", "Other"])
                
                # PCOS risk assessment
                if len(pcos_symptoms) >= 3:
                    st.warning("⚠️ Multiple symptoms present - consider specialist consultation")
    
    # Endometriosis Management
    with st.expander("🩸 Endometriosis Management"):
        endo_diagnosed = st.checkbox("Diagnosed with Endometriosis")
        
        if endo_diagnosed:
            col1, col2 = st.columns(2)
            
            with col1:
                st.write("**Pain Assessment:**")
                menstrual_pain = st.slider("Menstrual pain (1-10):", 1, 10, 6)
                pelvic_pain = st.slider("Chronic pelvic pain (1-10):", 1, 10, 4)
                pain_during_intercourse = st.slider("Pain during intercourse (1-10):", 1, 10, 3)
                
                if menstrual_pain >= 7 or pelvic_pain >= 6:
                    st.warning("⚠️ Severe pain levels - discuss pain management with specialist")
            
            with col2:
                st.write("**Current Treatment:**")
                endo_treatments = st.multiselect("Current treatments:", [
                    "NSAIDs for pain",
                    "Hormonal contraceptives",
                    "GnRH agonists",
                    "Progestin therapy",
                    "Previous surgery",
                    "Physical therapy"
                ])
                
                st.write("**Impact on Life:**")
                work_impact = st.selectbox("Impact on work/daily activities:", ["None", "Mild", "Moderate", "Severe"])
                fertility_concerns = st.checkbox("Fertility concerns")
    
    # Fibroids Management
    with st.expander("🫀 Uterine Fibroids Management"):
        fibroids_diagnosed = st.checkbox("Diagnosed with Uterine Fibroids")
        
        if fibroids_diagnosed:
            col1, col2 = st.columns(2)
            
            with col1:
                st.write("**Symptoms:**")
                fibroid_symptoms = st.multiselect("Current symptoms:", [
                    "Heavy menstrual bleeding",
                    "Prolonged periods",
                    "Pelvic pressure",
                    "Frequent urination",
                    "Constipation",
                    "Back pain",
                    "Pain during intercourse"
                ])
                
                bleeding_severity = st.selectbox("Menstrual bleeding:", ["Normal", "Heavy", "Very heavy", "Flooding"])
                
                if bleeding_severity in ["Very heavy", "Flooding"]:
                    st.error("🚨 Severe bleeding - monitor for anemia, consider urgent evaluation")
            
            with col2:
                st.write("**Monitoring:**")
                last_ultrasound = st.date_input("Last pelvic ultrasound:")
                hemoglobin_level = st.number_input("Last hemoglobin (g/dL):", value=12.0, min_value=6.0, max_value=18.0)
                
                if hemoglobin_level < 10:
                    st.error("🚨 Severe anemia - requires immediate attention")
                elif hemoglobin_level < 12:
                    st.warning("⚠️ Mild anemia - monitor and consider iron supplementation")
                
                st.write("**Treatment Options Discussed:**")
                fibroid_treatments = st.multiselect("Treatments considered/used:", [
                    "Watchful waiting",
                    "Hormonal therapy",
                    "Uterine artery embolization",
                    "Myomectomy",
                    "Hysterectomy"
                ])
    
    # Menstrual Health Tracking
    st.markdown("---")
    st.subheader("📅 Menstrual Health Tracking")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Cycle Information:**")
        cycle_regularity = st.selectbox("Cycle regularity:", ["Regular", "Irregular", "Absent", "Unpredictable"])
        average_cycle_length = st.number_input("Average cycle length (days):", value=28, min_value=21, max_value=45)
        period_duration = st.number_input("Period duration (days):", value=5, min_value=1, max_value=10)
        
        last_period = st.date_input("Last menstrual period:")
        
        if cycle_regularity == "Regular":
            import datetime
            next_period = last_period + datetime.timedelta(days=average_cycle_length)
            st.write(f"**Next expected period:** {next_period}")
    
    with col2:
        st.write("**Menstrual Symptoms:**")
        menstrual_symptoms = st.multiselect("Symptoms during menstruation:", [
            "Mild cramping",
            "Severe cramping",
            "Heavy bleeding",
            "Clotting",
            "Mood changes",
            "Breast tenderness",
            "Bloating",
            "Headaches",
            "Fatigue"
        ])
        
        if "Severe cramping" in menstrual_symptoms or "Heavy bleeding" in menstrual_symptoms:
            st.warning("⚠️ Consider evaluation for underlying conditions")
        
        pms_severity = st.selectbox("PMS severity:", ["None", "Mild", "Moderate", "Severe"])
        
        if pms_severity == "Severe":
            st.info("💡 Consider discussing PMDD evaluation with healthcare provider")

def show_general_reproductive_health():
    """General reproductive health information"""
    
    st.markdown("### 🌸 General Reproductive Health")
    
    st.info("💡 **Regular Health Maintenance:** Even when not pregnant or trying to conceive, maintaining reproductive health is important for overall wellbeing.")
    
    # Basic reproductive health checklist
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**🗓️ Preventive Care Schedule:**")
        st.write("• Annual gynecological exam")
        st.write("• Pap smear (every 3-5 years)")
        st.write("• STI screening as appropriate")
        st.write("• Breast self-examination monthly")
        st.write("• Clinical breast exam annually")
    
    with col2:
        st.write("**🩺 Health Monitoring:**")
        st.write("• Track menstrual cycles")
        st.write("• Monitor any changes in periods")
        st.write("• Note any pelvic pain or discomfort")
        st.write("• Maintain healthy weight")
        st.write("• Regular exercise and good nutrition")

# Main app logic
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        show_dashboard()

if __name__ == "__main__":
    main()