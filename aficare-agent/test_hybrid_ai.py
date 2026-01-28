#!/usr/bin/env python3
"""
Test the Hybrid AI System
"""

import asyncio
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

def test_hybrid_ai():
    print("\n" + "=" * 60)
    print("   AFICARE HYBRID AI TEST")
    print("=" * 60)

    # Test imports
    print("\n[1] Testing imports...")
    try:
        from ai.hybrid_medical_agent import (
            HybridMedicalAgent,
            AIBackend,
            MedicalAnalysis,
            GROQ_AVAILABLE,
            OLLAMA_AVAILABLE
        )
        print("    [OK] Hybrid AI module imported")
    except ImportError as e:
        print(f"    [FAIL] Import error: {e}")
        return

    # Check backends
    print("\n[2] Checking AI backends...")
    print(f"    Rule-Based: [OK] Always available")
    print(f"    Groq Cloud: {'[OK] Connected' if GROQ_AVAILABLE else '[--] Not configured'}")
    print(f"    Ollama:     {'[OK] Connected' if OLLAMA_AVAILABLE else '[--] Not installed'}")

    # Determine backend
    if GROQ_AVAILABLE:
        backend = AIBackend.GROQ
        backend_name = "Groq Cloud (FREE)"
    elif OLLAMA_AVAILABLE:
        backend = AIBackend.OLLAMA
        backend_name = "Ollama Local (FREE)"
    else:
        backend = AIBackend.RULE_BASED
        backend_name = "Rule-Based (Offline)"

    print(f"\n[3] Using backend: {backend_name}")

    # Create agent
    print("\n[4] Creating Hybrid Medical Agent...")
    agent = HybridMedicalAgent(preferred_backend=backend)
    print("    [OK] Agent created")

    # Run analysis
    print("\n[5] Running test analysis...")
    print("    Patient: 35yo male")
    print("    Symptoms: fever, chills, headache, fatigue")
    print("    Temperature: 39.5°C")

    async def run_test():
        result = await agent.analyze(
            symptoms=["fever", "chills", "headache", "fatigue"],
            vital_signs={"temperature": 39.5, "systolic_bp": 110},
            age=35,
            gender="male",
            chief_complaint="Feeling very sick for 2 days"
        )
        return result

    result = asyncio.run(run_test())

    # Display results
    print("\n" + "=" * 60)
    print("   ANALYSIS RESULTS")
    print("=" * 60)

    print(f"\n    AI Enhanced: {result.ai_enhanced}")
    print(f"    Backend Used: {result.backend_used}")
    print(f"    Confidence: {result.confidence:.0%}")

    # Triage
    triage_colors = {
        "emergency": "!!! EMERGENCY !!!",
        "urgent": "!! URGENT !!",
        "less_urgent": "! Less Urgent",
        "non_urgent": "Non-Urgent"
    }
    print(f"\n    TRIAGE: {triage_colors.get(result.triage_level, result.triage_level)}")

    # Diagnoses
    print(f"\n    DIAGNOSES:")
    for i, diag in enumerate(result.diagnoses[:3], 1):
        print(f"      {i}. {diag['condition']} - {diag['confidence']:.0%}")
        if diag.get('matching_symptoms'):
            print(f"         Symptoms: {', '.join(diag['matching_symptoms'][:3])}")

    # Recommendations
    print(f"\n    RECOMMENDATIONS:")
    for rec in result.recommendations[:4]:
        print(f"      - {rec}")

    print("\n" + "=" * 60)
    print("   TEST COMPLETE")
    print("=" * 60)

    return True

if __name__ == "__main__":
    success = test_hybrid_ai()
    sys.exit(0 if success else 1)
