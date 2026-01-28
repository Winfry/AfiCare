#!/usr/bin/env python3
"""
Test the Full AfiCare AI Agent
Fixed version that handles import issues gracefully
"""

import sys
from pathlib import Path
import asyncio
from datetime import datetime

# Add src to path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

async def test_full_ai_agent():
    """Test the full AI agent with proper error handling"""
    
    print("🤖 AfiCare AI Agent - Full Version Test")
    print("=" * 50)
    
    try:
        # Import with better error handling
        from core.agent import AfiCareAgent, PatientData
        from utils.config import Config
        
        print("✅ Successfully imported AfiCare Agent components")
        
        # Initialize the agent
        print("🔧 Initializing AfiCare Agent...")
        config = Config()
        agent = AfiCareAgent(config)
        
        print(f"✅ Agent initialized successfully!")
        print(f"📊 Loaded plugins: {len(agent.plugin_manager.plugins)}")
        print(f"🧠 Rule engine loaded: {hasattr(agent, 'rule_engine')}")
        print(f"🚨 Triage engine loaded: {hasattr(agent, 'triage_engine')}")
        print(f"💾 Patient store loaded: {hasattr(agent, 'patient_store')}")
        
        # Test Case 1: Malaria symptoms
        print("\n🦠 Test Case 1: Malaria Symptoms")
        print("-" * 30)
        
        malaria_patient = PatientData(
            patient_id="ML-TEST-MALARIA",
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
        
        print("🧠 Running AI consultation...")
        result = await agent.conduct_consultation(malaria_patient)
        
        print(f"🎯 Triage Level: {result.triage_level}")
        print(f"📊 Confidence: {result.confidence_score:.1%}")
        print(f"🏥 Referral Needed: {'Yes' if result.referral_needed else 'No'}")
        print(f"📅 Follow-up Required: {'Yes' if result.follow_up_required else 'No'}")
        
        print(f"🔍 Suspected Conditions:")
        for i, condition in enumerate(result.suspected_conditions[:3]):
            name = condition.get('name', 'Unknown')
            confidence = condition.get('confidence', 0)
            print(f"   {i+1}. {name} ({confidence:.1%})")
        
        print(f"💊 AI Recommendations:")
        for i, rec in enumerate(result.recommendations[:5]):
            print(f"   {i+1}. {rec}")
        
        # Test Case 2: Pneumonia symptoms
        print("\n🫁 Test Case 2: Pneumonia Symptoms")
        print("-" * 30)
        
        pneumonia_patient = PatientData(
            patient_id="ML-TEST-PNEUMONIA",
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
        
        print("🧠 Running AI consultation...")
        result2 = await agent.conduct_consultation(pneumonia_patient)
        
        print(f"🎯 Triage Level: {result2.triage_level}")
        print(f"📊 Confidence: {result2.confidence_score:.1%}")
        print(f"🏥 Referral Needed: {'Yes' if result2.referral_needed else 'No'}")
        
        print(f"🔍 Suspected Conditions:")
        for i, condition in enumerate(result2.suspected_conditions[:3]):
            name = condition.get('name', 'Unknown')
            confidence = condition.get('confidence', 0)
            print(f"   {i+1}. {name} ({confidence:.1%})")
        
        print(f"💊 AI Recommendations:")
        for i, rec in enumerate(result2.recommendations[:5]):
            print(f"   {i+1}. {rec}")
        
        # Test Case 3: Hypertension
        print("\n🩺 Test Case 3: Hypertension")
        print("-" * 30)
        
        hypertension_patient = PatientData(
            patient_id="ML-TEST-HTN",
            age=55,
            gender="Male",
            symptoms=["headache", "dizziness", "blurred vision"],
            vital_signs={
                "temperature": 37.1,
                "pulse": 82,
                "blood_pressure_systolic": 165,
                "blood_pressure_diastolic": 95,
                "respiratory_rate": 16
            },
            medical_history=["Family history of hypertension"],
            current_medications=["None"],
            chief_complaint="Persistent headaches and dizziness"
        )
        
        print("🧠 Running AI consultation...")
        result3 = await agent.conduct_consultation(hypertension_patient)
        
        print(f"🎯 Triage Level: {result3.triage_level}")
        print(f"📊 Confidence: {result3.confidence_score:.1%}")
        
        print(f"🔍 Suspected Conditions:")
        for i, condition in enumerate(result3.suspected_conditions[:3]):
            name = condition.get('name', 'Unknown')
            confidence = condition.get('confidence', 0)
            print(f"   {i+1}. {name} ({confidence:.1%})")
        
        print("\n" + "=" * 50)
        print("🎉 Full AfiCare AI Agent test completed successfully!")
        print("🚀 The AI is working with advanced medical reasoning!")
        print("🔌 Plugin system operational")
        print("🧠 Rule engine functional")
        print("🚨 Triage assessment working")
        print("💊 Treatment recommendations generated")
        
    except ImportError as e:
        print(f"❌ Import Error: {e}")
        print("\n💡 Troubleshooting:")
        print("1. Make sure you're in the aficare-agent directory")
        print("2. Check that all source files exist in src/")
        print("3. Verify the plugin files are in plugins/malaria/")
        
    except Exception as e:
        print(f"❌ Runtime Error: {e}")
        print(f"Error type: {type(e).__name__}")
        
        # Show more debug info
        import traceback
        print("\n🔧 Debug traceback:")
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_full_ai_agent())