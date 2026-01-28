"""
AfiCare Medical Agent using LangGraph
Multi-step medical reasoning with state management

This creates a proper AI agent workflow:
1. Symptom Analysis -> 2. Triage Assessment -> 3. Diagnosis -> 4. Treatment Plan

FREE via Groq or Ollama!
"""

import os
from typing import TypedDict, List, Dict, Any, Annotated
from dataclasses import dataclass

# Check if LangGraph is available
LANGGRAPH_AVAILABLE = False
try:
    from langgraph.graph import StateGraph, END
    from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
    LANGGRAPH_AVAILABLE = True
except ImportError:
    print("[INFO] LangGraph not installed. Install with: pip install langgraph")

# Check LLM availability
LLM_AVAILABLE = False
llm = None

try:
    from langchain_groq import ChatGroq
    if os.getenv("GROQ_API_KEY"):
        llm = ChatGroq(model="llama-3.1-8b-instant", temperature=0.1)
        LLM_AVAILABLE = True
        print("[AI] Using Groq LLM")
except:
    pass

if not LLM_AVAILABLE:
    try:
        from langchain_ollama import ChatOllama
        llm = ChatOllama(model="llama3.2", temperature=0.1)
        LLM_AVAILABLE = True
        print("[AI] Using Ollama LLM")
    except:
        pass


class MedicalState(TypedDict):
    """State that flows through the medical agent graph"""
    # Input
    patient_age: int
    patient_gender: str
    symptoms: List[str]
    vital_signs: Dict[str, float]
    chief_complaint: str
    medical_history: List[str]

    # Analysis stages
    symptom_analysis: str
    triage_level: str
    triage_reasoning: str
    diagnoses: List[Dict[str, Any]]
    treatment_plan: List[str]
    warnings: List[str]

    # Metadata
    messages: List[Any]
    current_step: str
    confidence: float


def create_medical_agent_graph():
    """Create the medical reasoning graph"""

    if not LANGGRAPH_AVAILABLE:
        raise ImportError("LangGraph not installed. Run: pip install langgraph")

    if not LLM_AVAILABLE:
        raise RuntimeError("No LLM available. Set up Groq or Ollama first.")

    # Define the graph
    workflow = StateGraph(MedicalState)

    # Node 1: Analyze Symptoms
    def analyze_symptoms(state: MedicalState) -> MedicalState:
        """First step: Analyze and categorize symptoms"""

        prompt = f"""Analyze these symptoms for a {state['patient_age']} year old {state['patient_gender']}:

Symptoms: {', '.join(state['symptoms'])}
Chief Complaint: {state['chief_complaint']}
Vital Signs: Temperature {state['vital_signs'].get('temperature', 'N/A')}°C,
             BP {state['vital_signs'].get('systolic_bp', 'N/A')}/{state['vital_signs'].get('diastolic_bp', 'N/A')}

Categorize symptoms by body system and identify key patterns.
Keep response under 200 words."""

        response = llm.invoke([HumanMessage(content=prompt)])

        return {
            **state,
            "symptom_analysis": response.content,
            "current_step": "symptom_analysis",
            "messages": state.get("messages", []) + [response]
        }

    # Node 2: Triage Assessment
    def assess_triage(state: MedicalState) -> MedicalState:
        """Determine urgency level"""

        prompt = f"""Based on this analysis, determine triage level:

{state['symptom_analysis']}

Vital Signs:
- Temperature: {state['vital_signs'].get('temperature', 37)}°C
- Blood Pressure: {state['vital_signs'].get('systolic_bp', 120)}/{state['vital_signs'].get('diastolic_bp', 80)}
- Respiratory Rate: {state['vital_signs'].get('respiratory_rate', 16)}

Classify as ONE of: EMERGENCY, URGENT, LESS_URGENT, NON_URGENT
Explain in 1-2 sentences why.

Format: LEVEL: [level]
REASON: [reason]"""

        response = llm.invoke([HumanMessage(content=prompt)])
        content = response.content.upper()

        # Parse triage level
        triage = "non_urgent"
        if "EMERGENCY" in content:
            triage = "emergency"
        elif "URGENT" in content and "LESS" not in content:
            triage = "urgent"
        elif "LESS_URGENT" in content or "LESS URGENT" in content:
            triage = "less_urgent"

        return {
            **state,
            "triage_level": triage,
            "triage_reasoning": response.content,
            "current_step": "triage",
            "messages": state.get("messages", []) + [response]
        }

    # Node 3: Generate Diagnoses
    def generate_diagnoses(state: MedicalState) -> MedicalState:
        """Generate differential diagnoses"""

        prompt = f"""Based on this medical assessment:

Patient: {state['patient_age']}yo {state['patient_gender']}
Symptoms: {', '.join(state['symptoms'])}
Analysis: {state['symptom_analysis']}
Triage: {state['triage_level']}

Provide top 3 differential diagnoses with confidence (0-100%).

Format each as:
1. [CONDITION] - [XX]% confidence
   Reasoning: [why]
"""

        response = llm.invoke([HumanMessage(content=prompt)])

        # Parse diagnoses (simplified)
        diagnoses = []
        lines = response.content.split('\n')
        for line in lines:
            if '%' in line and any(c.isalpha() for c in line):
                # Try to extract condition and confidence
                try:
                    parts = line.split('-')
                    if len(parts) >= 2:
                        condition = parts[0].strip().lstrip('0123456789. ')
                        conf_str = ''.join(c for c in parts[1] if c.isdigit())
                        confidence = int(conf_str) / 100 if conf_str else 0.5
                        diagnoses.append({
                            "condition": condition,
                            "confidence": confidence,
                            "reasoning": line
                        })
                except:
                    pass

        return {
            **state,
            "diagnoses": diagnoses[:3],
            "current_step": "diagnosis",
            "confidence": diagnoses[0]["confidence"] if diagnoses else 0.5,
            "messages": state.get("messages", []) + [response]
        }

    # Node 4: Treatment Plan
    def create_treatment_plan(state: MedicalState) -> MedicalState:
        """Generate treatment recommendations"""

        top_diagnosis = state['diagnoses'][0]['condition'] if state['diagnoses'] else "Unknown"

        prompt = f"""Create a treatment plan for suspected {top_diagnosis}:

Patient: {state['patient_age']}yo {state['patient_gender']}
Triage: {state['triage_level']}
Diagnoses: {[d['condition'] for d in state['diagnoses']]}

Provide:
1. Immediate actions (if urgent)
2. Medications (with doses if applicable)
3. Lifestyle/supportive care
4. Follow-up recommendations
5. Warning signs to watch for

Keep response practical for African healthcare settings.
Format as numbered list."""

        response = llm.invoke([HumanMessage(content=prompt)])

        # Parse treatment items
        treatments = []
        warnings = []
        for line in response.content.split('\n'):
            line = line.strip()
            if line and (line[0].isdigit() or line.startswith('-')):
                treatments.append(line.lstrip('0123456789.-) '))
            if 'warning' in line.lower() or 'danger' in line.lower():
                warnings.append(line)

        return {
            **state,
            "treatment_plan": treatments[:10],
            "warnings": warnings,
            "current_step": "complete",
            "messages": state.get("messages", []) + [response]
        }

    # Add nodes to graph
    workflow.add_node("analyze_symptoms", analyze_symptoms)
    workflow.add_node("assess_triage", assess_triage)
    workflow.add_node("generate_diagnoses", generate_diagnoses)
    workflow.add_node("create_treatment_plan", create_treatment_plan)

    # Define the flow
    workflow.set_entry_point("analyze_symptoms")
    workflow.add_edge("analyze_symptoms", "assess_triage")
    workflow.add_edge("assess_triage", "generate_diagnoses")
    workflow.add_edge("generate_diagnoses", "create_treatment_plan")
    workflow.add_edge("create_treatment_plan", END)

    # Compile the graph
    return workflow.compile()


async def run_medical_agent(
    symptoms: List[str],
    vital_signs: Dict[str, float],
    age: int,
    gender: str,
    chief_complaint: str = "",
    medical_history: List[str] = None
) -> Dict[str, Any]:
    """
    Run the full medical agent workflow

    Returns complete analysis with:
    - Symptom analysis
    - Triage level
    - Diagnoses with confidence
    - Treatment plan
    - Warnings
    """

    if not LANGGRAPH_AVAILABLE or not LLM_AVAILABLE:
        # Fallback to simple analysis
        return {
            "error": "LangGraph or LLM not available",
            "fallback": True,
            "triage_level": "non_urgent",
            "diagnoses": [],
            "treatment_plan": ["Consult healthcare provider"]
        }

    agent = create_medical_agent_graph()

    initial_state: MedicalState = {
        "patient_age": age,
        "patient_gender": gender,
        "symptoms": symptoms,
        "vital_signs": vital_signs,
        "chief_complaint": chief_complaint or "Not specified",
        "medical_history": medical_history or [],
        "symptom_analysis": "",
        "triage_level": "",
        "triage_reasoning": "",
        "diagnoses": [],
        "treatment_plan": [],
        "warnings": [],
        "messages": [],
        "current_step": "start",
        "confidence": 0.0
    }

    # Run the agent
    final_state = await agent.ainvoke(initial_state)

    return {
        "symptom_analysis": final_state["symptom_analysis"],
        "triage_level": final_state["triage_level"],
        "triage_reasoning": final_state["triage_reasoning"],
        "diagnoses": final_state["diagnoses"],
        "treatment_plan": final_state["treatment_plan"],
        "warnings": final_state["warnings"],
        "confidence": final_state["confidence"],
        "ai_enhanced": True
    }


# Example usage
if __name__ == "__main__":
    import asyncio

    async def test():
        print("\n" + "="*50)
        print("AfiCare Medical Agent Test")
        print("="*50)

        result = await run_medical_agent(
            symptoms=["fever", "chills", "headache", "muscle aches"],
            vital_signs={
                "temperature": 39.2,
                "systolic_bp": 110,
                "diastolic_bp": 70,
                "pulse_rate": 95,
                "respiratory_rate": 18
            },
            age=28,
            gender="female",
            chief_complaint="Feeling very sick for 3 days with high fever"
        )

        print(f"\n[TRIAGE] {result['triage_level'].upper()}")
        print(f"Reason: {result.get('triage_reasoning', 'N/A')[:100]}...")

        print(f"\n[DIAGNOSES]")
        for d in result.get('diagnoses', []):
            print(f"  - {d['condition']}: {d['confidence']:.0%}")

        print(f"\n[TREATMENT PLAN]")
        for t in result.get('treatment_plan', [])[:5]:
            print(f"  - {t}")

        print(f"\n[WARNINGS]")
        for w in result.get('warnings', []):
            print(f"  ! {w}")

    asyncio.run(test())
