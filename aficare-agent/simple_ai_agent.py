#!/usr/bin/env python3
"""
Simplified AfiCare AI Agent - Works without complex dependencies
Demonstrates the AI capabilities with basic rule-based logic
"""

import streamlit as st
from datetime import datetime
import json
from typing import Dict, List, Any, Optional
from dataclasses import dataclass

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

class SimplifiedAfiCareAgent:
    """Simplified AfiCare AI Agent with rule-based medical logic"""
    
    def __init__(self):
        self.conditions = self._load_medical_conditions()
        self.name = "AfiCare AI Agent (Simplified)"
        print(f"✅ {self.name} initialized with {len(self.conditions)} medical conditions")
    
    def _load_medical_conditions(self):
        """Load medical conditions and their diagnostic rules"""
        conditions = {}
        
        # Malaria
        conditions["malaria"] = {
            "name": "Malaria",
            "category": "Infectious Disease",
            "symptoms": {
                "fever": 0.9,
                "chills": 0.8,
                "headache": 0.7,
                "muscle_aches": 0.6,
                "nausea": 0.5,
                "fatigue": 0.6,
                "vomiting": 0.5,
                "sweating": 0.7
            },
            "vital_signs_weights": {
                "temperature": {"high": 0.8, "threshold": 38.0},
                "pulse": {"high": 0.3, "threshold": 100}
            },
            "treatment": [
                "Artemether-Lumefantrine (AL) 20/120mg based on weight",
                "Paracetamol 500mg every 6 hours for fever and pain",
                "Oral rehydration therapy (ORS)",
                "Rest and adequate nutrition",
                "Follow-up in 3 days or if symptoms worsen"
            ],
            "danger_signs": ["severe_headache", "confusion", "difficulty_breathing", "convulsions"],
            "age_factors": {"children": 0.2, "adults": 0.0}
        }
        
        # Pneumonia
        conditions["pneumonia"] = {
            "name": "Pneumonia",
            "category": "Respiratory Infection",
            "symptoms": {
                "cough": 0.9,
                "fever": 0.8,
                "difficulty_breathing": 0.9,
                "chest_pain": 0.7,
                "fatigue": 0.6,
                "rapid_breathing": 0.8,
                "chills": 0.6,
                "sputum_production": 0.5
            },
            "vital_signs_weights": {
                "temperature": {"high": 0.7, "threshold": 38.0},
                "respiratory_rate": {"high": 0.8, "threshold": 20}
            },
            "treatment": [
                "Amoxicillin 15mg/kg twice daily for 5 days (children)",
                "Amoxicillin 500mg three times daily for 5 days (adults)",
                "Oxygen therapy if SpO2 < 90%",
                "Adequate fluid intake and rest",
                "Follow-up in 2-3 days or if breathing worsens"
            ],
            "danger_signs": ["difficulty_breathing", "chest_pain", "high_fever", "confusion"],
            "age_factors": {"children": 0.3, "elderly": 0.2}
        }
        
        # Hypertension
        conditions["hypertension"] = {
            "name": "Hypertension",
            "category": "Cardiovascular",
            "symptoms": {
                "headache": 0.4,
                "dizziness": 0.5,
                "blurred_vision": 0.6,
                "chest_pain": 0.3,
                "fatigue": 0.3,
                "shortness_of_breath": 0.4
            },
            "vital_signs_weights": {
                "systolic_bp": {"high": 0.9, "threshold": 140},
                "diastolic_bp": {"high": 0.8, "threshold": 90}
            },
            "treatment": [
                "Lifestyle modifications (diet, exercise, weight management)",
                "Regular blood pressure monitoring",
                "Antihypertensive medication if BP >140/90",
                "Reduce salt intake to <2.3g/day",
                "Regular follow-up every 3-6 months"
            ],
            "danger_signs": ["severe_headache", "chest_pain", "difficulty_breathing", "vision_changes"],
            "age_factors": {"adults": 0.1, "elderly": 0.2}
        }
        
        # Common Cold/Flu
        conditions["common_cold"] = {
            "name": "Common Cold/Flu",
            "category": "Viral Infection",
            "symptoms": {
                "cough": 0.7,
                "runny_nose": 0.8,
                "sore_throat": 0.7,
                "headache": 0.5,
                "fatigue": 0.6,
                "muscle_aches": 0.4,
                "fever": 0.4,
                "sneezing": 0.6
            },
            "vital_signs_weights": {
                "temperature": {"mild": 0.3, "threshold": 37.5}
            },
            "treatment": [
                "Rest and adequate sleep (8+ hours)",
                "Increase fluid intake (water, warm teas)",
                "Paracetamol 500mg for fever and pain relief",
                "Warm salt water gargling for sore throat",
                "Return if symptoms worsen or persist >7 days"
            ],
            "danger_signs": ["high_fever", "difficulty_breathing", "severe_headache", "chest_pain"],
            "age_factors": {"children": 0.1, "elderly": 0.1}
        }
        
        return conditions
    
    def analyze_symptoms(self, patient_data: PatientData):
        """Analyze symptoms against medical conditions using AI-like logic"""
        
        results = []
        normalized_symptoms = [s.lower().replace(" ", "_") for s in patient_data.symptoms]
        
        for condition_name, condition_data in self.conditions.items():
            score = 0.0
            matching_symptoms = []
            
            # 1. Symptom matching with weighted scoring
            for symptom, weight in condition_data["symptoms"].items():
                if any(symptom in ns or ns in symptom for ns in normalized_symptoms):
                    score += weight
                    matching_symptoms.append(symptom.replace("_", " ").title())
            
            # 2. Vital signs analysis
            vital_weights = condition_data.get("vital_signs_weights", {})
            
            # Temperature analysis
            temp = patient_data.vital_signs.get("temperature", 37.0)
            if "temperature" in vital_weights:
                temp_config = vital_weights["temperature"]
                if temp > temp_config["threshold"]:
                    score += temp_config.get("high", 0.0)
            
            # Blood pressure analysis
            systolic_bp = patient_data.vital_signs.get("systolic_bp", 120)
            diastolic_bp = patient_data.vital_signs.get("diastolic_bp", 80)
            
            if "systolic_bp" in vital_weights and systolic_bp > vital_weights["systolic_bp"]["threshold"]:
                score += vital_weights["systolic_bp"]["high"]
            
            if "diastolic_bp" in vital_weights and diastolic_bp > vital_weights["diastolic_bp"]["threshold"]:
                score += vital_weights["diastolic_bp"]["high"]
            
            # Respiratory rate analysis
            resp_rate = patient_data.vital_signs.get("respiratory_rate", 16)
            if "respiratory_rate" in vital_weights and resp_rate > vital_weights["respiratory_rate"]["threshold"]:
                score += vital_weights["respiratory_rate"]["high"]
            
            # 3. Age factor adjustments
            age_factors = condition_data.get("age_factors", {})
            if patient_data.age < 18 and "children" in age_factors:
                score += age_factors["children"]
            elif patient_data.age > 65 and "elderly" in age_factors:
                score += age_factors["elderly"]
            elif patient_data.age >= 18 and "adults" in age_factors:
                score += age_factors["adults"]
            
            # 4. Medical history considerations
            history_text = " ".join(patient_data.medical_history).lower()
            if condition_name == "hypertension" and any(term in history_text for term in ["hypertension", "high blood pressure"]):
                score += 0.3
            elif condition_name == "pneumonia" and "asthma" in history_text:
                score += 0.2
            
            # 5. Only include significant matches
            if score > 0.2:
                confidence = min(score / 2.0, 1.0)  # Normalize to 0-1 range
                
                results.append({
                    "name": condition_name,
                    "display_name": condition_data["name"],
                    "category": condition_data["category"],
                    "confidence": confidence,
                    "matching_symptoms": matching_symptoms,
                    "treatment": condition_data["treatment"],
                    "danger_signs": condition_data.get("danger_signs", []),
                    "raw_score": score
                })
        
        # Sort by confidence (highest first)
        results.sort(key=lambda x: x["confidence"], reverse=True)
        return results
    
    def assess_triage(self, patient_data: PatientData, condition_matches: List[Dict]):
        """Assess urgency level using AI-like triage logic"""
        
        urgency_score = 0.0
        danger_signs = []
        
        # 1. Check symptoms for danger signs
        symptom_text = " ".join(patient_data.symptoms).lower()
        
        emergency_keywords = [
            "difficulty breathing", "chest pain", "unconscious", 
            "severe bleeding", "convulsions", "altered consciousness",
            "severe headache", "confusion", "high fever", "shortness of breath"
        ]
        
        for keyword in emergency_keywords:
            if keyword in symptom_text:
                urgency_score += 1.0
                danger_signs.append(keyword.title())
        
        # 2. Vital signs assessment
        temp = patient_data.vital_signs.get("temperature", 37.0)
        if temp > 40.0:
            urgency_score += 1.0
            danger_signs.append(f"Critical high fever: {temp}°C")
        elif temp < 35.0:
            urgency_score += 0.8
            danger_signs.append(f"Hypothermia: {temp}°C")
        elif temp > 38.5:
            urgency_score += 0.3
        
        pulse = patient_data.vital_signs.get("pulse", 80)
        if pulse > 120:
            urgency_score += 0.6
            danger_signs.append(f"Tachycardia: {pulse} bpm")
        elif pulse < 50:
            urgency_score += 0.7
            danger_signs.append(f"Bradycardia: {pulse} bpm")
        
        resp_rate = patient_data.vital_signs.get("respiratory_rate", 16)
        if resp_rate > 30:
            urgency_score += 0.8
            danger_signs.append(f"Tachypnea: {resp_rate}/min")
        elif resp_rate < 8:
            urgency_score += 0.9
            danger_signs.append(f"Bradypnea: {resp_rate}/min")
        
        systolic_bp = patient_data.vital_signs.get("systolic_bp", 120)
        if systolic_bp > 180:
            urgency_score += 0.7
            danger_signs.append(f"Hypertensive crisis: {systolic_bp} mmHg")
        elif systolic_bp < 90:
            urgency_score += 0.8
            danger_signs.append(f"Hypotension: {systolic_bp} mmHg")
        
        # 3. Age-based risk factors
        if patient_data.age < 1:
            urgency_score += 0.4
        elif patient_data.age < 5 or patient_data.age > 75:
            urgency_score += 0.2
        
        # 4. Condition-specific urgency
        for condition in condition_matches[:2]:  # Top 2 conditions
            if condition["confidence"] > 0.7:
                if condition["name"] in ["pneumonia", "malaria"]:
                    urgency_score += 0.3
                elif condition["name"] == "hypertension" and systolic_bp > 160:
                    urgency_score += 0.4
        
        # 5. Determine triage level
        if urgency_score >= 1.0:
            level = "EMERGENCY"
            referral = True
        elif urgency_score >= 0.6:
            level = "URGENT"
            referral = True
        elif urgency_score >= 0.3:
            level = "LESS_URGENT"
            referral = False
        else:
            level = "NON_URGENT"
            referral = False
        
        return {
            "level": level,
            "score": urgency_score,
            "danger_signs": danger_signs,
            "referral_needed": referral
        }
    
    async def conduct_consultation(self, patient_data: PatientData) -> ConsultationResult:
        """Conduct complete AI-powered medical consultation"""
        
        # 1. Analyze symptoms using AI logic
        condition_matches = self.analyze_symptoms(patient_data)
        
        # 2. Assess triage urgency
        triage_result = self.assess_triage(patient_data, condition_matches)
        
        # 3. Generate AI recommendations
        recommendations = []
        
        # Emergency recommendations
        if triage_result["level"] == "EMERGENCY":
            recommendations.append("🚨 IMMEDIATE MEDICAL ATTENTION REQUIRED")
            recommendations.append("Transfer to emergency department immediately")
            recommendations.append("Monitor vital signs continuously")
        
        # Condition-specific recommendations
        for condition in condition_matches[:2]:  # Top 2 conditions
            if condition["confidence"] > 0.4:
                recommendations.extend(condition["treatment"][:3])  # Top 3 treatments
        
        # General care recommendations
        if triage_result["level"] in ["NON_URGENT", "LESS_URGENT"]:
            recommendations.extend([
                "Monitor symptoms and return if condition worsens",
                "Ensure adequate rest and hydration",
                "Follow medication instructions carefully",
                "Maintain good hygiene practices"
            ])
        
        # 4. Determine follow-up requirements
        chronic_conditions = ["hypertension", "diabetes"]
        high_risk_conditions = ["pneumonia", "malaria"]
        
        follow_up_required = any([
            any(condition["name"] in chronic_conditions for condition in condition_matches if condition["confidence"] > 0.4),
            any(condition["name"] in high_risk_conditions for condition in condition_matches if condition["confidence"] > 0.6),
            triage_result["level"] in ["URGENT", "EMERGENCY"],
            patient_data.age < 5 or patient_data.age > 70
        ])
        
        # 5. Calculate overall confidence
        overall_confidence = condition_matches[0]["confidence"] if condition_matches else 0.0
        
        return ConsultationResult(
            patient_id=patient_data.patient_id,
            timestamp=datetime.now(),
            triage_level=triage_result["level"],
            suspected_conditions=condition_matches,
            recommendations=recommendations,
            referral_needed=triage_result["referral_needed"],
            follow_up_required=follow_up_required,
            confidence_score=overall_confidence
        )

# Test the simplified agent
if __name__ == "__main__":
    import asyncio
    
    async def test_simplified_agent():
        print("🤖 Testing Simplified AfiCare AI Agent")
        print("=" * 50)
        
        agent = SimplifiedAfiCareAgent()
        
        # Test case: Malaria symptoms
        patient = PatientData(
            patient_id="TEST-001",
            age=35,
            gender="Male",
            symptoms=["fever", "headache", "muscle aches", "chills"],
            vital_signs={
                "temperature": 39.2,
                "pulse": 98,
                "systolic_bp": 130,
                "diastolic_bp": 85,
                "respiratory_rate": 20
            },
            medical_history=["None"],
            current_medications=["None"],
            chief_complaint="High fever and body aches for 3 days"
        )
        
        result = await agent.conduct_consultation(patient)
        
        print(f"🎯 Triage Level: {result.triage_level}")
        print(f"📊 Confidence: {result.confidence_score:.1%}")
        print(f"🔍 Top Conditions:")
        for i, condition in enumerate(result.suspected_conditions[:3]):
            print(f"   {i+1}. {condition['display_name']} ({condition['confidence']:.1%})")
        
        print(f"💊 Recommendations:")
        for i, rec in enumerate(result.recommendations[:5]):
            print(f"   {i+1}. {rec}")
        
        print("\n✅ Simplified AI Agent working perfectly!")
    
    asyncio.run(test_simplified_agent())