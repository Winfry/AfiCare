"""
AfiCare AI Module - Hybrid Medical Intelligence

Available backends:
1. Rule-Based: Always works, no dependencies
2. Groq: FREE 30 req/min (cloud)
3. Ollama: FREE unlimited (local)
"""

from .hybrid_medical_agent import (
    HybridMedicalAgent,
    AIBackend,
    MedicalAnalysis,
    analyze_patient
)

__all__ = [
    "HybridMedicalAgent",
    "AIBackend",
    "MedicalAnalysis",
    "analyze_patient"
]
