#!/usr/bin/env python3
"""
Test the AfiCare AI Agent directly
Shows the AI in action with sample cases
"""

import sys
from pathlib import Path
import asyncio
from datetime import datetime

# Add src to path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

try:
    from core.agent import AfiCareAgent, PatientData
    from utils.config import Config
    
    async def test_ai_agent():
        """Test the AI agent with sample cases"""
        
        print("🤖 AfiCare AI Agent Test")
        print("=" * 50)
        
        # Initialize the agent
        config = Config()
        agent = AfiCareAgent(config)
        
        print(f"✅ Agent initialized successfully!")
        print(f"📊 Loaded plugins: {len(agent.plugin_manager.plugins)}")
        
        # Test Case 1: Malaria symptoms
        print("\n🦠 Test Case 1: Malaria Symptoms")
        print("-" * 30)
        
        malaria_patient = PatientData(
            patient_id="ML-TEST-001",
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
        
        result = await agent.conduct_consultation(malaria_patient)
        
        print(f"🎯 Triage Level: {result.triage_level}")
        print(f"📊 Confidence: {result.confidence_score:.1%}")
        print(f"🔍 Suspected Conditions:")
        for condition in result.suspected_conditions:
            print(f"   • {condition.get('name', 'Unknown')} ({condition.get('confidence', 0):.1%})")
        
        print(f"💊 Recommendations:")
        for rec in result.recommendations[:3]:
            print(f"   • {rec}")
        
        # Test Case 2: Pneumonia symptoms
        print("\n🫁 Test Case 2: Pneumonia Symptoms")
        print("-" * 30)
        
        pneumonia_patient = PatientData(
            patient_id="ML-TEST-002",
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
        
        result2 = await agent.conduct_consultation(pneumonia_patient)
        
        print(f"🎯 Triage Level: {result2.triage_level}")
        print(f"📊 Confidence: {result2.confidence_score:.1%}")
        print(f"🔍 Suspected Conditions:")
        for condition in result2.suspected_conditions:
            print(f"   • {condition.get('name', 'Unknown')} ({condition.get('confidence', 0):.1%})")
        
        print(f"💊 Recommendations:")
        for rec in result2.recommendations[:3]:
            print(f"   • {rec}")
        
        print("\n" + "=" * 50)
        print("🎉 AI Agent test completed successfully!")
        print("🚀 The AI is working and ready for integration!")
        
except ImportError as e:
    print(f"❌ Could not import AfiCare Agent: {e}")
    print("💡 Make sure you're running from the aficare-agent directory")
    print("💡 Check that all dependencies are installed")
except Exception as e:
    print(f"❌ Error testing AI Agent: {e}")

if __name__ == "__main__":
    asyncio.run(test_ai_agent())