"""
Streamlit Integration for AfiCare Hybrid AI
Provides easy-to-use functions for the Streamlit app
"""

import streamlit as st
import asyncio
from typing import List, Dict, Any
import os

# Import the hybrid agent
try:
    from .hybrid_medical_agent import (
        HybridMedicalAgent,
        AIBackend,
        MedicalAnalysis,
        GROQ_AVAILABLE,
        OLLAMA_AVAILABLE
    )
    AI_AVAILABLE = True
except ImportError:
    AI_AVAILABLE = False


def get_ai_status() -> Dict[str, bool]:
    """Get status of available AI backends"""
    return {
        "rule_based": True,  # Always available
        "groq": GROQ_AVAILABLE if AI_AVAILABLE else False,
        "ollama": OLLAMA_AVAILABLE if AI_AVAILABLE else False,
        "langchain": AI_AVAILABLE
    }


def display_ai_status_badge():
    """Display AI status in Streamlit sidebar"""
    status = get_ai_status()

    with st.sidebar:
        st.markdown("---")
        st.markdown("### AI Status")

        if status["groq"]:
            st.success("Groq Cloud: Connected")
        elif status["ollama"]:
            st.success("Ollama Local: Connected")
        else:
            st.info("Rule-Based: Active")

        # Show enhancement option
        if not status["groq"] and not status["ollama"]:
            with st.expander("Enable AI Enhancement"):
                st.markdown("""
                **FREE AI Options:**

                1. **Groq Cloud** (30 req/min FREE)
                   - Get key: [console.groq.com](https://console.groq.com)
                   - Set: `GROQ_API_KEY`

                2. **Ollama Local** (Unlimited FREE)
                   - Install: [ollama.ai](https://ollama.ai)
                   - Run: `ollama pull llama3.2`
                """)


@st.cache_resource
def get_hybrid_agent() -> HybridMedicalAgent:
    """Get cached hybrid medical agent"""
    # Determine best available backend
    if GROQ_AVAILABLE:
        backend = AIBackend.GROQ
    elif OLLAMA_AVAILABLE:
        backend = AIBackend.OLLAMA
    else:
        backend = AIBackend.RULE_BASED

    return HybridMedicalAgent(preferred_backend=backend)


def run_async(coro):
    """Helper to run async functions in Streamlit"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


def analyze_with_hybrid_ai(
    symptoms: List[str],
    vital_signs: Dict[str, float],
    age: int,
    gender: str,
    chief_complaint: str = "",
    medical_history: List[str] = None
) -> MedicalAnalysis:
    """
    Run hybrid AI analysis with progress display

    Returns MedicalAnalysis with:
    - diagnoses
    - triage_level
    - recommendations
    - ai_enhanced (bool)
    - backend_used
    """

    agent = get_hybrid_agent()

    # Run analysis
    result = run_async(agent.analyze(
        symptoms=symptoms,
        vital_signs=vital_signs,
        age=age,
        gender=gender,
        chief_complaint=chief_complaint,
        medical_history=medical_history or []
    ))

    return result


def display_ai_analysis_results(result: MedicalAnalysis):
    """Display AI analysis results in a nice Streamlit format"""

    # AI Enhancement badge
    if result.ai_enhanced:
        st.success(f"AI-Enhanced Analysis (via {result.backend_used})")
    else:
        st.info("Rule-Based Analysis (offline mode)")

    # Triage Level with color
    triage_colors = {
        "emergency": ("red", "EMERGENCY - Immediate attention required!"),
        "urgent": ("orange", "URGENT - Needs prompt attention"),
        "less_urgent": ("yellow", "LESS URGENT - Can wait safely"),
        "non_urgent": ("green", "NON-URGENT - Routine care")
    }

    color, description = triage_colors.get(
        result.triage_level,
        ("gray", result.triage_level.upper())
    )

    st.markdown(f"""
    <div style="background-color: {color}; padding: 15px; border-radius: 10px;
                color: white; text-align: center; margin: 10px 0;">
        <h3 style="margin:0;">TRIAGE: {result.triage_level.upper()}</h3>
        <p style="margin:5px 0 0 0;">{description}</p>
    </div>
    """, unsafe_allow_html=True)

    # Confidence score
    st.metric("Confidence", f"{result.confidence:.0%}")

    # Diagnoses
    st.subheader("Suspected Conditions")
    for i, diagnosis in enumerate(result.diagnoses[:3], 1):
        with st.expander(
            f"{i}. {diagnosis['condition']} - {diagnosis['confidence']:.0%}",
            expanded=(i == 1)
        ):
            # Matching symptoms
            if diagnosis.get('matching_symptoms'):
                st.write("**Matching Symptoms:**")
                for symptom in diagnosis['matching_symptoms']:
                    st.write(f"  - {symptom}")

            # Treatment
            if diagnosis.get('treatment'):
                st.write("**Treatment Protocol:**")
                for treatment in diagnosis['treatment']:
                    st.write(f"  - {treatment}")

            # Danger signs
            if diagnosis.get('danger_signs'):
                st.warning("**Watch for these danger signs:**")
                for sign in diagnosis['danger_signs']:
                    st.write(f"  - {sign}")

    # Recommendations
    st.subheader("Recommendations")
    for rec in result.recommendations:
        st.write(f"- {rec}")


def consultation_with_hybrid_ai():
    """
    Complete consultation widget with hybrid AI

    Drop this into any Streamlit page for instant AI consultation
    """

    st.header("AI-Powered Medical Consultation")

    # Show AI status
    display_ai_status_badge()

    # Patient info
    col1, col2 = st.columns(2)
    with col1:
        age = st.number_input("Patient Age", min_value=0, max_value=120, value=35)
    with col2:
        gender = st.selectbox("Gender", ["male", "female", "other"])

    chief_complaint = st.text_area(
        "Chief Complaint",
        placeholder="Describe the main reason for the visit..."
    )

    # Symptoms
    st.subheader("Symptoms")

    symptom_options = [
        "fever", "chills", "headache", "cough", "sore throat",
        "runny nose", "difficulty breathing", "chest pain",
        "nausea", "vomiting", "diarrhea", "abdominal pain",
        "fatigue", "dizziness", "muscle aches", "joint pain",
        "rash", "swelling", "weight loss", "night sweats"
    ]

    selected_symptoms = st.multiselect(
        "Select symptoms",
        symptom_options,
        help="Select all that apply"
    )

    # Custom symptoms
    custom_symptoms = st.text_input(
        "Other symptoms (comma-separated)",
        placeholder="e.g., blurred vision, frequent urination"
    )

    if custom_symptoms:
        selected_symptoms.extend([s.strip() for s in custom_symptoms.split(",")])

    # Vital Signs
    st.subheader("Vital Signs")
    col1, col2, col3 = st.columns(3)

    with col1:
        temperature = st.number_input("Temperature (C)", value=37.0, step=0.1)
        systolic = st.number_input("Systolic BP", value=120)

    with col2:
        diastolic = st.number_input("Diastolic BP", value=80)
        pulse = st.number_input("Pulse Rate", value=80)

    with col3:
        resp_rate = st.number_input("Respiratory Rate", value=16)
        spo2 = st.number_input("SpO2 (%)", value=98)

    vital_signs = {
        "temperature": temperature,
        "systolic_bp": systolic,
        "diastolic_bp": diastolic,
        "pulse_rate": pulse,
        "respiratory_rate": resp_rate,
        "oxygen_saturation": spo2
    }

    # Analyze button
    if st.button("Analyze with AI", type="primary", use_container_width=True):
        if not selected_symptoms:
            st.error("Please select at least one symptom")
            return

        with st.spinner("AI is analyzing..."):
            try:
                result = analyze_with_hybrid_ai(
                    symptoms=selected_symptoms,
                    vital_signs=vital_signs,
                    age=age,
                    gender=gender,
                    chief_complaint=chief_complaint
                )

                st.success("Analysis Complete!")
                display_ai_analysis_results(result)

            except Exception as e:
                st.error(f"Analysis error: {e}")
                st.info("Falling back to rule-based analysis...")


# Export for easy import
__all__ = [
    'get_ai_status',
    'display_ai_status_badge',
    'get_hybrid_agent',
    'analyze_with_hybrid_ai',
    'display_ai_analysis_results',
    'consultation_with_hybrid_ai'
]
