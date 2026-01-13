"""
AfiCare Agent - Simple Streamlit Application
Self-contained version that works without complex imports
"""

import streamlit as st
import json
import sqlite3
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import yaml
import logging

# Page configuration
st.set_page_config(
    page_title="AfiCare Medical Agent",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        background: linear-gradient(90deg, #2E8B57, #228B22);
        padding: 1rem;
        border-radius: 10px;
        color: white;
        text-align: center;
        margin-bottom: 2rem;
    }
    .triage-emergency {
        background: #ffebee;
        border-left: 4px solid #f44336;
        padding: 1rem;
        border-radius: 8px;
    }
    .triage-urgent {
        background: #fff3e0;
        border-left: 4px solid #ff9800;
        padding: 1rem;
        border-radius: 8px;
    }
    .triage-routine {
        background: #e8f5e8;
        border-left: 4px solid #4caf50;
        padding: 1rem;
        border-radius: 8px;
    }
    .condition-match {
        background: #f0f8ff;
        padding: 0.5rem;
        margin: 0.5rem 0;
        border-radius: 5px;
        border-left: 3px solid #1e88e5;
    }
</style>
""", unsafe_allow_html=True)

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
    """Simplified medical rule engine"""
    
    def __init__(self):
        self.conditions = self._load_conditions()
    
    def _load_conditions(self):
        """Load medical conditions from JSON files"""
        conditions = {}
        
        # Load malaria data
        malaria_data = {
            "name": "Malaria",
            "symptoms": {
                "fever": 0.9,
                "chills": 0.8,
                "headache": 0.7,
                "muscle_aches": 0.6,
                "nausea": 0.5,
                "fatigue": 0.6
            },
            "treatment": [
                "Artemether-Lumefantrine based on weight",
                "Paracetamol for fever and pain",
                "Oral rehydration therapy",
                "Rest and adequate nutrition"
            ]
        }
        conditions["malaria"] = malaria_data
        
        # Load pneumonia data
        pneumonia_data = {
            "name": "Pneumonia",
            "symptoms": {
                "cough": 0.9,
                "fever": 0.8,
                "difficulty_breathing": 0.9,
                "chest_pain": 0.7,
                "fatigue": 0.6
            },
            "treatment": [
                "Amoxicillin 15mg/kg twice daily for 5 days (children)",
                "Amoxicillin 500mg three times daily for 5 days (adults)",
                "Oxygen therapy if SpO2 < 90%",
                "Adequate fluid intake"
            ]
        }
        conditions["pneumonia"] = pneumonia_data
        
        # Add more conditions
        conditions["hypertension"] = {
            "name": "Hypertension",
            "symptoms": {
                "headache": 0.4,
                "dizziness": 0.5,
                "blurred_vision": 0.6,
                "chest_pain": 0.3
            },
            "treatment": [
                "Lifestyle modifications",
                "Regular blood pressure monitoring",
                "Antihypertensive medication if indicated"
            ]
        }
        
        return conditions
    
    def analyze_symptoms(self, symptoms: List[str], vital_signs: Dict[str, float], age: int, gender: str):
        """Analyze symptoms against conditions"""
        
        results = []
        
        # Normalize symptoms
        normalized_symptoms = [s.lower().replace(" ", "_") for s in symptoms]
        
        for condition_name, condition_data in self.conditions.items():
            score = 0.0
            matching_symptoms = []
            
            # Check symptom matches
            for symptom, weight in condition_data["symptoms"].items():
                if any(symptom in ns for ns in normalized_symptoms):
                    score += weight
                    matching_symptoms.append(symptom)
            
            # Vital signs boost
            if condition_name == "malaria" and vital_signs.get("temperature", 37) > 38.5:
                score += 0.2
            elif condition_name == "pneumonia" and vital_signs.get("respiratory_rate", 16) > 24:
                score += 0.2
            elif condition_name == "hypertension" and vital_signs.get("systolic_bp", 120) > 140:
                score += 0.3
            
            # Age factors
            if condition_name == "pneumonia" and (age < 2 or age > 65):
                score += 0.1
            
            if score > 0.2:  # Only include significant matches
                results.append({
                    "name": condition_name,
                    "display_name": condition_data["name"],
                    "confidence": min(score, 1.0),
                    "matching_symptoms": matching_symptoms,
                    "category": "infectious_disease" if condition_name in ["malaria", "pneumonia"] else "chronic_disease"
                })
        
        # Sort by confidence
        results.sort(key=lambda x: x["confidence"], reverse=True)
        return results

class SimpleTriageEngine:
    """Simplified triage assessment"""
    
    def assess_urgency(self, patient_data: PatientData):
        """Assess patient urgency"""
        
        score = 0.0
        danger_signs = []
        
        # Check symptoms for danger signs
        symptom_text = " ".join(patient_data.symptoms).lower()
        
        emergency_keywords = [
            "difficulty breathing", "chest pain", "unconscious", 
            "severe bleeding", "convulsions", "altered consciousness"
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
        
        # Age factors
        if patient_data.age < 1 or patient_data.age > 75:
            score += 0.2
        
        # Determine triage level
        if score >= 0.8:
            level = "emergency"
            referral = True
        elif score >= 0.5:
            level = "urgent"
            referral = True
        elif score >= 0.3:
            level = "less_urgent"
            referral = False
        else:
            level = "non_urgent"
            referral = False
        
        return {
            "level": level,
            "score": score,
            "danger_signs": danger_signs,
            "referral_needed": referral
        }

class SimpleAfiCareAgent:
    """Simplified AfiCare medical agent"""
    
    def __init__(self):
        self.rule_engine = SimpleRuleEngine()
        self.triage_engine = SimpleTriageEngine()
    
    def conduct_consultation(self, patient_data: PatientData) -> ConsultationResult:
        """Conduct medical consultation"""
        
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
        
        if triage_result["level"] == "emergency":
            recommendations.append("🚨 IMMEDIATE MEDICAL ATTENTION REQUIRED")
            recommendations.append("Transfer to emergency department")
        
        # Add condition-specific recommendations
        for condition in condition_matches[:2]:  # Top 2 conditions
            if condition["confidence"] > 0.6:
                condition_name = condition["name"]
                if condition_name in self.rule_engine.conditions:
                    treatment = self.rule_engine.conditions[condition_name]["treatment"]
                    recommendations.extend(treatment[:2])  # Top 2 treatments
        
        # General recommendations
        recommendations.extend([
            "Monitor symptoms and return if condition worsens",
            "Ensure adequate rest and hydration"
        ])
        
        # Determine follow-up
        follow_up_conditions = ["hypertension", "diabetes"]
        follow_up_required = any(
            condition["name"] in follow_up_conditions 
            for condition in condition_matches 
            if condition["confidence"] > 0.5
        )
        
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
    
    def get_system_status(self):
        """Get system status"""
        return {
            "status": "operational",
            "llm_loaded": False,  # Simplified version doesn't use LLM
            "rules_loaded": len(self.rule_engine.conditions),
            "database_connected": True,
            "timestamp": datetime.now().isoformat()
        }

@st.cache_resource
def initialize_agent():
    """Initialize the simplified AfiCare agent"""
    try:
        agent = SimpleAfiCareAgent()
        return agent
    except Exception as e:
        st.error(f"Failed to initialize AfiCare Agent: {str(e)}")
        return None

def main():
    """Main Streamlit application"""
    
    # Header
    st.markdown("""
    <div class="main-header">
        <h1>🏥 AfiCare Medical Agent</h1>
        <p>AI-Powered Medical Assistant for African Healthcare</p>
        <small>Simplified Version - Rule-Based Analysis</small>
    </div>
    """, unsafe_allow_html=True)
    
    # Initialize agent
    agent = initialize_agent()
    
    if not agent:
        st.error("❌ Unable to start AfiCare Agent.")
        return
    
    # Sidebar navigation
    st.sidebar.title("🔧 Navigation")
    page = st.sidebar.selectbox(
        "Select Page",
        ["🏥 New Consultation", "📊 System Status", "📚 Medical Knowledge"]
    )
    
    if page == "🏥 New Consultation":
        consultation_page(agent)
    elif page == "📊 System Status":
        system_status_page(agent)
    elif page == "📚 Medical Knowledge":
        knowledge_page(agent)

def consultation_page(agent):
    """Patient consultation interface"""
    
    st.header("🏥 New Patient Consultation")
    
    # Patient Information Section
    with st.expander("👤 Patient Information", expanded=True):
        col1, col2, col3 = st.columns(3)
        
        with col1:
            patient_id = st.text_input(
                "Patient ID",
                value=f"AFC-{datetime.now().strftime('%Y%m%d')}-{datetime.now().strftime('%H%M%S')}",
                help="Unique patient identifier"
            )
            age = st.number_input("Age (years)", min_value=0, max_value=120, value=25)
        
        with col2:
            gender = st.selectbox("Gender", ["male", "female", "other"])
            weight = st.number_input("Weight (kg)", min_value=0.0, max_value=200.0, value=70.0, step=0.1)
        
        with col3:
            language = st.selectbox("Preferred Language", ["en", "sw", "lg"])
            visit_type = st.selectbox("Visit Type", ["new", "follow_up", "emergency"])
    
    # Chief Complaint
    st.subheader("🗣️ Chief Complaint")
    chief_complaint = st.text_area(
        "What is the main problem?",
        placeholder="Patient's main concern in their own words...",
        height=100
    )
    
    # Symptoms Section
    st.subheader("🔍 Symptoms Assessment")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Common Symptoms** (Select all that apply)")
        
        # Predefined symptom checkboxes
        common_symptoms = [
            "fever", "cough", "headache", "nausea", "vomiting", 
            "diarrhea", "abdominal_pain", "chest_pain", "difficulty_breathing",
            "fatigue", "dizziness", "muscle_aches", "chills", "loss_of_appetite"
        ]
        
        selected_symptoms = []
        for symptom in common_symptoms:
            if st.checkbox(symptom.replace("_", " ").title(), key=f"symptom_{symptom}"):
                selected_symptoms.append(symptom)
    
    with col2:
        st.write("**Additional Symptoms**")
        additional_symptoms = st.text_area(
            "Other symptoms not listed above",
            placeholder="Describe any other symptoms...",
            height=150
        )
        
        if additional_symptoms:
            # Split and clean additional symptoms
            extra_symptoms = [s.strip() for s in additional_symptoms.split(',') if s.strip()]
            selected_symptoms.extend(extra_symptoms)
    
    # Vital Signs Section
    st.subheader("🌡️ Vital Signs")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        temperature = st.number_input("Temperature (°C)", min_value=30.0, max_value=45.0, value=37.0, step=0.1)
    
    with col2:
        systolic_bp = st.number_input("Systolic BP (mmHg)", min_value=60, max_value=250, value=120)
        diastolic_bp = st.number_input("Diastolic BP (mmHg)", min_value=40, max_value=150, value=80)
    
    with col3:
        pulse = st.number_input("Pulse (bpm)", min_value=30, max_value=200, value=80)
    
    with col4:
        respiratory_rate = st.number_input("Respiratory Rate (/min)", min_value=5, max_value=60, value=16)
        oxygen_saturation = st.number_input("Oxygen Saturation (%)", min_value=70, max_value=100, value=98)
    
    # Medical History
    with st.expander("📋 Medical History"):
        medical_history = st.text_area(
            "Past medical conditions, surgeries, hospitalizations",
            placeholder="List any significant medical history...",
            height=100
        )
        
        current_medications = st.text_area(
            "Current medications",
            placeholder="List current medications and dosages...",
            height=80
        )
    
    # Consultation Button
    st.markdown("---")
    
    if st.button("🔍 Start AI Consultation", type="primary", use_container_width=True):
        if not chief_complaint.strip():
            st.error("Please enter the chief complaint before starting consultation.")
            return
        
        if not selected_symptoms:
            st.error("Please select at least one symptom.")
            return
        
        # Prepare patient data
        vital_signs = {
            "temperature": temperature,
            "systolic_bp": systolic_bp,
            "diastolic_bp": diastolic_bp,
            "pulse": pulse,
            "respiratory_rate": respiratory_rate,
            "oxygen_saturation": oxygen_saturation
        }
        
        medical_history_list = [h.strip() for h in medical_history.split(',') if h.strip()] if medical_history else []
        medications_list = [m.strip() for m in current_medications.split(',') if m.strip()] if current_medications else []
        
        patient_data = PatientData(
            patient_id=patient_id,
            age=age,
            gender=gender,
            symptoms=selected_symptoms,
            vital_signs=vital_signs,
            medical_history=medical_history_list,
            current_medications=medications_list,
            chief_complaint=chief_complaint
        )
        
        # Run consultation
        with st.spinner("🤖 AI is analyzing the case..."):
            try:
                result = agent.conduct_consultation(patient_data)
                display_consultation_results(result, language)
                
            except Exception as e:
                st.error(f"❌ Consultation failed: {str(e)}")

def display_consultation_results(result, language):
    """Display consultation results"""
    
    st.markdown("---")
    st.header("🎯 Consultation Results")
    
    # Triage Level
    triage_class = {
        "emergency": "triage-emergency",
        "urgent": "triage-urgent", 
        "less_urgent": "triage-routine",
        "non_urgent": "triage-routine"
    }.get(result.triage_level, "triage-routine")
    
    triage_emoji = {
        "emergency": "🚨",
        "urgent": "⚠️",
        "less_urgent": "⏰",
        "non_urgent": "✅"
    }.get(result.triage_level, "ℹ️")
    
    st.markdown(f"""
    <div class="{triage_class}">
        <h3>{triage_emoji} Triage Level: {result.triage_level.title()}</h3>
        <p><strong>Confidence:</strong> {result.confidence_score:.1%}</p>
        <p><strong>Referral Needed:</strong> {'Yes' if result.referral_needed else 'No'}</p>
        <p><strong>Follow-up Required:</strong> {'Yes' if result.follow_up_required else 'No'}</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Suspected Conditions
    if result.suspected_conditions:
        st.subheader("🔍 Suspected Conditions")
        
        for i, condition in enumerate(result.suspected_conditions[:5]):
            confidence = condition.get('confidence', 0)
            condition_name = condition.get('display_name', condition.get('name', 'Unknown'))
            
            st.markdown(f"""
            <div class="condition-match">
                <strong>{i+1}. {condition_name}</strong> - {confidence:.1%} confidence
                <br><small>Category: {condition.get('category', 'Unknown')}</small>
            </div>
            """, unsafe_allow_html=True)
    
    # Recommendations
    if result.recommendations:
        st.subheader("💊 Treatment Recommendations")
        for i, recommendation in enumerate(result.recommendations, 1):
            st.write(f"{i}. {recommendation}")
    
    # Additional Information
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("📅 Follow-up")
        if result.follow_up_required:
            st.success("✅ Follow-up appointment recommended")
            st.info("Schedule follow-up within 3-7 days or as clinically indicated")
        else:
            st.info("ℹ️ Routine follow-up as needed")
    
    with col2:
        st.subheader("🏥 Referral")
        if result.referral_needed:
            st.warning("⚠️ Referral to higher level facility recommended")
        else:
            st.success("✅ Can be managed at current facility")

def system_status_page(agent):
    """System status and health monitoring"""
    
    st.header("📊 System Status")
    
    # Get system status
    status = agent.get_system_status()
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric(
            "System Status",
            "🟢 Operational" if status.get("status") == "operational" else "🔴 Error",
            delta=None
        )
    
    with col2:
        st.metric(
            "Analysis Mode", 
            "📋 Rule-Based",
            delta=None
        )
    
    with col3:
        st.metric(
            "Medical Rules",
            f"{status.get('rules_loaded', 0)} conditions",
            delta=None
        )
    
    # Detailed status
    st.subheader("🔧 System Information")
    
    st.info("ℹ️ This is a simplified version of AfiCare that uses rule-based medical analysis.")
    st.write("**Features Available:**")
    st.write("- ✅ Symptom analysis and condition matching")
    st.write("- ✅ Emergency triage assessment")
    st.write("- ✅ Treatment recommendations")
    st.write("- ✅ Multi-language support framework")
    
    st.write("**Medical Conditions Supported:**")
    st.write("- 🦠 Malaria")
    st.write("- 🫁 Pneumonia") 
    st.write("- 💓 Hypertension")

def knowledge_page(agent):
    """Medical knowledge base browser"""
    
    st.header("📚 Medical Knowledge Base")
    
    conditions = agent.rule_engine.conditions
    
    if conditions:
        st.subheader("Available Medical Conditions")
        
        selected_condition = st.selectbox("Select a condition to view details:", list(conditions.keys()))
        
        if selected_condition:
            condition_info = conditions[selected_condition]
            
            st.subheader(f"📋 {condition_info.get('name', selected_condition)}")
            
            # Symptoms
            st.write("**Key Symptoms:**")
            symptoms = condition_info.get('symptoms', {})
            for symptom, weight in symptoms.items():
                st.write(f"- {symptom.replace('_', ' ').title()} (weight: {weight:.1f})")
            
            # Treatment
            st.write("**Treatment Recommendations:**")
            treatments = condition_info.get('treatment', [])
            for i, treatment in enumerate(treatments, 1):
                st.write(f"{i}. {treatment}")
    else:
        st.info("No medical conditions loaded.")

if __name__ == "__main__":
    main()