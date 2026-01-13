"""
AfiCare Agent - FastAPI Backend
RESTful API for medical consultation services
"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime
import asyncio
import logging

try:
    from ..core.agent import AfiCareAgent, PatientData
    from ..utils.config import Config
    from ..utils.logger import setup_logging, log_medical_event
except ImportError:
    from core.agent import AfiCareAgent, PatientData
    from utils.config import Config
    from utils.logger import setup_logging, log_medical_event

logger = logging.getLogger(__name__)

# Pydantic models for API
class PatientRequest(BaseModel):
    patient_id: str
    age: int
    gender: str
    symptoms: List[str]
    vital_signs: Dict[str, float]
    medical_history: List[str] = []
    current_medications: List[str] = []
    chief_complaint: str
    risk_factors: List[str] = []

class ConsultationResponse(BaseModel):
    patient_id: str
    timestamp: datetime
    triage_level: str
    suspected_conditions: List[Dict[str, Any]]
    recommendations: List[str]
    referral_needed: bool
    follow_up_required: bool
    confidence_score: float

class SystemStatus(BaseModel):
    status: str
    llm_loaded: bool
    rules_loaded: int
    database_connected: bool
    timestamp: str

# Global agent instance
agent: Optional[AfiCareAgent] = None
config: Optional[Config] = None

def create_app(app_config: Config = None) -> FastAPI:
    """Create and configure FastAPI application"""
    
    global agent, config
    
    # Initialize configuration
    if app_config:
        config = app_config
    else:
        config = Config()
    
    # Setup logging
    setup_logging(config.get('app.log_level', 'INFO'))
    
    # Initialize agent
    agent = AfiCareAgent(config)
    
    # Create FastAPI app
    app = FastAPI(
        title="AfiCare Medical Agent API",
        description="AI-powered medical consultation and diagnostic support API",
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc"
    )
    
    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Configure appropriately for production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    return app

# Create app instance
app = create_app()

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "AfiCare Medical Agent API",
        "version": "0.1.0",
        "status": "operational"
    }

@app.get("/health", response_model=SystemStatus)
async def health_check():
    """Health check endpoint"""
    
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")
    
    status = agent.get_system_status()
    
    return SystemStatus(
        status=status.get("status", "unknown"),
        llm_loaded=status.get("llm_loaded", False),
        rules_loaded=status.get("rules_loaded", 0),
        database_connected=status.get("database_connected", False),
        timestamp=status.get("timestamp", datetime.now().isoformat())
    )

@app.post("/api/consultations", response_model=ConsultationResponse)
async def conduct_consultation(patient_request: PatientRequest):
    """Conduct medical consultation"""
    
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")
    
    try:
        # Convert request to PatientData
        patient_data = PatientData(
            patient_id=patient_request.patient_id,
            age=patient_request.age,
            gender=patient_request.gender,
            symptoms=patient_request.symptoms,
            vital_signs=patient_request.vital_signs,
            medical_history=patient_request.medical_history,
            current_medications=patient_request.current_medications,
            chief_complaint=patient_request.chief_complaint
        )
        
        # Conduct consultation
        result = await agent.conduct_consultation(patient_data)
        
        # Log consultation
        log_medical_event(
            "api_consultation",
            patient_request.patient_id,
            f"API consultation completed - Triage: {result.triage_level}"
        )
        
        return ConsultationResponse(
            patient_id=result.patient_id,
            timestamp=result.timestamp,
            triage_level=result.triage_level,
            suspected_conditions=result.suspected_conditions,
            recommendations=result.recommendations,
            referral_needed=result.referral_needed,
            follow_up_required=result.follow_up_required,
            confidence_score=result.confidence_score
        )
        
    except Exception as e:
        logger.error(f"Consultation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Consultation failed: {str(e)}")

@app.get("/api/patients/{patient_id}/history")
async def get_patient_history(patient_id: str):
    """Get patient consultation history"""
    
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")
    
    try:
        history = await agent.get_patient_history(patient_id)
        return history
        
    except Exception as e:
        logger.error(f"Failed to get patient history: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get patient history: {str(e)}")

@app.get("/api/conditions")
async def get_medical_conditions():
    """Get available medical conditions"""
    
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")
    
    try:
        conditions = agent.rule_engine.get_loaded_rules()
        
        condition_details = []
        for condition_name in conditions:
            condition_info = agent.rule_engine.get_condition_info(condition_name)
            if condition_info:
                condition_details.append({
                    'name': condition_name,
                    'display_name': condition_info.get('name', condition_name),
                    'category': condition_info.get('category', 'unknown'),
                    'icd10': condition_info.get('icd10', ''),
                    'prevalence': condition_info.get('prevalence', {})
                })
        
        return {
            'conditions': condition_details,
            'total': len(condition_details)
        }
        
    except Exception as e:
        logger.error(f"Failed to get conditions: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get conditions: {str(e)}")

@app.get("/api/conditions/{condition_name}")
async def get_condition_details(condition_name: str):
    """Get detailed information about a specific condition"""
    
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")
    
    try:
        condition_info = agent.rule_engine.get_condition_info(condition_name)
        
        if not condition_info:
            raise HTTPException(status_code=404, detail="Condition not found")
        
        return condition_info
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get condition details: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get condition details: {str(e)}")

@app.post("/api/triage")
async def assess_triage(patient_request: PatientRequest):
    """Assess patient triage level only"""
    
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")
    
    try:
        # Convert request to PatientData
        patient_data = PatientData(
            patient_id=patient_request.patient_id,
            age=patient_request.age,
            gender=patient_request.gender,
            symptoms=patient_request.symptoms,
            vital_signs=patient_request.vital_signs,
            medical_history=patient_request.medical_history,
            current_medications=patient_request.current_medications,
            chief_complaint=patient_request.chief_complaint
        )
        
        # Assess triage only
        triage_result = await agent.triage_engine.assess_urgency(patient_data)
        
        return {
            'patient_id': patient_request.patient_id,
            'triage_level': triage_result.level,
            'priority_score': triage_result.priority_score,
            'requires_referral': triage_result.requires_referral,
            'estimated_wait_time': triage_result.estimated_wait_time,
            'danger_signs': triage_result.danger_signs,
            'recommendations': triage_result.recommendations,
            'reasoning': triage_result.reasoning
        }
        
    except Exception as e:
        logger.error(f"Triage assessment failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Triage assessment failed: {str(e)}")

@app.get("/api/statistics")
async def get_statistics():
    """Get system statistics"""
    
    if not agent:
        raise HTTPException(status_code=503, detail="Agent not initialized")
    
    try:
        # Get patient store statistics
        patient_stats = agent.patient_store.get_statistics()
        
        # Get triage statistics
        triage_stats = agent.triage_engine.get_triage_statistics()
        
        # Get system status
        system_status = agent.get_system_status()
        
        return {
            'system': system_status,
            'patients': patient_stats,
            'triage': triage_stats,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Failed to get statistics: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get statistics: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    
    # Load configuration
    config = Config()
    
    # Run the server
    uvicorn.run(
        "main:app",
        host=config.get('api.host', '0.0.0.0'),
        port=config.get('api.port', 8000),
        reload=config.get('app.debug', False)
    )