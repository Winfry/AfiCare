"""
AfiCare Agent - Standalone Streamlit Application
Run this file directly with: streamlit run streamlit_app.py
"""

import streamlit as st
import asyncio
import sys
import os
from pathlib import Path
from datetime import datetime
import json

# Add src to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

# Now import our modules
from core.agent import AfiCareAgent, PatientData
from utils.config import Config
from utils.logger import setup_logging, log_medical_event

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
    .patient-card {
        background: #f8f9fa;
        padding: 1rem;
        border-radius: 8px;
        border-left: 4px solid #2E8B57;
        margin-bottom: 1rem;
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

@st.cache_resource
def initialize_agent():
    """Initialize the AfiCare agent"""
    try:
        config_path = 'config/default.yaml'
        config = Config(config_path)
        setup_logging(config.get('app.log_level', 'INFO'))
        
        agent = AfiCareAgent(config)
        return agent, config
    except Exception as e:
        st.error(f"Failed to initialize AfiCare Agent: {str(e)}")
        return None, None

def main():
    """Main Streamlit application"""
    
    # Header
    st.markdown("""
    <div class="main-header">
        <h1>🏥 AfiCare Medical Agent</h1>
        <p>AI-Powered Medical Assistant for African Healthcare</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Initialize agent
    agent, config = initialize_agent()
    
    if not agent:
        st.error("❌ Unable to start AfiCare Agent. Please check configuration.")
        st.info("💡 Make sure you're running this from the aficare-agent directory")
        return
    
    # Sidebar navigation
    st.sidebar.title("🔧 Navigation")
    page = st.sidebar.selectbox(
        "Select Page",
        ["🏥 New Consultation", "📊 System Status", "📚 Medical Knowledge"]
    )
    
    if page == "🏥 New Consultation":
        consultation_page(agent, config)
    elif page == "📊 System Status":
        system_status_page(agent)
    elif page == "📚 Medical Knowledge":
        knowledge_page(agent)

def consultation_page(agent, config):
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
    
    # Risk Factors
    with st.expander("⚠️ Risk Factors"):
        risk_factors = []
        
        col1, col2 = st.columns(2)
        
        with col1:
            if st.checkbox("Lives in malaria-endemic area"):
                risk_factors.append("endemic_area")
            if st.checkbox("No bed net use"):
                risk_factors.append("no_bed_net")
            if st.checkbox("Recent travel"):
                risk_factors.append("recent_travel")
            if st.checkbox("Pregnancy"):
                risk_factors.append("pregnancy")
        
        with col2:
            if st.checkbox("HIV positive"):
                risk_factors.append("hiv_positive")
            if st.checkbox("Diabetes"):
                risk_factors.append("diabetes")
            if st.checkbox("Smoking"):
                risk_factors.append("smoking")
            if st.checkbox("Malnutrition"):
                risk_factors.append("malnutrition")
    
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
                # Run async consultation
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                result = loop.run_until_complete(agent.conduct_consultation(patient_data))
                loop.close()
                
                # Display results
                display_consultation_results(result, language)
                
                # Log the consultation
                log_medical_event(
                    "consultation",
                    patient_id,
                    f"AI consultation completed - Triage: {result.triage_level}"
                )
                
            except Exception as e:
                st.error(f"❌ Consultation failed: {str(e)}")
                st.info("💡 This might be due to missing LLM model. The system can still work with rule-based analysis.")

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
            "LLM Status", 
            "✅ Loaded" if status.get("llm_loaded") else "❌ Not Loaded",
            delta=None
        )
    
    with col3:
        st.metric(
            "Medical Rules",
            f"{status.get('rules_loaded', 0)} conditions",
            delta=None
        )
    
    # Detailed status
    st.subheader("🔧 Detailed Status")
    
    status_data = {
        "Database Connected": "✅ Yes" if status.get("database_connected") else "❌ No",
        "LLM Model Loaded": "✅ Yes" if status.get("llm_loaded") else "❌ No", 
        "Medical Rules Loaded": f"{status.get('rules_loaded', 0)} conditions",
        "Last Updated": status.get("timestamp", "Unknown")
    }
    
    for key, value in status_data.items():
        st.write(f"**{key}:** {value}")
    
    if not status.get("llm_loaded"):
        st.info("💡 LLM not loaded. Download the Llama model to enable full AI features.")

def knowledge_page(agent):
    """Medical knowledge base browser"""
    
    st.header("📚 Medical Knowledge Base")
    
    # Get loaded conditions
    if hasattr(agent.rule_engine, 'get_loaded_rules'):
        conditions = agent.rule_engine.get_loaded_rules()
        
        if conditions:
            st.subheader("Available Medical Conditions")
            
            selected_condition = st.selectbox("Select a condition to view details:", conditions)
            
            if selected_condition:
                condition_info = agent.rule_engine.get_condition_info(selected_condition)
                
                if condition_info:
                    st.subheader(f"📋 {condition_info.get('name', selected_condition)}")
                    
                    # Basic information
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        st.write(f"**Category:** {condition_info.get('category', 'Unknown')}")
                        st.write(f"**ICD-10:** {condition_info.get('icd10', 'Not specified')}")
                    
                    with col2:
                        prevalence = condition_info.get('prevalence', {})
                        if prevalence:
                            st.write("**Prevalence:**")
                            for region, rate in prevalence.items():
                                st.write(f"  - {region}: {rate:.1%}")
                    
                    # Symptoms
                    symptoms = condition_info.get('symptoms', {})
                    if symptoms:
                        st.subheader("🔍 Symptoms")
                        
                        primary = symptoms.get('primary', [])
                        if primary:
                            st.write("**Primary Symptoms:**")
                            for symptom in primary:
                                st.write(f"- {symptom.get('name', 'Unknown')} (weight: {symptom.get('weight', 0):.1f})")
                    
                    # Treatment
                    treatment = condition_info.get('treatment', {})
                    if treatment:
                        st.subheader("💊 Treatment")
                        
                        first_line = treatment.get('first_line', {})
                        if first_line:
                            uncomplicated = first_line.get('uncomplicated', [])
                            if uncomplicated:
                                st.write("**First-line Treatment:**")
                                for med in uncomplicated:
                                    st.write(f"- {med.get('medication', 'Unknown')}: {med.get('dosage', 'See guidelines')}")
        else:
            st.info("No medical conditions loaded. Check system configuration.")
    else:
        st.error("Unable to access medical knowledge base.")

if __name__ == "__main__":
    main()