"""
AfiCare Agent - FastAPI Backend
RESTful API for medical consultation services
"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime
import asyncio, secrets, json
import logging

try:
    from ..core.agent import AfiCareAgent, PatientData
    from ..utils.config import Config
    from ..utils.logger import setup_logging, log_medical_event
    from ..database.enhanced_database_manager import EnhancedDatabaseManager
except ImportError:
    from core.agent import AfiCareAgent, PatientData
    from utils.config import Config
    from utils.logger import setup_logging, log_medical_event
    from database.enhanced_database_manager import EnhancedDatabaseManager

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

class AccessCodeRequest(BaseModel):
    medilink_id: str
    duration_hours: int = 24
    permissions: Optional[Dict[str, bool]] = None

class AccessCodeResponse(BaseModel):
    access_code: str
    share_url: str
    expires_at: str
    success: bool

# Global instances
agent: Optional[AfiCareAgent] = None
config: Optional[Config] = None
db: Optional[EnhancedDatabaseManager] = None

REQUEST_ACCESS_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Access Required - AfiCare</title>
<style>
  *{{margin:0;padding:0;box-sizing:border-box}}
  body{{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f0f4f8;color:#1a202c;padding:16px;display:flex;align-items:center;justify-content:center;min-height:100vh}}
  .card{{background:#fff;border-radius:12px;padding:32px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.1);max-width:400px}}
  .icon{{font-size:48px;margin-bottom:16px}}
  h2{{font-size:20px;margin-bottom:8px}}
  p{{color:#64748b;font-size:14px;margin-bottom:24px}}
  .code{{background:#f0f4f8;padding:12px;border-radius:8px;font-family:monospace;font-size:18px;font-weight:bold}}
  .footer{{text-align:center;font-size:12px;color:#94a3b8;margin-top:24px}}
</style>
</head>
<body>
<div class="card">
<div class="icon">🔐</div>
<h2>Access Code Required</h2>
<p>This patient's records are protected. Please ask the patient to share their access code from the AfiCare app.</p>
<p style="font-size:12px;color:#94a3b8">Patient MediLink ID: {}</p>
</div>
<div class="footer">Powered by AfiCare — AI-Powered Medical Assistant</div>
</body>
</html>"""

PATIENT_SUMMARY_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AfiCare - Patient Summary</title>
<style>
  *{{margin:0;padding:0;box-sizing:border-box}}
  body{{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f0f4f8;color:#1a202c;padding:16px}}
  .card{{background:#fff;border-radius:12px;padding:24px;margin-bottom:16px;box-shadow:0 1px 3px rgba(0,0,0,.1)}}
  .header{{background:linear-gradient(135deg,#2563eb,#1d4ed8);color:#fff;border-radius:12px;padding:24px;margin-bottom:16px;text-align:center}}
  .header h1{{font-size:22px;margin-bottom:4px}}
  .header .id{{font-size:13px;opacity:.8}}
  .header .meta{{font-size:12px;opacity:.7;margin-top:8px}}
  .badge{{display:inline-block;padding:4px 12px;border-radius:20px;font-size:12px;font-weight:600;margin:2px}}
  .badge-red{{background:#fee2e2;color:#dc2626}}
  .badge-green{{background:#dcfce7;color:#16a34a}}
  .badge-blue{{background:#dbeafe;color:#2563eb}}
  .badge-orange{{background:#ffedd5;color:#ea580c}}
  .badge-purple{{background:#f3e8ff;color:#7c3aed}}
  .label{{font-size:12px;color:#64748b;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px}}
  .value{{font-size:16px;color:#1a202c}}
  .grid{{display:grid;grid-template-columns:1fr 1fr;gap:12px}}
  .grid-3{{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px}}
  .footer{{text-align:center;font-size:12px;color:#94a3b8;margin-top:24px}}
  .expired{{background:#fef2f2;color:#dc2626;text-align:center;padding:40px;border-radius:12px}}
  .expired h2{{font-size:20px;margin-bottom:8px}}
  .vital{{text-align:center;padding:12px;background:#f8fafc;border-radius:8px}}
  .vital .v-label{{font-size:11px;color:#64748b;text-transform:uppercase}}
  .vital .v-value{{font-size:20px;font-weight:700;color:#1a202c}}
  .vital .v-unit{{font-size:12px;color:#64748b}}
  .diagnosis-entry{{padding:8px 0;border-bottom:1px solid #e2e8f0}}
  .diagnosis-entry:last-child{{border:none}}
  .rec-list{{list-style:none;padding:0}}
  .rec-list li{{padding:6px 0 6px 20px;position:relative;font-size:14px;color:#475569}}
  .rec-list li::before{{content:"\\25CF";position:absolute;left:0;color:#2563eb}}
  .section-title{{font-size:16px;font-weight:600;color:#1a202c;margin-bottom:12px;padding-bottom:8px;border-bottom:2px solid #e2e8f0}}
  .consult-card{{padding:16px;margin-bottom:12px;background:#f8fafc;border-radius:8px;border-left:4px solid #2563eb}}
  .consult-card.emergency{{border-left-color:#dc2626}}
  .consult-card.urgent{{border-left-color:#ea580c}}
  .consult-card.less_urgent{{border-left-color:#2563eb}}
  .consult-card.non_urgent{{border-left-color:#16a34a}}
  .consult-card .date{{font-size:12px;color:#64748b;margin-bottom:4px}}
  .consult-card .chief{{font-size:15px;font-weight:600;margin-bottom:6px}}
  .consult-card .detail-row{{font-size:13px;color:#475569;margin-bottom:2px}}
  .consult-card .detail-row strong{{color:#1a202c}}
  .tag{{display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:500;margin:1px;background:#f1f5f9;color:#475569}}
  .critical{{color:#dc2626;font-weight:700}}
  .btn{{display:inline-block;padding:10px 20px;border-radius:8px;font-size:14px;font-weight:600;text-decoration:none;text-align:center;margin:4px}}
  .btn-primary{{background:#2563eb;color:#fff}}
  .btn-outline{{border:1px solid #2563eb;color:#2563eb;background:transparent}}
  @media print{{.no-print{{display:none}}}}
</style>
</head>
<body>
{}
<div class="footer no-print">Powered by AfiCare — AI-Powered Medical Assistant</div>
</body>
</html>"""

def _fmt(val, default='N/A'):
    if val is None or val == '' or val == 'None reported':
        return default
    return str(val)

def _parse_json(val):
    if isinstance(val, (list, dict)):
        return val
    if isinstance(val, str):
        try:
            return json.loads(val)
        except (json.JSONDecodeError, TypeError):
            return []
    return []

def _safe_str_list(val):
    parsed = _parse_json(val)
    if isinstance(parsed, list):
        return [str(x) if isinstance(x, (str, int, float)) else x.get('name', str(x)) for x in parsed]
    if isinstance(parsed, str):
        return [parsed]
    return []

def _build_vitals_html(vital_signs):
    vs = _parse_json(vital_signs)
    if not vs or not isinstance(vs, dict):
        return ''
    vitals_map = {
        'bp': ('BP', 'mmHg'), 'hr': ('HR', 'bpm'), 'temp': ('Temp', '°C'),
        'rr': ('RR', '/min'), 'spo2': ('SpO₂', '%'), 'weight': ('Wt', 'kg'),
        'height': ('Ht', 'cm'), 'bmi': ('BMI', ''),
    }
    html = '<div class="grid-3" style="margin-top:8px">'
    for key, (label, unit) in vitals_map.items():
        if key in vs:
            val = vs[key]
            html += f'<div class="vital"><div class="v-label">{label}</div><div class="v-value">{val}</div><div class="v-unit">{unit}</div></div>'
    html += '</div>'
    return html

def _build_patient_page(patient: dict, consultations: list, expires_at: str, permissions: dict) -> str:
    name = _fmt(patient.get('full_name'))
    medilink_id = _fmt(patient.get('medilink_id'))
    age = _fmt(patient.get('age'))
    gender = _fmt(patient.get('gender'))
    phone = _fmt(patient.get('phone'))
    blood_type = _fmt(patient.get('blood_type'))
    allergies = patient.get('allergies') or ''
    chronic = patient.get('chronic_conditions') or ''
    dob = _fmt(patient.get('date_of_birth', ''), '')

    body = f'<div class="header"><h1>{name}</h1><div class="id">{medilink_id}</div>'
    if dob:
        body += f'<div class="meta">DOB: {dob[:10]}</div>'
    body += '</div>'

    # Demographics card
    body += '<div class="card"><div class="section-title">Patient Information</div><div class="grid">'
    body += f'<div><div class="label">Age</div><div class="value">{age}</div></div>'
    body += f'<div><div class="label">Gender</div><div class="value">{gender}</div></div>'
    body += f'<div><div class="label">Phone</div><div class="value">{phone}</div></div>'
    body += f'<div><div class="label">Blood Type</div><div class="value">{blood_type}</div></div>'
    body += '</div>'

    if allergies:
        body += f'<div style="margin-top:12px"><div class="label">Allergies</div><div>'
        for a in allergies.split(','):
            a = a.strip()
            if a:
                body += f'<span class="badge badge-red">{a}</span> '
        body += '</div></div>'

    if chronic:
        body += f'<div style="margin-top:12px"><div class="label">Chronic Conditions</div><div>'
        for c in chronic.split(','):
            c = c.strip()
            if c:
                body += f'<span class="badge badge-orange">{c}</span> '
        body += '</div></div>'

    body += '</div>'

    # Consultations
    if consultations:
        body += '<div class="card"><div class="section-title">Consultation History</div>'
        for c in consultations[:10]:
            date = _fmt(c.get('timestamp', ''))[:10]
            triage = c.get('triage_level', 'unknown')
            chief = _fmt(c.get('chief_complaint'))
            symptoms = c.get('symptoms', [])
            diagnoses = c.get('diagnoses', [])
            recommendations = c.get('recommendations', [])
            vitals = c.get('vital_signs', {})
            notes = _fmt(c.get('notes', ''))
            follow_up = c.get('follow_up_required', False)
            follow_up_date = c.get('follow_up_date', '')

            badge_class = {'emergency': 'badge-red', 'urgent': 'badge-orange', 'less_urgent': 'badge-blue'}.get(triage, 'badge-green')
            body += f'<div class="consult-card {triage}">'
            body += f'<div class="date">{date} <span class="badge {badge_class}">{triage}</span></div>'
            body += f'<div class="chief">{chief}</div>'

            vs_html = _build_vitals_html(vitals)
            if vs_html:
                body += vs_html

            symps = _safe_str_list(symptoms)
            if symps:
                body += f'<div class="detail-row" style="margin-top:6px"><strong>Symptoms:</strong> '
                body += ' '.join(f'<span class="tag">{s}</span>' for s in symps)
                body += '</div>'

            diags = _parse_json(diagnoses)
            if diags:
                body += f'<div class="detail-row" style="margin-top:6px"><strong>Diagnoses:</strong></div>'
                for d in diags:
                    d_name = d.get('name', str(d)) if isinstance(d, dict) else str(d)
                    d_code = d.get('code', '') if isinstance(d, dict) else ''
                    body += f'<div class="diagnosis-entry">{d_name} <span style="font-size:11px;color:#64748b">{d_code}</span></div>'

            recs = recommendations
            if isinstance(recs, str):
                recs = _safe_str_list(recs)
            if isinstance(recs, list) and recs:
                body += f'<div class="detail-row" style="margin-top:6px"><strong>Recommendations:</strong></div>'
                body += '<ul class="rec-list">'
                for r in recs:
                    body += f'<li>{str(r)}</li>'
                body += '</ul>'

            if notes:
                body += f'<div class="detail-row" style="margin-top:6px"><strong>Notes:</strong> {notes}</div>'

            if follow_up:
                fd = _fmt(follow_up_date, '')
                body += f'<div class="detail-row" style="margin-top:6px;color:#2563eb"><strong>Follow-up required:</strong> {fd if fd else "Yes"}</div>'

            body += '</div>'
        body += '</div>'

    # Expiry info
    body += f'<div class="card" style="text-align:center;font-size:13px;color:#64748b">This summary expires: {expires_at[:16] if expires_at else "N/A"}<br>Shared via AfiCare MediLink</div>'

    return PATIENT_SUMMARY_HTML.format(body)

def _build_expired_page() -> str:
    body = '<div class="expired"><h2>Link Expired</h2><p>This access link is no longer valid. Please ask the patient to generate a new one.</p></div>'
    body += '<div class="footer">Powered by AfiCare — AI-Powered Medical Assistant</div>'
    return PATIENT_SUMMARY_HTML.format(body)


def create_app(app_config: Config = None) -> FastAPI:
    """Create and configure FastAPI application"""
    
    global agent, config, db
    
    # Initialize configuration
    if app_config:
        config = app_config
    else:
        config = Config()
    
    # Setup logging
    setup_logging(config.get('app.log_level', 'INFO'))
    
    # Initialize agent
    agent = AfiCareAgent(config)
    
    # Initialize database
    db_path = config.get('database.url', 'sqlite:///./aficare.db')
    if db_path.startswith('sqlite:///'):
        db_path = db_path[10:]
    db = EnhancedDatabaseManager(db_path)
    
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
        allow_origins=["*"],
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

@app.post("/api/access-codes", response_model=AccessCodeResponse)
async def create_access_code(req: AccessCodeRequest):
    """Generate an access code and return a shareable URL"""
    global db
    if not db:
        raise HTTPException(status_code=503, detail="Database not initialized")
    permissions = req.permissions or {}
    success, code = db.generate_access_code(req.medilink_id, req.duration_hours, permissions)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to generate access code")
    from datetime import timedelta
    expires_at = (datetime.now() + timedelta(hours=req.duration_hours)).isoformat()
    share_url = f"/v/{code}"
    return AccessCodeResponse(access_code=code, share_url=share_url, expires_at=expires_at, success=True)

@app.get("/v/{code}", response_class=HTMLResponse)
async def view_patient_summary(code: str):
    """Public web view of patient summary (no app required)
    
    Accepts either:
    - A 6-digit access code → shows patient summary
    - A MediLink ID (ML-...)  → asks doctor to get an access code from patient
    """
    global db, agent
    if not db:
        raise HTTPException(status_code=503, detail="Database not initialized")
    
    # Case 1: Direct MediLink ID (from QR code) — show request-access page
    if code.startswith("ML-"):
        html = REQUEST_ACCESS_HTML.format(code)
        return HTMLResponse(content=html, status_code=200)
    
    # Case 2: Access code — verify and show patient summary
    success, medilink_id, permissions = db.verify_access_code(code, "web_viewer", mark_as_used=False)
    if not success or not medilink_id:
        return HTMLResponse(content=_build_expired_page(), status_code=200)
    
    try:
        import sqlite3
        with sqlite3.connect(db.db_path) as conn:
            cursor = conn.cursor()
            # Look up user by medilink_id (local users table)
            cursor.execute("SELECT * FROM users WHERE medilink_id = ?", (medilink_id,))
            ucols = [d[0] for d in cursor.description]
            urow = cursor.fetchone()
            patient = dict(zip(ucols, urow)) if urow else {}

            # Get extended patient profile (local patients table, joined by username/id)
            if patient.get('username'):
                cursor.execute("SELECT * FROM patients WHERE id = ?", (patient['username'],))
                pcols = [d[0] for d in cursor.description]
                prow = cursor.fetchone()
                if prow:
                    pdata = dict(zip(pcols, prow))
                    for k, v in pdata.items():
                        if k not in patient or patient[k] is None:
                            patient[k] = v

            # Get consultations (local consultations table)
            if patient.get('username'):
                cursor.execute("SELECT * FROM consultations WHERE patient_id = ? ORDER BY timestamp DESC LIMIT 10", (patient['username'],))
                ccols = [d[0] for d in cursor.description]
                consultations = [dict(zip(ccols, r)) for r in cursor.fetchall()]
            else:
                consultations = []
    except Exception as e:
        logger.error(f"Error loading patient data: {e}")
        patient, consultations = {}, []
    
    expires_str = "N/A"
    try:
        with sqlite3.connect(db.db_path) as conn:
            cur = conn.cursor()
            cur.execute('SELECT expires_at FROM access_codes_enhanced WHERE access_code = ?', (code,))
            row = cur.fetchone()
            if row:
                expires_str = str(row[0])[:16]
    except Exception:
        pass
    
    html = _build_patient_page(patient, consultations, expires_str, permissions or {})
    return HTMLResponse(content=html, status_code=200)

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

# ============================================================
# NEW API ENDPOINTS — Patient Search, Detail, Triage, Lab,
#                     Radiology, Referrals, Messages, Adherence
# ============================================================

class SearchRequest(BaseModel):
    q: str
    limit: int = 20

class TriageCheckinRequest(BaseModel):
    medilink_id: str
    triage_level: str
    priority_score: int = 0
    estimated_wait_time: int = 0
    danger_signs: List[str] = []
    chief_complaint: str = ""
    provider_username: str = ""

class LabOrderRequest(BaseModel):
    patient_medilink_id: str
    provider_username: str
    consultation_id: str = ""
    test_name: str
    test_category: str = "other"
    priority: str = "routine"
    notes: str = ""

class LabResultRequest(BaseModel):
    lab_order_id: str
    result_value: str = ""
    result_unit: str = ""
    reference_range_low: str = ""
    reference_range_high: str = ""
    result_flag: str = "normal"
    performed_by: str = ""
    notes: str = ""

class RadiologyOrderRequest(BaseModel):
    patient_medilink_id: str
    provider_username: str
    consultation_id: str = ""
    study_type: str
    body_part: str
    clinical_indication: str = ""
    priority: str = "routine"

class RadiologyReportRequest(BaseModel):
    radiology_order_id: str
    radiologist_name: str = ""
    findings: str
    impression: str = ""
    recommendations: str = ""

class ReferralRequest(BaseModel):
    patient_medilink_id: str
    from_username: str
    to_facility: str = ""
    to_provider_username: str = ""
    to_specialty: str = ""
    reason: str
    urgency: str = "routine"
    referral_notes: str = ""

class MessageRequest(BaseModel):
    sender_username: str
    receiver_username: str
    patient_medilink_id: str = ""
    content: str
    message_type: str = "text"
    reference_id: str = ""

class AdherenceRequest(BaseModel):
    prescription_id: str
    patient_medilink_id: str
    scheduled_time: str
    taken_time: str = ""
    skipped_reason: str = ""
    status: str = "pending"


def _get_db_cursor():
    import sqlite3
    if not db or not db.db_path:
        return None, None
    conn = sqlite3.connect(db.db_path)
    conn.row_factory = sqlite3.Row
    return conn, conn.cursor()


def _generate_uuid():
    return str(secrets.token_hex(16))


def _rows_to_dicts(cursor):
    cols = [d[0] for d in cursor.description]
    return [dict(zip(cols, r)) for r in cursor.fetchall()]


@app.get("/api/patients/search")
async def search_patients(q: str = "", limit: int = 20):
    """Search patients by name, MediLink ID, or phone"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        pattern = f"%{q}%"
        cur.execute('''
            SELECT username, full_name, medilink_id, phone, email, role, age, gender
            FROM users
            WHERE (full_name LIKE ? OR medilink_id LIKE ? OR phone LIKE ? OR username LIKE ?)
            AND role = 'patient'
            LIMIT ?
        ''', (pattern, pattern, pattern, pattern, limit))
        results = _rows_to_dicts(cur)
        conn.close()
        return {"patients": results, "total": len(results)}
    except Exception as e:
        logger.error(f"Search failed: {e}")
        raise HTTPException(500, f"Search failed: {e}")


@app.get("/api/patients/{patient_id}/detail")
async def get_patient_detail(patient_id: str):
    """Get full patient detail: profile + recent consultations"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")

        # Get user info
        cur.execute("SELECT * FROM users WHERE username = ? OR medilink_id = ?", (patient_id, patient_id))
        user = _rows_to_dicts(cur)
        if not user:
            conn.close()
            raise HTTPException(404, "Patient not found")
        user = user[0]

        result = {"user": user}

        try:
            cur.execute("SELECT * FROM patients WHERE id = ?", (user['username'],))
            patient_ext = _rows_to_dicts(cur)
            if patient_ext:
                result["profile"] = patient_ext[0]
        except Exception as e:
            logger.warning(f"Could not fetch patient profile: {e}")

        try:
            cur.execute("SELECT * FROM patient_profiles_enhanced WHERE medilink_id = ?", (user.get('medilink_id', ''),))
            enhanced = _rows_to_dicts(cur)
            if enhanced:
                result["enhanced"] = enhanced[0]
        except Exception as e:
            logger.warning(f"Could not fetch enhanced profile: {e}")

        try:
            cur.execute('''
                SELECT * FROM consultations
                WHERE patient_id = ? ORDER BY timestamp DESC LIMIT 10
            ''', (user['username'],))
            consultations = _rows_to_dicts(cur)
            if consultations:
                result["consultations"] = consultations
        except Exception as e:
            logger.warning(f"Could not fetch consultations: {e}")

        try:
            cur.execute('''
                SELECT lo.*, lr.result_value, lr.result_unit, lr.result_flag, lr.reference_range_low, lr.reference_range_high
                FROM lab_orders lo
                LEFT JOIN lab_results lr ON lr.lab_order_id = lo.id
                WHERE lo.patient_medilink_id = ?
                ORDER BY lo.ordered_at DESC LIMIT 10
            ''', (user.get('medilink_id', ''),))
            labs = _rows_to_dicts(cur)
            if labs:
                result["labs"] = labs
        except Exception as e:
            logger.warning(f"Could not fetch lab orders: {e}")

        try:
            cur.execute('''
                SELECT * FROM prescriptions
                WHERE patient_id = ? AND status = 'active'
                ORDER BY issued_at DESC
            ''', (user['username'],))
            prescriptions = _rows_to_dicts(cur)
            if prescriptions:
                result["prescriptions"] = prescriptions
        except Exception as e:
            logger.warning(f"Could not fetch prescriptions: {e}")

        conn.close()

        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Patient detail failed: {e}")
        raise HTTPException(500, f"Failed to get patient detail: {e}")


@app.get("/api/triage/queue")
async def get_triage_queue(status: str = "waiting"):
    """Get triage queue sorted by priority"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        cur.execute('''
            SELECT t.*, u.full_name, u.medilink_id, u.age, u.gender
            FROM triage_queue t
            JOIN users u ON u.medilink_id = t.patient_medilink_id
            WHERE t.status = ?
            ORDER BY t.priority_score DESC, t.check_in_time ASC
        ''', (status,))
        results = _rows_to_dicts(cur)
        conn.close()
        return {"queue": results, "count": len(results)}
    except Exception as e:
        logger.error(f"Triage queue failed: {e}")
        raise HTTPException(500, f"Failed to get triage queue: {e}")


@app.post("/api/triage/checkin")
async def triage_checkin(req: TriageCheckinRequest):
    """Add patient to triage queue"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO triage_queue (id, patient_medilink_id, provider_username,
                triage_level, priority_score, estimated_wait_time, danger_signs,
                chief_complaint, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'waiting')
        ''', (uid, req.medilink_id, req.provider_username,
              req.triage_level, req.priority_score, req.estimated_wait_time,
              json.dumps(req.danger_signs), req.chief_complaint))
        conn.commit()
        conn.close()
        return {"id": uid, "status": "waiting", "success": True}
    except Exception as e:
        logger.error(f"Triage checkin failed: {e}")
        raise HTTPException(500, f"Checkin failed: {e}")


@app.post("/api/lab/orders")
async def create_lab_order(req: LabOrderRequest):
    """Create a lab order"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO lab_orders (id, patient_medilink_id, provider_username,
                consultation_id, test_name, test_category, priority, status, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'ordered', ?)
        ''', (uid, req.patient_medilink_id, req.provider_username,
              req.consultation_id, req.test_name, req.test_category, req.priority, req.notes))
        conn.commit()
        conn.close()
        return {"id": uid, "status": "ordered", "success": True}
    except Exception as e:
        logger.error(f"Lab order failed: {e}")
        raise HTTPException(500, f"Lab order failed: {e}")


@app.get("/api/lab/orders/{patient_medilink_id}")
async def get_lab_orders(patient_medilink_id: str):
    """Get lab orders for a patient"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        cur.execute('''
            SELECT lo.*, lr.result_value, lr.result_unit, lr.result_flag,
                   lr.reference_range_low, lr.reference_range_high, lr.resulted_at
            FROM lab_orders lo
            LEFT JOIN lab_results lr ON lr.lab_order_id = lo.id
            WHERE lo.patient_medilink_id = ?
            ORDER BY lo.ordered_at DESC
        ''', (patient_medilink_id,))
        results = _rows_to_dicts(cur)
        conn.close()
        return {"orders": results, "count": len(results)}
    except Exception as e:
        logger.error(f"Get lab orders failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.post("/api/lab/results")
async def add_lab_result(req: LabResultRequest):
    """Add lab result to an order"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO lab_results (id, lab_order_id, result_value, result_unit,
                reference_range_low, reference_range_high, result_flag, performed_by, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (uid, req.lab_order_id, req.result_value, req.result_unit,
              req.reference_range_low, req.reference_range_high,
              req.result_flag, req.performed_by, req.notes))
        # Update order status to completed
        cur.execute("UPDATE lab_orders SET status = 'completed' WHERE id = ?", (req.lab_order_id,))
        conn.commit()
        conn.close()

        # Alert if critical
        alert = None
        if req.result_flag == "critical":
            alert = {"lab_order_id": req.lab_order_id, "result_flag": "critical", "message": "Critical lab result"}

        return {"id": uid, "result_flag": req.result_flag, "success": True, "alert": alert}
    except Exception as e:
        logger.error(f"Lab result failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.post("/api/radiology/orders")
async def create_radiology_order(req: RadiologyOrderRequest):
    """Create a radiology order"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO radiology_orders (id, patient_medilink_id, provider_username,
                consultation_id, study_type, body_part, clinical_indication, priority, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ordered')
        ''', (uid, req.patient_medilink_id, req.provider_username,
              req.consultation_id, req.study_type, req.body_part,
              req.clinical_indication, req.priority))
        conn.commit()
        conn.close()
        return {"id": uid, "status": "ordered", "success": True}
    except Exception as e:
        logger.error(f"Radiology order failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.get("/api/radiology/orders/{patient_medilink_id}")
async def get_radiology_orders(patient_medilink_id: str):
    """Get radiology orders for a patient"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        cur.execute('''
            SELECT ro.*, rr.findings, rr.impression, rr.recommendations, rr.radiologist_name, rr.reported_at
            FROM radiology_orders ro
            LEFT JOIN radiology_reports rr ON rr.radiology_order_id = ro.id
            WHERE ro.patient_medilink_id = ?
            ORDER BY ro.ordered_at DESC
        ''', (patient_medilink_id,))
        results = _rows_to_dicts(cur)
        conn.close()
        return {"orders": results, "count": len(results)}
    except Exception as e:
        logger.error(f"Get radiology orders failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.post("/api/radiology/reports")
async def add_radiology_report(req: RadiologyReportRequest):
    """Add radiology report"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO radiology_reports (id, radiology_order_id, radiologist_name,
                findings, impression, recommendations)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (uid, req.radiology_order_id, req.radiologist_name,
              req.findings, req.impression, req.recommendations))
        cur.execute("UPDATE radiology_orders SET status = 'reported' WHERE id = ?", (req.radiology_order_id,))
        conn.commit()
        conn.close()
        return {"id": uid, "success": True}
    except Exception as e:
        logger.error(f"Radiology report failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.post("/api/referrals")
async def create_referral(req: ReferralRequest):
    """Create a referral"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO referrals (id, patient_medilink_id, from_username,
                to_facility, to_provider_username, to_specialty, reason, urgency,
                referral_notes, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
        ''', (uid, req.patient_medilink_id, req.from_username,
              req.to_facility, req.to_provider_username, req.to_specialty,
              req.reason, req.urgency, req.referral_notes))
        conn.commit()
        conn.close()
        return {"id": uid, "status": "pending", "success": True}
    except Exception as e:
        logger.error(f"Referral failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.get("/api/referrals/{patient_medilink_id}")
async def get_referrals(patient_medilink_id: str):
    """Get referrals for a patient"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        cur.execute('''
            SELECT r.*, u.full_name as patient_name
            FROM referrals r
            JOIN users u ON u.medilink_id = r.patient_medilink_id
            WHERE r.patient_medilink_id = ?
            ORDER BY r.created_at DESC
        ''', (patient_medilink_id,))
        results = _rows_to_dicts(cur)
        conn.close()
        return {"referrals": results, "count": len(results)}
    except Exception as e:
        logger.error(f"Get referrals failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.put("/api/referrals/{referral_id}/status")
async def update_referral_status(referral_id: str, status: str = ""):
    """Update referral status"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        now = datetime.now().isoformat()
        if status in ("completed", "closed"):
            cur.execute("UPDATE referrals SET status = ?, updated_at = ?, completed_at = ? WHERE id = ?",
                       (status, now, now, referral_id))
        else:
            cur.execute("UPDATE referrals SET status = ?, updated_at = ? WHERE id = ?",
                       (status, now, referral_id))
        conn.commit()
        conn.close()
        return {"success": True, "status": status}
    except Exception as e:
        logger.error(f"Update referral status failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.post("/api/messages")
async def send_message(req: MessageRequest):
    """Send a message"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO messages (id, sender_username, receiver_username,
                patient_medilink_id, content, message_type, reference_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (uid, req.sender_username, req.receiver_username,
              req.patient_medilink_id, req.content, req.message_type,
              req.reference_id or None))
        conn.commit()
        conn.close()
        return {"id": uid, "success": True}
    except Exception as e:
        logger.error(f"Send message failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.get("/api/messages/{username}")
async def get_messages(username: str, limit: int = 50):
    """Get messages for a user (sent + received)"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        cur.execute('''
            SELECT * FROM messages
            WHERE sender_username = ? OR receiver_username = ?
            ORDER BY created_at DESC LIMIT ?
        ''', (username, username, limit))
        results = _rows_to_dicts(cur)
        conn.close()
        return {"messages": results, "count": len(results)}
    except Exception as e:
        logger.error(f"Get messages failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.post("/api/adherence")
async def log_adherence(req: AdherenceRequest):
    """Log medication adherence"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        uid = _generate_uuid()
        cur.execute('''
            INSERT INTO adherence_log (id, prescription_id, patient_medilink_id,
                scheduled_time, taken_time, skipped_reason, status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (uid, req.prescription_id, req.patient_medilink_id,
              req.scheduled_time, req.taken_time or None,
              req.skipped_reason or None, req.status))
        conn.commit()
        conn.close()
        return {"id": uid, "status": req.status, "success": True}
    except Exception as e:
        logger.error(f"Adherence log failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


@app.get("/api/adherence/{patient_medilink_id}")
async def get_adherence(patient_medilink_id: str):
    """Get adherence log with stats"""
    try:
        conn, cur = _get_db_cursor()
        if not cur:
            raise HTTPException(503, "Database not initialized")
        cur.execute('''
            SELECT a.*, p.medication_name, p.dosage, p.frequency
            FROM adherence_log a
            JOIN prescriptions p ON p.id = a.prescription_id
            WHERE a.patient_medilink_id = ?
            ORDER BY a.scheduled_time DESC LIMIT 50
        ''', (patient_medilink_id,))
        log = _rows_to_dicts(cur)

        # Calculate stats
        cur.execute('''
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken,
                SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) as skipped
            FROM adherence_log WHERE patient_medilink_id = ?
        ''', (patient_medilink_id,))
        stats_row = cur.fetchone()
        stats = dict(zip([d[0] for d in cur.description], stats_row)) if stats_row else {}
        conn.close()

        adherence_rate = 0
        if stats.get('total', 0) > 0:
            adherence_rate = round(stats['taken'] / stats['total'] * 100, 1)

        return {"log": log, "stats": stats, "adherence_rate": adherence_rate}
    except Exception as e:
        logger.error(f"Get adherence failed: {e}")
        raise HTTPException(500, f"Failed: {e}")


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