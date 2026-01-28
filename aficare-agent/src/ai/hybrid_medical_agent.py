"""
AfiCare Hybrid Medical AI Agent
- Rule-based engine: Always works (offline)
- LLM enhancement: Optional (when online, FREE via Groq/Ollama)

FREE Options:
1. Groq Cloud: 30 req/min free tier (Llama 3, Mixtral)
2. Ollama: Local LLMs, unlimited, needs 8GB+ RAM
3. Google AI: 60 req/min free tier (Gemini)
"""

import os
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from enum import Enum
import json

# Check available AI backends
GROQ_AVAILABLE = False
OLLAMA_AVAILABLE = False
LANGCHAIN_AVAILABLE = False
ChatPromptTemplate = None
JsonOutputParser = None

# Try to import LangChain core components first
try:
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.output_parsers import JsonOutputParser
    LANGCHAIN_AVAILABLE = True
except ImportError:
    pass

# Check Groq availability
try:
    from langchain_groq import ChatGroq
    GROQ_AVAILABLE = bool(os.getenv("GROQ_API_KEY"))
except ImportError:
    pass

# Check Ollama availability
try:
    from langchain_ollama import ChatOllama
    OLLAMA_AVAILABLE = True
except ImportError:
    pass


class AIBackend(Enum):
    RULE_BASED = "rule_based"  # Always available
    GROQ = "groq"              # Free tier: 30 req/min
    OLLAMA = "ollama"          # Local, unlimited
    GOOGLE = "google"          # Free tier: 60 req/min


@dataclass
class MedicalAnalysis:
    """Result of medical analysis"""
    diagnoses: List[Dict[str, Any]]
    triage_level: str
    recommendations: List[str]
    confidence: float
    ai_enhanced: bool
    backend_used: str


class HybridMedicalAgent:
    """
    Hybrid Medical AI Agent

    Priority order:
    1. Try LLM enhancement (if available and online)
    2. Fall back to rule-based engine (always works)
    """

    def __init__(self, preferred_backend: AIBackend = AIBackend.RULE_BASED):
        self.preferred_backend = preferred_backend
        self.llm = None
        self._init_llm()

        # Medical conditions database (rule-based fallback)
        self.conditions = self._load_conditions()

    def _init_llm(self):
        """Initialize LLM based on preferred backend"""

        if self.preferred_backend == AIBackend.GROQ and GROQ_AVAILABLE:
            try:
                self.llm = ChatGroq(
                    model="llama-3.1-8b-instant",  # Fast, free tier friendly
                    temperature=0.1,
                    max_tokens=1024,
                )
                print("[AI] Groq LLM initialized (FREE tier)")
            except Exception as e:
                print(f"[AI] Groq init failed: {e}")

        elif self.preferred_backend == AIBackend.OLLAMA and OLLAMA_AVAILABLE:
            try:
                self.llm = ChatOllama(
                    model="llama3.2",  # Or mistral, gemma2
                    temperature=0.1,
                )
                print("[AI] Ollama LLM initialized (LOCAL)")
            except Exception as e:
                print(f"[AI] Ollama init failed: {e}")

        if self.llm is None:
            print("[AI] Using rule-based engine (no LLM)")

    def _load_conditions(self) -> Dict[str, Dict]:
        """Load medical conditions for rule-based engine"""
        return {
            "malaria": {
                "name": "Malaria",
                "symptoms": {
                    "fever": 0.9, "chills": 0.8, "headache": 0.7,
                    "muscle aches": 0.6, "nausea": 0.5, "fatigue": 0.6,
                    "vomiting": 0.5, "sweating": 0.4
                },
                "treatment": [
                    "Artemether-Lumefantrine based on weight",
                    "Paracetamol for fever and pain",
                    "Oral rehydration therapy",
                    "Rest and adequate nutrition",
                    "Follow-up in 3 days"
                ],
                "danger_signs": ["severe headache", "confusion", "difficulty breathing"]
            },
            "pneumonia": {
                "name": "Pneumonia",
                "symptoms": {
                    "cough": 0.9, "fever": 0.8, "difficulty breathing": 0.9,
                    "chest pain": 0.7, "fatigue": 0.6, "rapid breathing": 0.8
                },
                "treatment": [
                    "Amoxicillin based on age and weight",
                    "Oxygen therapy if SpO2 < 90%",
                    "Adequate fluid intake",
                    "Follow-up in 2-3 days"
                ],
                "danger_signs": ["difficulty breathing", "chest pain", "high fever"]
            },
            "hypertension": {
                "name": "Hypertension",
                "symptoms": {
                    "headache": 0.4, "dizziness": 0.5, "blurred vision": 0.6,
                    "chest pain": 0.3, "fatigue": 0.3
                },
                "treatment": [
                    "Lifestyle modifications",
                    "Regular BP monitoring",
                    "Antihypertensive if indicated",
                    "Reduce salt intake"
                ],
                "danger_signs": ["severe headache", "chest pain", "vision changes"]
            },
            "diabetes": {
                "name": "Diabetes Mellitus",
                "symptoms": {
                    "frequent urination": 0.8, "excessive thirst": 0.8,
                    "weight loss": 0.7, "fatigue": 0.6, "blurred vision": 0.5
                },
                "treatment": [
                    "Blood glucose monitoring",
                    "Dietary modifications",
                    "Regular exercise",
                    "Medication as prescribed"
                ],
                "danger_signs": ["confusion", "fruity breath", "unconsciousness"]
            },
            "tuberculosis": {
                "name": "Tuberculosis",
                "symptoms": {
                    "persistent cough": 0.9, "coughing blood": 0.8,
                    "night sweats": 0.7, "weight loss": 0.7, "fever": 0.5
                },
                "treatment": [
                    "Refer for TB testing",
                    "DOTS therapy if confirmed",
                    "6-month treatment regimen",
                    "Contact tracing"
                ],
                "danger_signs": ["coughing blood", "severe weight loss"]
            }
        }

    async def analyze(
        self,
        symptoms: List[str],
        vital_signs: Dict[str, float],
        age: int,
        gender: str,
        chief_complaint: str = "",
        medical_history: List[str] = None
    ) -> MedicalAnalysis:
        """
        Analyze patient symptoms using hybrid approach

        1. First try LLM enhancement (if available)
        2. Fall back to rule-based engine
        3. Combine results for best accuracy
        """

        # Always run rule-based analysis (reliable baseline)
        rule_based_result = self._rule_based_analysis(
            symptoms, vital_signs, age, gender
        )

        # Try LLM enhancement if available
        llm_result = None
        if self.llm is not None:
            try:
                llm_result = await self._llm_analysis(
                    symptoms, vital_signs, age, gender,
                    chief_complaint, medical_history
                )
            except Exception as e:
                print(f"[AI] LLM analysis failed, using rule-based: {e}")

        # Combine results
        if llm_result:
            return self._combine_results(rule_based_result, llm_result)
        else:
            return rule_based_result

    def _rule_based_analysis(
        self,
        symptoms: List[str],
        vital_signs: Dict[str, float],
        age: int,
        gender: str
    ) -> MedicalAnalysis:
        """Rule-based medical analysis (always works)"""

        diagnoses = []
        normalized_symptoms = [s.lower().strip() for s in symptoms]

        for condition_key, condition in self.conditions.items():
            score = 0.0
            matching_symptoms = []

            for symptom_text in normalized_symptoms:
                for cond_symptom, weight in condition["symptoms"].items():
                    if cond_symptom in symptom_text or symptom_text in cond_symptom:
                        score += weight
                        matching_symptoms.append(cond_symptom)

            # Vital signs adjustments
            temp = vital_signs.get("temperature", 37.0)
            systolic = vital_signs.get("systolic_bp", 120)

            if condition_key == "malaria" and temp > 38.5:
                score += 0.3
            elif condition_key == "hypertension" and systolic > 140:
                score += 0.4
            elif condition_key == "pneumonia" and temp > 38.0:
                score += 0.2

            if score > 0.3:
                diagnoses.append({
                    "condition": condition["name"],
                    "confidence": min(score, 1.0),
                    "matching_symptoms": list(set(matching_symptoms)),
                    "treatment": condition["treatment"],
                    "danger_signs": condition["danger_signs"]
                })

        # Sort by confidence
        diagnoses.sort(key=lambda x: x["confidence"], reverse=True)

        # Determine triage level
        triage_level = self._assess_triage(vital_signs, normalized_symptoms)

        # Generate recommendations
        recommendations = []
        if diagnoses:
            recommendations = diagnoses[0]["treatment"][:3]
        recommendations.append("Follow up if symptoms worsen")

        return MedicalAnalysis(
            diagnoses=diagnoses[:3],
            triage_level=triage_level,
            recommendations=recommendations,
            confidence=diagnoses[0]["confidence"] if diagnoses else 0.0,
            ai_enhanced=False,
            backend_used="rule_based"
        )

    async def _llm_analysis(
        self,
        symptoms: List[str],
        vital_signs: Dict[str, float],
        age: int,
        gender: str,
        chief_complaint: str,
        medical_history: List[str]
    ) -> Optional[MedicalAnalysis]:
        """LLM-enhanced analysis using LangChain"""

        if not LANGCHAIN_AVAILABLE or self.llm is None:
            return None

        prompt = ChatPromptTemplate.from_messages([
            ("system", """You are a medical AI assistant for AfiCare MediLink,
a healthcare system for African settings. Analyze the patient data and provide
a structured medical assessment.

IMPORTANT: Always recommend professional medical evaluation. This is decision
support, not a diagnosis.

Respond in JSON format with:
{{
    "diagnoses": [
        {{
            "condition": "Name",
            "confidence": 0.0-1.0,
            "reasoning": "Why this condition",
            "treatment": ["treatment1", "treatment2"]
        }}
    ],
    "triage_level": "emergency|urgent|less_urgent|non_urgent",
    "recommendations": ["rec1", "rec2"],
    "warning_signs": ["sign1", "sign2"]
}}"""),
            ("human", """Patient Assessment:
- Age: {age} years, Gender: {gender}
- Chief Complaint: {chief_complaint}
- Symptoms: {symptoms}
- Vital Signs: Temperature {temp}°C, BP {bp}, Pulse {pulse}, RR {rr}
- Medical History: {history}

Provide your medical assessment:""")
        ])

        chain = prompt | self.llm | JsonOutputParser()

        try:
            result = await chain.ainvoke({
                "age": age,
                "gender": gender,
                "chief_complaint": chief_complaint or "Not specified",
                "symptoms": ", ".join(symptoms),
                "temp": vital_signs.get("temperature", "N/A"),
                "bp": f"{vital_signs.get('systolic_bp', 'N/A')}/{vital_signs.get('diastolic_bp', 'N/A')}",
                "pulse": vital_signs.get("pulse_rate", "N/A"),
                "rr": vital_signs.get("respiratory_rate", "N/A"),
                "history": ", ".join(medical_history) if medical_history else "None reported"
            })

            return MedicalAnalysis(
                diagnoses=result.get("diagnoses", []),
                triage_level=result.get("triage_level", "non_urgent"),
                recommendations=result.get("recommendations", []),
                confidence=result["diagnoses"][0]["confidence"] if result.get("diagnoses") else 0.5,
                ai_enhanced=True,
                backend_used="llm_" + self.preferred_backend.value
            )
        except Exception as e:
            print(f"[AI] LLM parsing error: {e}")
            return None

    def _combine_results(
        self,
        rule_based: MedicalAnalysis,
        llm_result: MedicalAnalysis
    ) -> MedicalAnalysis:
        """Combine rule-based and LLM results for best accuracy"""

        # Use LLM's natural language understanding
        # But validate against rule-based for safety

        combined_diagnoses = []

        # Add LLM diagnoses that are supported by rules
        for llm_diag in llm_result.diagnoses:
            for rule_diag in rule_based.diagnoses:
                if llm_diag["condition"].lower() in rule_diag["condition"].lower():
                    # Boost confidence when both agree
                    combined_diagnoses.append({
                        **llm_diag,
                        "confidence": min(
                            (llm_diag["confidence"] + rule_diag["confidence"]) / 2 + 0.1,
                            1.0
                        ),
                        "validated": True
                    })
                    break
            else:
                # LLM-only diagnosis (lower confidence)
                combined_diagnoses.append({
                    **llm_diag,
                    "confidence": llm_diag["confidence"] * 0.8,
                    "validated": False
                })

        # Use stricter triage level
        triage_priority = ["emergency", "urgent", "less_urgent", "non_urgent"]
        rule_idx = triage_priority.index(rule_based.triage_level)
        llm_idx = triage_priority.index(llm_result.triage_level)
        final_triage = triage_priority[min(rule_idx, llm_idx)]

        return MedicalAnalysis(
            diagnoses=combined_diagnoses[:3],
            triage_level=final_triage,
            recommendations=llm_result.recommendations or rule_based.recommendations,
            confidence=max(rule_based.confidence, llm_result.confidence),
            ai_enhanced=True,
            backend_used="hybrid"
        )

    def _assess_triage(
        self,
        vital_signs: Dict[str, float],
        symptoms: List[str]
    ) -> str:
        """Assess triage level based on vital signs and symptoms"""

        emergency_symptoms = [
            "difficulty breathing", "chest pain", "unconscious",
            "severe bleeding", "convulsions"
        ]

        for symptom in symptoms:
            if any(es in symptom for es in emergency_symptoms):
                return "emergency"

        temp = vital_signs.get("temperature", 37.0)
        systolic = vital_signs.get("systolic_bp", 120)
        resp_rate = vital_signs.get("respiratory_rate", 16)

        if temp > 40 or systolic > 180 or resp_rate > 30:
            return "emergency"
        if temp > 39 or systolic > 160 or resp_rate > 24:
            return "urgent"
        if temp > 38 or systolic > 140:
            return "less_urgent"

        return "non_urgent"


# Convenience function for quick use
async def analyze_patient(
    symptoms: List[str],
    vital_signs: Dict[str, float],
    age: int,
    gender: str,
    use_ai: bool = True
) -> MedicalAnalysis:
    """Quick analysis function"""

    backend = AIBackend.GROQ if use_ai and GROQ_AVAILABLE else AIBackend.RULE_BASED
    agent = HybridMedicalAgent(preferred_backend=backend)

    return await agent.analyze(
        symptoms=symptoms,
        vital_signs=vital_signs,
        age=age,
        gender=gender
    )


# Example usage
if __name__ == "__main__":
    import asyncio

    async def test():
        result = await analyze_patient(
            symptoms=["fever", "chills", "headache", "fatigue"],
            vital_signs={"temperature": 39.5, "systolic_bp": 110},
            age=35,
            gender="male",
            use_ai=True
        )

        print(f"\n=== Medical Analysis ===")
        print(f"AI Enhanced: {result.ai_enhanced}")
        print(f"Backend: {result.backend_used}")
        print(f"Triage: {result.triage_level}")
        print(f"\nDiagnoses:")
        for d in result.diagnoses:
            print(f"  - {d['condition']}: {d['confidence']:.0%}")
        print(f"\nRecommendations:")
        for r in result.recommendations:
            print(f"  - {r}")

    asyncio.run(test())
