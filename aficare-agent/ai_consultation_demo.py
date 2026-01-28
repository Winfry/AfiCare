#!/usr/bin/env python3
"""
AfiCare AI Agent - Interactive Consultation Demo
Shows the full power of the medical AI agent
"""

import streamlit as st
import sys
from pathlib import Path
import asyncio
from datetime import datetime
import json

# Add src to path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

# Page config
st.set_page_config(
    page_title="AfiCare AI Agent Demo",
    page_icon="🤖",
    layout="wide"
)

# Custom CSS
st.markdown("""
<style>
.ai-header {
    background: linear-gradient(90deg, #2E8B57, #4CAF50);
    padding: 1rem;
    border-radius: 10px;
    color: white;
    text-align: center;
    margin-bottom: 2rem;
}

.test-case {
    background: #f0f8ff;
    padding: 1rem;
    border-radius: 8px;
    border-left: 4px solid #2196F3;
    margin: 1rem 0;
}

.ai-result {
    background: #e8f5e8;
    padding: 1rem;
    border-radius: 8px;
    border-left: 4px solid #4CAF50;
    margin: 1rem 0;
}

.error-box {
    background: #ffebee;
    padding: 1rem;
    border-radius: 8px;
    border-left: 4px solid #f44336;
    margin: 1rem 0;
}
</style>
""", unsafe_allow_html=True)

# Header
st.markdown("""
<div class="ai-header">
    <h1>🤖 AfiCare AI Agent - Medical Consultation Demo</h1>
    <p>Experience the power of AI-driven medical diagnosis and treatment recommendations</p>
</div>
""", unsafe_allow_html=True)

# Try to load the real AI Agent
try:
    from core.agent import AfiCareAgent, PatientData
    from utils.config import Config
    
    @st.cache_resource
    def get_ai_agent():
        """Initialize the AfiCare AI Agent"""
        config = Config()
        return AfiCareAgent(config)
    
    AI_AVAILABLE = True
    st.success("✅ **Real AfiCare AI Agent Loaded Successfully!**")
    
except ImportError as e:
    AI_AVAILABLE = False
    st.error(f"❌ **Could not load AfiCare AI Agent:** {e}")
    st.info("💡 Make sure you're running from the aficare-agent directory and all dependencies are installed")

if AI_AVAILABLE:
    # Initialize agent
    agent = get_ai_agent()
    
    st.info(f"🔌 **Agent Status:** Loaded with {len(agent.plugin_manager.plugins)} medical plugins")
    
    # Tabs for different demos
    tab1, tab2, tab3 = st.tabs(["🦠 Malaria Case", "🫁 Pneumonia Case", "🩺 Custom Case"])
    
    with tab1:
        st.subheader("🦠 Malaria Diagnosis Demo")
        
        st.markdown("""
        <div class="test-case">
        <h4>Patient Case: John Doe (35M)</h4>
        <p><strong>Chief Complaint:</strong> High fever and body aches for 3 days</p>
        <p><strong>Symptoms:</strong> Fever, headache, muscle aches, chills, sweating</p>
        <p><strong>Vital Signs:</strong> Temp 39.2°C, Pulse 98, BP 130/85, RR 20</p>
        </div>
        """, unsafe_allow_html=True)
        
        if st.button("🤖 Run AI Analysis - Malaria Case", key="malaria"):
            with st.spinner("🧠 AI Agent is analyzing the case..."):
                try:
                    # Create patient data
                    patient_data = PatientData(
                        patient_id="ML-DEMO-MALARIA",
                        age=35,
                        gender="Male",
                        symptoms=["fever", "headache", "muscle aches", "chills", "sweating"],
                        vital_signs={
                            "temperature": 39.2,
                            "pulse": 98,
                            "blood_pressure_systolic": 130,
                            "blood_pressure_diastolic": 85,
                            "respiratory_rate": 20
                        },
                        medical_history=["None"],
                        current_medications=["None"],
                        chief_complaint="High fever and body aches for 3 days"
                    )
                    
                    # Run AI consultation
                    result = asyncio.run(agent.conduct_consultation(patient_data))
                    
                    # Display results
                    st.markdown("""
                    <div class="ai-result">
                    <h4>🎯 AI Analysis Results</h4>
                    </div>
                    """, unsafe_allow_html=True)
                    
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        st.metric("🚨 Triage Level", result.triage_level)
                    
                    with col2:
                        st.metric("🎯 Confidence", f"{result.confidence_score:.1%}")
                    
                    with col3:
                        st.metric("🏥 Referral Needed", "Yes" if result.referral_needed else "No")
                    
                    # Suspected conditions
                    st.subheader("🔍 Suspected Conditions")
                    for i, condition in enumerate(result.suspected_conditions):
                        st.write(f"{i+1}. **{condition.get('name', 'Unknown')}** - {condition.get('confidence', 0):.1%} confidence")
                    
                    # Recommendations
                    st.subheader("💊 Treatment Recommendations")
                    for i, rec in enumerate(result.recommendations):
                        st.write(f"{i+1}. {rec}")
                    
                    # Show raw data
                    with st.expander("🔧 Raw AI Output (Technical)"):
                        st.json({
                            "patient_id": result.patient_id,
                            "timestamp": result.timestamp.isoformat(),
                            "triage_level": result.triage_level,
                            "suspected_conditions": result.suspected_conditions,
                            "recommendations": result.recommendations,
                            "referral_needed": result.referral_needed,
                            "follow_up_required": result.follow_up_required,
                            "confidence_score": result.confidence_score
                        })
                    
                except Exception as e:
                    st.markdown(f"""
                    <div class="error-box">
                    <h4>❌ AI Analysis Failed</h4>
                    <p>Error: {str(e)}</p>
                    </div>
                    """, unsafe_allow_html=True)
    
    with tab2:
        st.subheader("🫁 Pneumonia Diagnosis Demo")
        
        st.markdown("""
        <div class="test-case">
        <h4>Patient Case: Sarah Ali (45F)</h4>
        <p><strong>Chief Complaint:</strong> Persistent cough with fever and breathing difficulty</p>
        <p><strong>Symptoms:</strong> Cough, fever, difficulty breathing, chest pain</p>
        <p><strong>Vital Signs:</strong> Temp 38.8°C, Pulse 105, BP 125/80, RR 26</p>
        <p><strong>History:</strong> Asthma, currently on Salbutamol inhaler</p>
        </div>
        """, unsafe_allow_html=True)
        
        if st.button("🤖 Run AI Analysis - Pneumonia Case", key="pneumonia"):
            with st.spinner("🧠 AI Agent is analyzing the case..."):
                try:
                    patient_data = PatientData(
                        patient_id="ML-DEMO-PNEUMONIA",
                        age=45,
                        gender="Female",
                        symptoms=["cough", "fever", "difficulty breathing", "chest pain"],
                        vital_signs={
                            "temperature": 38.8,
                            "pulse": 105,
                            "blood_pressure_systolic": 125,
                            "blood_pressure_diastolic": 80,
                            "respiratory_rate": 26
                        },
                        medical_history=["Asthma"],
                        current_medications=["Salbutamol inhaler"],
                        chief_complaint="Persistent cough with fever and breathing difficulty"
                    )
                    
                    result = asyncio.run(agent.conduct_consultation(patient_data))
                    
                    # Display results (same format as malaria)
                    st.markdown("""
                    <div class="ai-result">
                    <h4>🎯 AI Analysis Results</h4>
                    </div>
                    """, unsafe_allow_html=True)
                    
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        st.metric("🚨 Triage Level", result.triage_level)
                    
                    with col2:
                        st.metric("🎯 Confidence", f"{result.confidence_score:.1%}")
                    
                    with col3:
                        st.metric("🏥 Referral Needed", "Yes" if result.referral_needed else "No")
                    
                    st.subheader("🔍 Suspected Conditions")
                    for i, condition in enumerate(result.suspected_conditions):
                        st.write(f"{i+1}. **{condition.get('name', 'Unknown')}** - {condition.get('confidence', 0):.1%} confidence")
                    
                    st.subheader("💊 Treatment Recommendations")
                    for i, rec in enumerate(result.recommendations):
                        st.write(f"{i+1}. {rec}")
                    
                except Exception as e:
                    st.error(f"❌ AI Analysis Failed: {str(e)}")
    
    with tab3:
        st.subheader("🩺 Custom Medical Case")
        st.write("Create your own patient case and see how the AI analyzes it!")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.subheader("Patient Information")
            age = st.number_input("Age", min_value=1, max_value=120, value=30)
            gender = st.selectbox("Gender", ["Male", "Female", "Other"])
            chief_complaint = st.text_area("Chief Complaint", placeholder="e.g., Fever and headache for 2 days")
            
            st.subheader("Symptoms")
            symptoms_text = st.text_area("Symptoms (one per line)", 
                                       placeholder="fever\nheadache\ncough\nnausea")
            symptoms = [s.strip() for s in symptoms_text.split('\n') if s.strip()]
            
        with col2:
            st.subheader("Vital Signs")
            temperature = st.number_input("Temperature (°C)", min_value=35.0, max_value=45.0, value=37.0, step=0.1)
            pulse = st.number_input("Pulse (bpm)", min_value=40, max_value=200, value=80)
            systolic_bp = st.number_input("Systolic BP", min_value=70, max_value=250, value=120)
            diastolic_bp = st.number_input("Diastolic BP", min_value=40, max_value=150, value=80)
            respiratory_rate = st.number_input("Respiratory Rate", min_value=8, max_value=50, value=16)
            
            st.subheader("Medical History")
            medical_history = st.text_area("Medical History", placeholder="e.g., Diabetes, Hypertension")
            current_medications = st.text_area("Current Medications", placeholder="e.g., Metformin, Lisinopril")
        
        if st.button("🤖 Analyze Custom Case", key="custom"):
            if not symptoms:
                st.error("❌ Please enter at least one symptom")
            elif not chief_complaint:
                st.error("❌ Please enter a chief complaint")
            else:
                with st.spinner("🧠 AI Agent is analyzing your custom case..."):
                    try:
                        patient_data = PatientData(
                            patient_id="ML-DEMO-CUSTOM",
                            age=age,
                            gender=gender,
                            symptoms=symptoms,
                            vital_signs={
                                "temperature": temperature,
                                "pulse": pulse,
                                "blood_pressure_systolic": systolic_bp,
                                "blood_pressure_diastolic": diastolic_bp,
                                "respiratory_rate": respiratory_rate
                            },
                            medical_history=[medical_history] if medical_history else ["None"],
                            current_medications=[current_medications] if current_medications else ["None"],
                            chief_complaint=chief_complaint
                        )
                        
                        result = asyncio.run(agent.conduct_consultation(patient_data))
                        
                        # Display results
                        st.success("🎯 AI Analysis Complete!")
                        
                        col1, col2, col3 = st.columns(3)
                        
                        with col1:
                            st.metric("🚨 Triage Level", result.triage_level)
                        
                        with col2:
                            st.metric("🎯 Confidence", f"{result.confidence_score:.1%}")
                        
                        with col3:
                            st.metric("🏥 Referral Needed", "Yes" if result.referral_needed else "No")
                        
                        st.subheader("🔍 Suspected Conditions")
                        for i, condition in enumerate(result.suspected_conditions):
                            st.write(f"{i+1}. **{condition.get('name', 'Unknown')}** - {condition.get('confidence', 0):.1%} confidence")
                        
                        st.subheader("💊 Treatment Recommendations")
                        for i, rec in enumerate(result.recommendations):
                            st.write(f"{i+1}. {rec}")
                        
                    except Exception as e:
                        st.error(f"❌ AI Analysis Failed: {str(e)}")
                        st.write("**Debug Info:**")
                        st.write(f"Symptoms: {symptoms}")
                        st.write(f"Vital Signs: Temperature {temperature}°C, Pulse {pulse}")

else:
    st.warning("⚠️ **AfiCare AI Agent not available**")
    st.info("To enable the full AI Agent:")
    st.code("""
# 1. Make sure you're in the aficare-agent directory
cd aficare-agent

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run this demo
streamlit run ai_consultation_demo.py
    """)

# Footer
st.markdown("---")
st.markdown("🏥 **AfiCare MediLink** - AI-Powered Healthcare for Africa")
st.markdown("Built with ❤️ for improving healthcare accessibility")