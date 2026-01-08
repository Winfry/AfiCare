"""
Medical Rule Engine for AfiCare Agent
Implements evidence-based medical decision rules and protocols
"""

import json
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class SymptomMatch:
    """Represents a symptom match with confidence"""
    symptom: str
    weight: float
    matched: bool
    confidence: float


@dataclass
class ConditionMatch:
    """Represents a condition match result"""
    name: str
    confidence: float
    matching_symptoms: List[SymptomMatch]
    risk_factors: List[str]
    severity: str
    recommendations: List[str]


class RuleEngine:
    """Medical rule engine for diagnostic reasoning"""
    
    def __init__(self, config):
        self.config = config
        self.conditions = {}
        self.treatment_protocols = {}
        self._load_medical_knowledge()
    
    def _load_medical_knowledge(self):
        """Load medical conditions and treatment protocols"""
        
        knowledge_base_path = Path("data/knowledge_base/conditions")
        
        if not knowledge_base_path.exists():
            logger.warning(f"Knowledge base path not found: {knowledge_base_path}")
            return
        
        # Load condition files
        for condition_file in knowledge_base_path.glob("*.json"):
            try:
                with open(condition_file, 'r', encoding='utf-8') as f:
                    condition_data = json.load(f)
                
                condition_name = condition_data.get('condition')
                if condition_name:
                    self.conditions[condition_name] = condition_data
                    logger.debug(f"Loaded condition: {condition_name}")
                
            except Exception as e:
                logger.error(f"Error loading condition file {condition_file}: {str(e)}")
        
        logger.info(f"Loaded {len(self.conditions)} medical conditions")
    
    async def analyze_symptoms(
        self,
        symptoms: List[str],
        vital_signs: Dict[str, float],
        age: int,
        gender: str,
        risk_factors: List[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Analyze symptoms against medical conditions
        
        Args:
            symptoms: List of reported symptoms
            vital_signs: Dictionary of vital sign measurements
            age: Patient age in years
            gender: Patient gender
            risk_factors: List of known risk factors
            
        Returns:
            List of condition matches with confidence scores
        """
        
        risk_factors = risk_factors or []
        condition_matches = []
        
        # Normalize symptoms for matching
        normalized_symptoms = [self._normalize_symptom(s) for s in symptoms]
        
        # Analyze each condition
        for condition_name, condition_data in self.conditions.items():
            
            match_result = self._match_condition(
                condition_data,
                normalized_symptoms,
                vital_signs,
                age,
                gender,
                risk_factors
            )
            
            if match_result.confidence > 0.1:  # Only include significant matches
                condition_matches.append({
                    'name': condition_name,
                    'display_name': condition_data.get('name', condition_name),
                    'confidence': match_result.confidence,
                    'matching_symptoms': [
                        {
                            'symptom': sm.symptom,
                            'weight': sm.weight,
                            'matched': sm.matched
                        }
                        for sm in match_result.matching_symptoms
                    ],
                    'risk_factors': match_result.risk_factors,
                    'severity': match_result.severity,
                    'category': condition_data.get('category', 'unknown'),
                    'recommendations': match_result.recommendations
                })
        
        # Sort by confidence (highest first)
        condition_matches.sort(key=lambda x: x['confidence'], reverse=True)
        
        return condition_matches[:10]  # Return top 10 matches
    
    def _match_condition(
        self,
        condition_data: Dict[str, Any],
        symptoms: List[str],
        vital_signs: Dict[str, float],
        age: int,
        gender: str,
        risk_factors: List[str]
    ) -> ConditionMatch:
        """Match symptoms against a specific condition"""
        
        condition_name = condition_data.get('name', 'Unknown')
        
        # Get symptom weights for this condition
        primary_symptoms = condition_data.get('symptoms', {}).get('primary', [])
        secondary_symptoms = condition_data.get('symptoms', {}).get('secondary', [])
        
        all_symptoms = primary_symptoms + secondary_symptoms
        
        # Calculate symptom matches
        symptom_matches = []
        total_symptom_score = 0.0
        max_possible_score = 0.0
        
        for symptom_def in all_symptoms:
            symptom_name = symptom_def.get('name', '')
            symptom_weight = symptom_def.get('weight', 0.5)
            
            # Check if this symptom is present
            matched = any(
                self._symptoms_similar(symptom_name, reported_symptom)
                for reported_symptom in symptoms
            )
            
            symptom_match = SymptomMatch(
                symptom=symptom_name,
                weight=symptom_weight,
                matched=matched,
                confidence=symptom_weight if matched else 0.0
            )
            
            symptom_matches.append(symptom_match)
            
            if matched:
                total_symptom_score += symptom_weight
            
            max_possible_score += symptom_weight
        
        # Calculate base confidence from symptoms
        symptom_confidence = (
            total_symptom_score / max_possible_score
            if max_possible_score > 0 else 0.0
        )
        
        # Factor in vital signs
        vital_signs_boost = self._assess_vital_signs(condition_data, vital_signs)
        
        # Factor in risk factors
        risk_factor_boost = self._assess_risk_factors(
            condition_data, risk_factors, age, gender
        )
        
        # Factor in age and gender
        demographic_factor = self._assess_demographics(
            condition_data, age, gender
        )
        
        # Combine all factors
        final_confidence = min(
            symptom_confidence + vital_signs_boost + risk_factor_boost + demographic_factor,
            1.0
        )
        
        # Determine severity
        severity = self._determine_severity(
            condition_data, symptoms, vital_signs, age
        )
        
        # Get basic recommendations
        recommendations = self._get_basic_recommendations(
            condition_data, severity
        )
        
        # Get matching risk factors
        matching_risk_factors = self._get_matching_risk_factors(
            condition_data, risk_factors
        )
        
        return ConditionMatch(
            name=condition_name,
            confidence=final_confidence,
            matching_symptoms=symptom_matches,
            risk_factors=matching_risk_factors,
            severity=severity,
            recommendations=recommendations
        )
    
    def _normalize_symptom(self, symptom: str) -> str:
        """Normalize symptom text for matching"""
        
        # Convert to lowercase and remove extra spaces
        normalized = symptom.lower().strip()
        
        # Replace common variations
        replacements = {
            'difficulty breathing': 'dyspnea',
            'shortness of breath': 'dyspnea',
            'trouble breathing': 'dyspnea',
            'body aches': 'muscle_aches',
            'body pain': 'muscle_aches',
            'stomach pain': 'abdominal_pain',
            'belly pain': 'abdominal_pain',
            'throwing up': 'vomiting',
            'feeling sick': 'nausea'
        }
        
        for original, replacement in replacements.items():
            if original in normalized:
                normalized = replacement
                break
        
        # Replace spaces with underscores
        normalized = normalized.replace(' ', '_')
        
        return normalized
    
    def _symptoms_similar(self, condition_symptom: str, reported_symptom: str) -> bool:
        """Check if two symptoms are similar enough to match"""
        
        # Exact match
        if condition_symptom == reported_symptom:
            return True
        
        # Partial match
        if condition_symptom in reported_symptom or reported_symptom in condition_symptom:
            return True
        
        # Common synonyms
        synonyms = {
            'fever': ['high_temperature', 'pyrexia'],
            'cough': ['coughing'],
            'headache': ['head_pain'],
            'nausea': ['feeling_sick', 'queasiness'],
            'vomiting': ['throwing_up', 'emesis'],
            'diarrhea': ['loose_stools', 'watery_stools'],
            'fatigue': ['tiredness', 'weakness', 'exhaustion'],
            'dyspnea': ['difficulty_breathing', 'shortness_of_breath']
        }
        
        for main_symptom, synonym_list in synonyms.items():
            if (condition_symptom == main_symptom and reported_symptom in synonym_list) or \
               (reported_symptom == main_symptom and condition_symptom in synonym_list):
                return True
        
        return False
    
    def _assess_vital_signs(
        self,
        condition_data: Dict[str, Any],
        vital_signs: Dict[str, float]
    ) -> float:
        """Assess vital signs for condition-specific patterns"""
        
        boost = 0.0
        condition_name = condition_data.get('condition', '')
        
        # Temperature assessment
        temp = vital_signs.get('temperature', 37.0)
        if condition_name in ['malaria', 'pneumonia', 'tuberculosis']:
            if temp > 38.5:  # High fever
                boost += 0.2
            elif temp > 37.5:  # Low-grade fever
                boost += 0.1
        
        # Blood pressure assessment
        systolic_bp = vital_signs.get('systolic_bp')
        if condition_name == 'hypertension' and systolic_bp:
            if systolic_bp > 140:
                boost += 0.3
            elif systolic_bp > 130:
                boost += 0.1
        
        # Respiratory rate assessment
        resp_rate = vital_signs.get('respiratory_rate')
        if condition_name == 'pneumonia' and resp_rate:
            if resp_rate > 24:
                boost += 0.2
            elif resp_rate > 20:
                boost += 0.1
        
        # Heart rate assessment
        pulse = vital_signs.get('pulse')
        if pulse:
            if pulse > 100:  # Tachycardia
                if condition_name in ['malaria', 'pneumonia']:
                    boost += 0.1
        
        return min(boost, 0.3)  # Cap boost at 0.3
    
    def _assess_risk_factors(
        self,
        condition_data: Dict[str, Any],
        risk_factors: List[str],
        age: int,
        gender: str
    ) -> float:
        """Assess risk factors for the condition"""
        
        condition_risk_factors = condition_data.get('risk_factors', [])
        boost = 0.0
        
        for risk_factor_def in condition_risk_factors:
            factor_name = risk_factor_def.get('factor', '')
            factor_weight = risk_factor_def.get('weight', 0.1)
            
            # Check if this risk factor is present
            if any(factor_name in rf.lower() for rf in risk_factors):
                boost += factor_weight * 0.5  # Scale down risk factor contribution
        
        return min(boost, 0.2)  # Cap boost at 0.2
    
    def _assess_demographics(
        self,
        condition_data: Dict[str, Any],
        age: int,
        gender: str
    ) -> float:
        """Assess demographic factors"""
        
        boost = 0.0
        condition_name = condition_data.get('condition', '')
        
        # Age-based factors
        if condition_name == 'pneumonia':
            if age < 2 or age > 65:
                boost += 0.1
        elif condition_name == 'hypertension':
            if age > 45:
                boost += 0.05
        elif condition_name == 'diabetes':
            if age > 45:
                boost += 0.05
        
        # Gender-based factors (if any specific patterns exist)
        # This can be expanded based on epidemiological data
        
        return boost
    
    def _determine_severity(
        self,
        condition_data: Dict[str, Any],
        symptoms: List[str],
        vital_signs: Dict[str, float],
        age: int
    ) -> str:
        """Determine condition severity based on symptoms and vital signs"""
        
        # Check for danger signs
        danger_signs = [
            'altered_consciousness', 'confusion', 'convulsions',
            'severe_respiratory_distress', 'cyanosis', 'shock'
        ]
        
        for danger_sign in danger_signs:
            if any(danger_sign in symptom for symptom in symptoms):
                return 'severe'
        
        # Check vital signs for severity
        temp = vital_signs.get('temperature', 37.0)
        resp_rate = vital_signs.get('respiratory_rate', 16)
        pulse = vital_signs.get('pulse', 80)
        
        severe_vitals = (
            temp > 40.0 or temp < 35.0 or
            resp_rate > 30 or resp_rate < 8 or
            pulse > 120 or pulse < 50
        )
        
        if severe_vitals:
            return 'severe'
        
        # Age-based severity (very young or very old)
        if age < 1 or age > 75:
            return 'moderate'
        
        return 'mild'
    
    def _get_basic_recommendations(
        self,
        condition_data: Dict[str, Any],
        severity: str
    ) -> List[str]:
        """Get basic treatment recommendations"""
        
        recommendations = []
        
        # Get treatment information
        treatment = condition_data.get('treatment', {})
        
        if severity == 'severe':
            recommendations.append("Immediate medical attention required")
            recommendations.append("Consider hospital referral")
        
        # Add general recommendations
        supportive_care = treatment.get('supportive_care', [])
        recommendations.extend(supportive_care[:3])  # Limit to top 3
        
        return recommendations
    
    def _get_matching_risk_factors(
        self,
        condition_data: Dict[str, Any],
        patient_risk_factors: List[str]
    ) -> List[str]:
        """Get risk factors that match the patient"""
        
        condition_risk_factors = condition_data.get('risk_factors', [])
        matching = []
        
        for risk_factor_def in condition_risk_factors:
            factor_name = risk_factor_def.get('factor', '')
            
            # Check if this risk factor matches any patient risk factors
            for patient_rf in patient_risk_factors:
                if factor_name.lower() in patient_rf.lower():
                    matching.append(risk_factor_def.get('description', factor_name))
                    break
        
        return matching
    
    async def get_treatment_protocol(self, condition_name: str) -> List[str]:
        """Get treatment protocol for a condition"""
        
        if condition_name not in self.conditions:
            return ["Treatment protocol not available for this condition"]
        
        condition_data = self.conditions[condition_name]
        treatment = condition_data.get('treatment', {})
        
        protocols = []
        
        # First-line treatment
        first_line = treatment.get('first_line', {})
        if 'uncomplicated' in first_line:
            for med in first_line['uncomplicated']:
                protocols.append(
                    f"{med.get('medication', 'Unknown')} - "
                    f"{med.get('dosage', 'See guidelines')} for "
                    f"{med.get('duration', 'prescribed duration')}"
                )
        
        # Supportive care
        supportive = treatment.get('supportive_care', [])
        protocols.extend(supportive)
        
        return protocols if protocols else ["No specific treatment protocol available"]
    
    def get_loaded_rules(self) -> List[str]:
        """Get list of loaded medical conditions"""
        return list(self.conditions.keys())
    
    def get_condition_info(self, condition_name: str) -> Optional[Dict[str, Any]]:
        """Get detailed information about a condition"""
        return self.conditions.get(condition_name)