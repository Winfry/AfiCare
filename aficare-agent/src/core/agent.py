"""
AfiCare Medical Agent - Core Agent Implementation
"""

from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime
import logging

from ..llm.local_llm import LocalLLM
from ..rules.rule_engine import RuleEngine
from ..rules.triage_engine import TriageEngine
from ..memory.patient_store import PatientStore
from ..utils.config import Config

logger = logging.getLogger(__name__)


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


class AfiCareAgent:
    """Main medical AI agent for patient consultations"""
    
    def __init__(self, config: Config):
        self.config = config
        self.llm = LocalLLM(config)
        self.rule_engine = RuleEngine(config)
        self.triage_engine = TriageEngine(config)
        self.patient_store = PatientStore(config)
        
        logger.info("AfiCare Agent initialized successfully")
    
    async def conduct_consultation(self, patient_data: PatientData) -> ConsultationResult:
        """
        Conduct a complete medical consultation
        
        Args:
            patient_data: Patient information and symptoms
            
        Returns:
            ConsultationResult with diagnosis and recommendations
        """
        try:
            logger.info(f"Starting consultation for patient {patient_data.patient_id}")
            
            # Step 1: Triage assessment
            triage_result = await self.triage_engine.assess_urgency(patient_data)
            
            # Step 2: Symptom analysis and condition matching
            condition_matches = await self.rule_engine.analyze_symptoms(
                patient_data.symptoms,
                patient_data.vital_signs,
                patient_data.age,
                patient_data.gender
            )
            
            # Step 3: LLM-based reasoning for complex cases
            llm_analysis = await self.llm.analyze_case(
                patient_data,
                condition_matches,
                triage_result
            )
            
            # Step 4: Generate recommendations
            recommendations = await self._generate_recommendations(
                patient_data,
                condition_matches,
                llm_analysis,
                triage_result
            )
            
            # Step 5: Create consultation result
            result = ConsultationResult(
                patient_id=patient_data.patient_id,
                timestamp=datetime.now(),
                triage_level=triage_result.level,
                suspected_conditions=condition_matches,
                recommendations=recommendations,
                referral_needed=triage_result.requires_referral,
                follow_up_required=self._requires_follow_up(condition_matches),
                confidence_score=llm_analysis.get('confidence', 0.0)
            )
            
            # Step 6: Store consultation record
            await self.patient_store.save_consultation(result)
            
            logger.info(f"Consultation completed for patient {patient_data.patient_id}")
            return result
            
        except Exception as e:
            logger.error(f"Error during consultation: {str(e)}")
            raise
    
    async def _generate_recommendations(
        self,
        patient_data: PatientData,
        conditions: List[Dict],
        llm_analysis: Dict,
        triage_result: Any
    ) -> List[str]:
        """Generate treatment and care recommendations"""
        
        recommendations = []
        
        # Emergency recommendations
        if triage_result.level == "emergency":
            recommendations.append("IMMEDIATE MEDICAL ATTENTION REQUIRED")
            recommendations.append("Transfer to emergency department")
        
        # Condition-specific recommendations
        for condition in conditions:
            if condition['confidence'] > 0.7:
                condition_name = condition['name']
                
                # Get standard treatment protocols
                protocols = await self.rule_engine.get_treatment_protocol(condition_name)
                recommendations.extend(protocols)
        
        # LLM-generated recommendations
        if llm_analysis.get('recommendations'):
            recommendations.extend(llm_analysis['recommendations'])
        
        # General care recommendations
        recommendations.extend([
            "Monitor symptoms and return if condition worsens",
            "Ensure adequate rest and hydration",
            "Follow medication instructions carefully"
        ])
        
        return recommendations
    
    def _requires_follow_up(self, conditions: List[Dict]) -> bool:
        """Determine if follow-up is required based on conditions"""
        
        follow_up_conditions = [
            'hypertension', 'diabetes', 'tuberculosis', 'hiv'
        ]
        
        for condition in conditions:
            if condition['name'].lower() in follow_up_conditions:
                return True
                
        return False
    
    async def get_patient_history(self, patient_id: str) -> Dict[str, Any]:
        """Retrieve patient consultation history"""
        return await self.patient_store.get_patient_history(patient_id)
    
    async def update_patient_data(self, patient_id: str, updates: Dict[str, Any]) -> bool:
        """Update patient information"""
        return await self.patient_store.update_patient(patient_id, updates)
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get agent system status and health"""
        return {
            "status": "operational",
            "llm_loaded": self.llm.is_loaded(),
            "rules_loaded": len(self.rule_engine.get_loaded_rules()),
            "database_connected": self.patient_store.is_connected(),
            "timestamp": datetime.now().isoformat()
        }