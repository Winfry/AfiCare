"""
Medical Triage Engine for AfiCare Agent
Implements emergency triage and patient prioritization
"""

import logging
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)


class TriageLevel(Enum):
    """Triage priority levels"""
    EMERGENCY = "red"      # Immediate - Life threatening
    URGENT = "orange"      # Urgent - Potentially life threatening  
    LESS_URGENT = "yellow" # Less urgent - Significant but stable
    NON_URGENT = "green"   # Non-urgent - Minor conditions
    DECEASED = "blue"      # Deceased


@dataclass
class TriageResult:
    """Triage assessment result"""
    level: str
    priority_score: float
    requires_referral: bool
    estimated_wait_time: int  # minutes
    danger_signs: List[str]
    recommendations: List[str]
    reasoning: str


class TriageEngine:
    """Medical triage engine for patient prioritization"""
    
    def __init__(self, config):
        self.config = config
        self.emergency_keywords = config.get(
            'medical.emergency_keywords',
            ["chest pain", "difficulty breathing", "severe bleeding", "unconscious"]
        )
        self.high_priority_conditions = config.get(
            'medical.high_priority_conditions',
            ["malaria", "pneumonia", "severe dehydration"]
        )
        
        # Initialize triage criteria
        self._setup_triage_criteria()
    
    def _setup_triage_criteria(self):
        """Setup triage criteria and scoring rules"""
        
        # Danger signs that require immediate attention
        self.danger_signs = {
            'airway_breathing': [
                'severe difficulty breathing',
                'cannot speak in full sentences',
                'blue lips or fingernails',
                'stridor',
                'severe respiratory distress'
            ],
            'circulation': [
                'severe bleeding',
                'signs of shock',
                'weak or absent pulse',
                'cold and clammy skin',
                'severe dehydration'
            ],
            'neurological': [
                'unconscious',
                'altered consciousness',
                'convulsions',
                'severe confusion',
                'neck stiffness with fever'
            ],
            'general': [
                'severe pain',
                'high fever with danger signs',
                'unable to drink or breastfeed',
                'vomits everything'
            ]
        }
        
        # Vital sign thresholds for different age groups
        self.vital_thresholds = {
            'adult': {
                'temperature': {'severe': 40.0, 'moderate': 38.5},
                'pulse': {'severe_high': 120, 'severe_low': 50, 'moderate_high': 100},
                'respiratory_rate': {'severe_high': 30, 'severe_low': 8, 'moderate_high': 24},
                'systolic_bp': {'severe_high': 180, 'severe_low': 90, 'moderate_high': 160}
            },
            'child': {
                'temperature': {'severe': 40.0, 'moderate': 38.5},
                'pulse': {'severe_high': 160, 'severe_low': 60, 'moderate_high': 140},
                'respiratory_rate': {'severe_high': 50, 'severe_low': 15, 'moderate_high': 40}
            },
            'infant': {
                'temperature': {'severe': 39.0, 'moderate': 38.0},
                'pulse': {'severe_high': 180, 'severe_low': 80, 'moderate_high': 160},
                'respiratory_rate': {'severe_high': 60, 'severe_low': 20, 'moderate_high': 50}
            }
        }
    
    async def assess_urgency(self, patient_data: Any) -> TriageResult:
        """
        Assess patient urgency and assign triage level
        
        Args:
            patient_data: Patient information including symptoms and vital signs
            
        Returns:
            TriageResult with triage level and recommendations
        """
        
        try:
            # Initialize scoring
            priority_score = 0.0
            danger_signs_found = []
            recommendations = []
            
            # Check for immediate danger signs
            danger_score, danger_signs_found = self._assess_danger_signs(
                patient_data.symptoms
            )
            priority_score += danger_score
            
            # Assess vital signs
            vital_score, vital_concerns = self._assess_vital_signs(
                patient_data.vital_signs,
                patient_data.age
            )
            priority_score += vital_score
            danger_signs_found.extend(vital_concerns)
            
            # Assess age-specific factors
            age_score = self._assess_age_factors(patient_data.age)
            priority_score += age_score
            
            # Assess symptom severity
            symptom_score = self._assess_symptom_severity(
                patient_data.symptoms,
                patient_data.chief_complaint
            )
            priority_score += symptom_score
            
            # Check for high-priority conditions
            condition_score = self._assess_condition_priority(patient_data.symptoms)
            priority_score += condition_score
            
            # Determine triage level based on total score
            triage_level, requires_referral = self._determine_triage_level(
                priority_score, danger_signs_found
            )
            
            # Generate recommendations
            recommendations = self._generate_triage_recommendations(
                triage_level, danger_signs_found, patient_data
            )
            
            # Estimate wait time
            wait_time = self._estimate_wait_time(triage_level)
            
            # Generate reasoning
            reasoning = self._generate_reasoning(
                priority_score, danger_signs_found, triage_level
            )
            
            result = TriageResult(
                level=triage_level,
                priority_score=priority_score,
                requires_referral=requires_referral,
                estimated_wait_time=wait_time,
                danger_signs=danger_signs_found,
                recommendations=recommendations,
                reasoning=reasoning
            )
            
            # Log triage decision
            logger.info(
                f"Triage assessment - Patient: {patient_data.patient_id}, "
                f"Level: {triage_level}, Score: {priority_score:.2f}"
            )
            
            return result
            
        except Exception as e:
            logger.error(f"Error in triage assessment: {str(e)}")
            # Return safe default for errors
            return TriageResult(
                level="urgent",
                priority_score=0.5,
                requires_referral=True,
                estimated_wait_time=30,
                danger_signs=["Assessment error - requires evaluation"],
                recommendations=["Immediate clinical assessment required"],
                reasoning="Triage assessment failed - defaulting to urgent care"
            )
    
    def _assess_danger_signs(self, symptoms: List[str]) -> tuple[float, List[str]]:
        """Assess for immediate danger signs"""
        
        score = 0.0
        found_signs = []
        
        # Convert symptoms to lowercase for matching
        symptom_text = ' '.join(symptoms).lower()
        
        # Check each category of danger signs
        for category, signs in self.danger_signs.items():
            for sign in signs:
                if sign.lower() in symptom_text:
                    found_signs.append(sign)
                    
                    # Different scoring based on severity
                    if category in ['airway_breathing', 'circulation', 'neurological']:
                        score += 1.0  # Maximum priority
                    else:
                        score += 0.7
        
        return min(score, 1.0), found_signs
    
    def _assess_vital_signs(
        self,
        vital_signs: Dict[str, float],
        age: int
    ) -> tuple[float, List[str]]:
        """Assess vital signs for abnormalities"""
        
        score = 0.0
        concerns = []
        
        # Determine age group
        if age < 1:
            age_group = 'infant'
        elif age < 18:
            age_group = 'child'
        else:
            age_group = 'adult'
        
        thresholds = self.vital_thresholds.get(age_group, self.vital_thresholds['adult'])
        
        # Temperature assessment
        temp = vital_signs.get('temperature')
        if temp:
            if temp >= thresholds['temperature']['severe']:
                score += 0.8
                concerns.append(f"Very high fever ({temp}°C)")
            elif temp <= 35.0:
                score += 0.9
                concerns.append(f"Hypothermia ({temp}°C)")
            elif temp >= thresholds['temperature']['moderate']:
                score += 0.3
                concerns.append(f"High fever ({temp}°C)")
        
        # Pulse assessment
        pulse = vital_signs.get('pulse')
        if pulse:
            if (pulse >= thresholds['pulse']['severe_high'] or 
                pulse <= thresholds['pulse']['severe_low']):
                score += 0.7
                concerns.append(f"Abnormal heart rate ({pulse} bpm)")
            elif pulse >= thresholds['pulse']['moderate_high']:
                score += 0.3
                concerns.append(f"Elevated heart rate ({pulse} bpm)")
        
        # Respiratory rate assessment
        resp_rate = vital_signs.get('respiratory_rate')
        if resp_rate:
            if (resp_rate >= thresholds['respiratory_rate']['severe_high'] or
                resp_rate <= thresholds['respiratory_rate']['severe_low']):
                score += 0.8
                concerns.append(f"Abnormal breathing rate ({resp_rate}/min)")
            elif resp_rate >= thresholds['respiratory_rate']['moderate_high']:
                score += 0.4
                concerns.append(f"Fast breathing ({resp_rate}/min)")
        
        # Blood pressure assessment (adults only)
        if age_group == 'adult':
            systolic_bp = vital_signs.get('systolic_bp')
            if systolic_bp:
                if systolic_bp >= thresholds['systolic_bp']['severe_high']:
                    score += 0.7
                    concerns.append(f"Severe hypertension ({systolic_bp} mmHg)")
                elif systolic_bp <= thresholds['systolic_bp']['severe_low']:
                    score += 0.8
                    concerns.append(f"Hypotension ({systolic_bp} mmHg)")
                elif systolic_bp >= thresholds['systolic_bp']['moderate_high']:
                    score += 0.3
                    concerns.append(f"High blood pressure ({systolic_bp} mmHg)")
        
        return min(score, 1.0), concerns
    
    def _assess_age_factors(self, age: int) -> float:
        """Assess age-related risk factors"""
        
        score = 0.0
        
        # Very young children (higher risk)
        if age < 2:
            score += 0.3
        elif age < 5:
            score += 0.2
        
        # Elderly (higher risk)
        elif age > 75:
            score += 0.3
        elif age > 65:
            score += 0.2
        
        return score
    
    def _assess_symptom_severity(
        self,
        symptoms: List[str],
        chief_complaint: str
    ) -> float:
        """Assess severity based on symptom descriptions"""
        
        score = 0.0
        
        # Combine all symptom text
        all_text = (chief_complaint + ' ' + ' '.join(symptoms)).lower()
        
        # Severity indicators
        severe_indicators = [
            'severe', 'excruciating', 'unbearable', 'worst ever',
            'sudden onset', 'rapidly worsening', 'getting worse'
        ]
        
        moderate_indicators = [
            'moderate', 'significant', 'troublesome', 'concerning'
        ]
        
        # Check for severity indicators
        for indicator in severe_indicators:
            if indicator in all_text:
                score += 0.4
                break
        
        for indicator in moderate_indicators:
            if indicator in all_text:
                score += 0.2
                break
        
        # Check for emergency keywords
        for keyword in self.emergency_keywords:
            if keyword.lower() in all_text:
                score += 0.5
                break
        
        return min(score, 0.8)
    
    def _assess_condition_priority(self, symptoms: List[str]) -> float:
        """Assess priority based on suspected conditions"""
        
        score = 0.0
        symptom_text = ' '.join(symptoms).lower()
        
        # High-priority condition indicators
        high_priority_indicators = {
            'malaria': ['fever', 'chills', 'headache'],
            'pneumonia': ['cough', 'fever', 'difficulty breathing'],
            'meningitis': ['headache', 'neck stiffness', 'fever'],
            'sepsis': ['fever', 'confusion', 'rapid pulse']
        }
        
        for condition, indicators in high_priority_indicators.items():
            matches = sum(1 for indicator in indicators if indicator in symptom_text)
            if matches >= 2:  # At least 2 indicators present
                score += 0.3
                break
        
        return min(score, 0.5)
    
    def _determine_triage_level(
        self,
        priority_score: float,
        danger_signs: List[str]
    ) -> tuple[str, bool]:
        """Determine triage level based on total score"""
        
        # Emergency level - immediate attention
        if priority_score >= 0.8 or danger_signs:
            return "emergency", True
        
        # Urgent level - within 30 minutes
        elif priority_score >= 0.6:
            return "urgent", True
        
        # Less urgent - within 2 hours
        elif priority_score >= 0.3:
            return "less_urgent", False
        
        # Non-urgent - routine care
        else:
            return "non_urgent", False
    
    def _generate_triage_recommendations(
        self,
        triage_level: str,
        danger_signs: List[str],
        patient_data: Any
    ) -> List[str]:
        """Generate triage-specific recommendations"""
        
        recommendations = []
        
        if triage_level == "emergency":
            recommendations.extend([
                "IMMEDIATE MEDICAL ATTENTION REQUIRED",
                "Prepare for emergency interventions",
                "Consider immediate referral to higher level facility"
            ])
            
            if danger_signs:
                recommendations.append(f"Address danger signs: {', '.join(danger_signs[:3])}")
        
        elif triage_level == "urgent":
            recommendations.extend([
                "Urgent medical evaluation needed",
                "Monitor vital signs closely",
                "Prepare for possible referral"
            ])
        
        elif triage_level == "less_urgent":
            recommendations.extend([
                "Medical evaluation within 2 hours",
                "Monitor for worsening symptoms",
                "Provide comfort measures"
            ])
        
        else:  # non_urgent
            recommendations.extend([
                "Routine medical evaluation",
                "Patient education and reassurance",
                "Schedule appropriate follow-up"
            ])
        
        return recommendations
    
    def _estimate_wait_time(self, triage_level: str) -> int:
        """Estimate wait time based on triage level"""
        
        wait_times = {
            "emergency": 0,      # Immediate
            "urgent": 15,        # 15 minutes
            "less_urgent": 60,   # 1 hour
            "non_urgent": 120    # 2 hours
        }
        
        return wait_times.get(triage_level, 60)
    
    def _generate_reasoning(
        self,
        priority_score: float,
        danger_signs: List[str],
        triage_level: str
    ) -> str:
        """Generate explanation for triage decision"""
        
        reasoning_parts = []
        
        reasoning_parts.append(f"Priority score: {priority_score:.2f}")
        
        if danger_signs:
            reasoning_parts.append(f"Danger signs identified: {len(danger_signs)}")
        
        reasoning_parts.append(f"Assigned triage level: {triage_level}")
        
        if triage_level == "emergency":
            reasoning_parts.append("Requires immediate medical intervention")
        elif triage_level == "urgent":
            reasoning_parts.append("Needs prompt medical attention")
        elif triage_level == "less_urgent":
            reasoning_parts.append("Stable but requires medical evaluation")
        else:
            reasoning_parts.append("Non-urgent condition suitable for routine care")
        
        return ". ".join(reasoning_parts)
    
    def get_triage_statistics(self) -> Dict[str, Any]:
        """Get triage system statistics"""
        
        return {
            "danger_sign_categories": len(self.danger_signs),
            "total_danger_signs": sum(len(signs) for signs in self.danger_signs.values()),
            "emergency_keywords": len(self.emergency_keywords),
            "high_priority_conditions": len(self.high_priority_conditions),
            "age_groups_supported": len(self.vital_thresholds)
        }