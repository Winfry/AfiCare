"""
Medical Reasoning Engine for AfiCare Agent
Handles complex medical decision-making and diagnostic reasoning
"""

from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum
import logging
import json

logger = logging.getLogger(__name__)


class ConfidenceLevel(Enum):
    """Confidence levels for medical assessments"""
    VERY_LOW = 0.2
    LOW = 0.4
    MODERATE = 0.6
    HIGH = 0.8
    VERY_HIGH = 0.95


@dataclass
class MedicalEvidence:
    """Represents a piece of medical evidence"""
    symptom: str
    weight: float
    supporting_conditions: List[str]
    contradicting_conditions: List[str]


@dataclass
class DiagnosticHypothesis:
    """Represents a diagnostic hypothesis"""
    condition: str
    probability: float
    supporting_evidence: List[MedicalEvidence]
    risk_factors: List[str]
    differential_diagnoses: List[str]


class ReasoningEngine:
    """Advanced medical reasoning engine using probabilistic inference"""
    
    def __init__(self, config):
        self.config = config
        self.symptom_weights = self._load_symptom_weights()
        self.condition_probabilities = self._load_condition_probabilities()
        self.risk_factor_weights = self._load_risk_factors()
        
    def _load_symptom_weights(self) -> Dict[str, Dict[str, float]]:
        """Load symptom-condition weight mappings"""
        return {
            "malaria": {
                "fever": 0.9,
                "headache": 0.7,
                "chills": 0.8,
                "muscle_aches": 0.6,
                "nausea": 0.5,
                "vomiting": 0.4,
                "fatigue": 0.6
            },
            "pneumonia": {
                "cough": 0.9,
                "fever": 0.8,
                "difficulty_breathing": 0.9,
                "chest_pain": 0.7,
                "fatigue": 0.6,
                "rapid_breathing": 0.8
            },
            "tuberculosis": {
                "persistent_cough": 0.9,
                "weight_loss": 0.8,
                "night_sweats": 0.7,
                "fever": 0.6,
                "fatigue": 0.6,
                "chest_pain": 0.5
            },
            "hypertension": {
                "headache": 0.4,
                "dizziness": 0.5,
                "blurred_vision": 0.6,
                "chest_pain": 0.3,
                "shortness_of_breath": 0.4
            },
            "diabetes": {
                "excessive_thirst": 0.8,
                "frequent_urination": 0.8,
                "unexplained_weight_loss": 0.7,
                "fatigue": 0.6,
                "blurred_vision": 0.5,
                "slow_healing": 0.6
            }
        }
    
    def _load_condition_probabilities(self) -> Dict[str, float]:
        """Load base prevalence rates for conditions"""
        return {
            "malaria": 0.15,  # 15% prevalence in endemic areas
            "pneumonia": 0.08,
            "tuberculosis": 0.03,
            "hypertension": 0.25,
            "diabetes": 0.12,
            "common_cold": 0.30,
            "gastroenteritis": 0.10
        }
    
    def _load_risk_factors(self) -> Dict[str, Dict[str, float]]:
        """Load risk factor weights for conditions"""
        return {
            "malaria": {
                "endemic_area": 0.8,
                "no_bed_net": 0.6,
                "recent_travel": 0.7,
                "rainy_season": 0.5
            },
            "tuberculosis": {
                "hiv_positive": 0.9,
                "malnutrition": 0.7,
                "overcrowded_living": 0.6,
                "smoking": 0.5
            },
            "diabetes": {
                "family_history": 0.7,
                "obesity": 0.8,
                "age_over_45": 0.6,
                "sedentary_lifestyle": 0.5
            }
        }
    
    async def generate_hypotheses(
        self,
        symptoms: List[str],
        vital_signs: Dict[str, float],
        patient_age: int,
        patient_gender: str,
        risk_factors: List[str] = None
    ) -> List[DiagnosticHypothesis]:
        """
        Generate diagnostic hypotheses based on symptoms and patient data
        
        Args:
            symptoms: List of reported symptoms
            vital_signs: Dictionary of vital sign measurements
            patient_age: Patient age in years
            patient_gender: Patient gender
            risk_factors: List of known risk factors
            
        Returns:
            List of diagnostic hypotheses ranked by probability
        """
        
        hypotheses = []
        risk_factors = risk_factors or []
        
        # Calculate probabilities for each condition
        for condition, base_prob in self.condition_probabilities.items():
            
            # Calculate symptom evidence
            symptom_evidence = self._calculate_symptom_evidence(
                condition, symptoms, vital_signs
            )
            
            # Calculate risk factor contribution
            risk_contribution = self._calculate_risk_factors(
                condition, risk_factors, patient_age, patient_gender
            )
            
            # Combine evidence using Bayesian inference
            posterior_prob = self._bayesian_update(
                base_prob, symptom_evidence, risk_contribution
            )
            
            if posterior_prob > 0.1:  # Only include significant hypotheses
                hypothesis = DiagnosticHypothesis(
                    condition=condition,
                    probability=posterior_prob,
                    supporting_evidence=self._get_supporting_evidence(
                        condition, symptoms
                    ),
                    risk_factors=self._get_relevant_risk_factors(
                        condition, risk_factors
                    ),
                    differential_diagnoses=self._get_differentials(condition)
                )
                hypotheses.append(hypothesis)
        
        # Sort by probability (highest first)
        hypotheses.sort(key=lambda h: h.probability, reverse=True)
        
        return hypotheses[:5]  # Return top 5 hypotheses
    
    def _calculate_symptom_evidence(
        self,
        condition: str,
        symptoms: List[str],
        vital_signs: Dict[str, float]
    ) -> float:
        """Calculate evidence strength from symptoms"""
        
        if condition not in self.symptom_weights:
            return 0.0
        
        condition_weights = self.symptom_weights[condition]
        total_evidence = 0.0
        max_possible = 0.0
        
        # Process reported symptoms
        for symptom in symptoms:
            symptom_clean = symptom.lower().replace(" ", "_")
            if symptom_clean in condition_weights:
                total_evidence += condition_weights[symptom_clean]
            max_possible += condition_weights.get(symptom_clean, 0.1)
        
        # Process vital signs
        vital_evidence = self._assess_vital_signs(condition, vital_signs)
        total_evidence += vital_evidence
        
        # Normalize evidence
        if max_possible > 0:
            return min(total_evidence / max_possible, 1.0)
        
        return 0.0
    
    def _assess_vital_signs(
        self,
        condition: str,
        vital_signs: Dict[str, float]
    ) -> float:
        """Assess vital signs for condition-specific patterns"""
        
        evidence = 0.0
        
        # Temperature assessment
        temp = vital_signs.get('temperature', 37.0)
        if condition in ['malaria', 'pneumonia', 'tuberculosis']:
            if temp > 38.5:  # High fever
                evidence += 0.3
            elif temp > 37.5:  # Low-grade fever
                evidence += 0.1
        
        # Blood pressure assessment
        systolic = vital_signs.get('systolic_bp', 120)
        if condition == 'hypertension':
            if systolic > 140:
                evidence += 0.4
            elif systolic > 130:
                evidence += 0.2
        
        # Respiratory rate assessment
        resp_rate = vital_signs.get('respiratory_rate', 16)
        if condition == 'pneumonia':
            if resp_rate > 24:
                evidence += 0.3
            elif resp_rate > 20:
                evidence += 0.1
        
        return evidence
    
    def _calculate_risk_factors(
        self,
        condition: str,
        risk_factors: List[str],
        age: int,
        gender: str
    ) -> float:
        """Calculate risk factor contribution"""
        
        if condition not in self.risk_factor_weights:
            return 0.0
        
        condition_risks = self.risk_factor_weights[condition]
        risk_score = 0.0
        
        # Process known risk factors
        for risk_factor in risk_factors:
            risk_clean = risk_factor.lower().replace(" ", "_")
            if risk_clean in condition_risks:
                risk_score += condition_risks[risk_clean]
        
        # Age-based risk factors
        if condition == 'hypertension' and age > 45:
            risk_score += 0.3
        elif condition == 'diabetes' and age > 45:
            risk_score += 0.4
        
        return min(risk_score, 1.0)
    
    def _bayesian_update(
        self,
        prior: float,
        symptom_evidence: float,
        risk_evidence: float
    ) -> float:
        """Update probability using Bayesian inference"""
        
        # Combine evidence
        combined_evidence = (symptom_evidence + risk_evidence) / 2
        
        # Bayesian update (simplified)
        likelihood = combined_evidence
        posterior = (likelihood * prior) / (
            (likelihood * prior) + ((1 - likelihood) * (1 - prior))
        )
        
        return posterior
    
    def _get_supporting_evidence(
        self,
        condition: str,
        symptoms: List[str]
    ) -> List[MedicalEvidence]:
        """Get supporting evidence for a condition"""
        
        evidence_list = []
        
        if condition in self.symptom_weights:
            condition_weights = self.symptom_weights[condition]
            
            for symptom in symptoms:
                symptom_clean = symptom.lower().replace(" ", "_")
                if symptom_clean in condition_weights:
                    evidence = MedicalEvidence(
                        symptom=symptom,
                        weight=condition_weights[symptom_clean],
                        supporting_conditions=[condition],
                        contradicting_conditions=[]
                    )
                    evidence_list.append(evidence)
        
        return evidence_list
    
    def _get_relevant_risk_factors(
        self,
        condition: str,
        risk_factors: List[str]
    ) -> List[str]:
        """Get relevant risk factors for a condition"""
        
        if condition not in self.risk_factor_weights:
            return []
        
        condition_risks = self.risk_factor_weights[condition]
        relevant = []
        
        for risk_factor in risk_factors:
            risk_clean = risk_factor.lower().replace(" ", "_")
            if risk_clean in condition_risks:
                relevant.append(risk_factor)
        
        return relevant
    
    def _get_differentials(self, condition: str) -> List[str]:
        """Get differential diagnoses for a condition"""
        
        differentials = {
            "malaria": ["typhoid", "dengue", "viral_fever"],
            "pneumonia": ["tuberculosis", "bronchitis", "lung_cancer"],
            "tuberculosis": ["pneumonia", "lung_cancer", "bronchitis"],
            "hypertension": ["white_coat_hypertension", "kidney_disease"],
            "diabetes": ["hyperthyroidism", "kidney_disease"]
        }
        
        return differentials.get(condition, [])
    
    def get_confidence_level(self, probability: float) -> ConfidenceLevel:
        """Convert probability to confidence level"""
        
        if probability >= 0.9:
            return ConfidenceLevel.VERY_HIGH
        elif probability >= 0.7:
            return ConfidenceLevel.HIGH
        elif probability >= 0.5:
            return ConfidenceLevel.MODERATE
        elif probability >= 0.3:
            return ConfidenceLevel.LOW
        else:
            return ConfidenceLevel.VERY_LOW