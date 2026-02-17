"""
Supabase client for AfiCare MediLink
Provides database persistence with graceful fallback to session-state-only mode.
Uses service role key to bypass RLS (safe server-side, never exposed to browser).
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List

logger = logging.getLogger(__name__)

_client = None
_available = None


def get_client():
    """Get singleton Supabase client. Returns None if unavailable."""
    global _client, _available

    if _available is False:
        return None
    if _client is not None:
        return _client

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")

    if not url or not key:
        logger.warning("SUPABASE_URL or SUPABASE_KEY not set - running in session-state-only mode")
        _available = False
        return None

    try:
        from supabase import create_client
        _client = create_client(url, key)
        _available = True
        logger.info("Supabase client initialized successfully")
        return _client
    except Exception as e:
        logger.error(f"Failed to initialize Supabase client: {e}")
        _available = False
        return None


def is_available() -> bool:
    """Check if Supabase is available."""
    get_client()
    return _available is True


# ============================================
# USER OPERATIONS
# ============================================

def get_user_by_medilink_id(medilink_id: str) -> Optional[Dict]:
    """Look up a user by MediLink ID."""
    client = get_client()
    if not client:
        return None
    try:
        result = client.table("users").select("*").eq("medilink_id", medilink_id).execute()
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"get_user_by_medilink_id error: {e}")
    return None


def get_user_by_phone(phone: str) -> Optional[Dict]:
    """Look up a user by phone number."""
    client = get_client()
    if not client:
        return None
    try:
        result = client.table("users").select("*").eq("phone", phone).execute()
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"get_user_by_phone error: {e}")
    return None


def get_user_by_email(email: str) -> Optional[Dict]:
    """Look up a user by email."""
    client = get_client()
    if not client:
        return None
    try:
        result = client.table("users").select("*").eq("email", email).execute()
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"get_user_by_email error: {e}")
    return None


def get_user_by_username(username: str) -> Optional[Dict]:
    """Look up a user by username stored in metadata."""
    client = get_client()
    if not client:
        return None
    try:
        # Try medilink_id first
        result = get_user_by_medilink_id(username)
        if result:
            return result
        # Try phone
        result = get_user_by_phone(username)
        if result:
            return result
        # Try email
        result = get_user_by_email(username)
        if result:
            return result
        # Try username in metadata
        result = client.table("users").select("*").contains("metadata", {"username": username}).execute()
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"get_user_by_username error: {e}")
    return None


def create_user(data: Dict[str, Any]) -> Optional[Dict]:
    """Create a new user in Supabase. Returns created user or None."""
    client = get_client()
    if not client:
        return None
    try:
        user_record = {
            "email": data.get("email") or f"{data.get('phone', 'unknown')}@aficare.local",
            "full_name": data["full_name"],
            "role": data["role"],
            "phone": data.get("phone"),
            "medilink_id": data.get("medilink_id"),
            "hospital_id": data.get("hospital_id"),
            "department": data.get("department"),
            "metadata": {
                "password_hash": data.get("password", ""),
                "username": data.get("username"),
                "age": data.get("age"),
                "gender": data.get("gender"),
                "location": data.get("location"),
                "license_number": data.get("license_number"),
                "specialization": data.get("specialization"),
                "years_experience": data.get("years_experience"),
                "provider_id": data.get("provider_id"),
                "registration_date": data.get("registration_date"),
            }
        }
        # Remove None values from metadata
        user_record["metadata"] = {k: v for k, v in user_record["metadata"].items() if v is not None}

        result = client.table("users").insert(user_record).execute()
        if result.data:
            logger.info(f"Created user: {data['full_name']} ({data['role']})")
            return result.data[0]
    except Exception as e:
        logger.error(f"create_user error: {e}")
    return None


def create_patient(user_id: str, data: Dict[str, Any]) -> Optional[Dict]:
    """Create patient extended info. user_id is the UUID from users table."""
    client = get_client()
    if not client:
        return None
    try:
        patient_record = {
            "id": user_id,
            "gender": data.get("gender", "").lower() if data.get("gender") else None,
            "allergies": [a.strip() for a in data.get("allergies", "").split(",") if a.strip()] if data.get("allergies") else None,
            "chronic_conditions": [c.strip() for c in data.get("medical_history", "").split(",") if c.strip()] if data.get("medical_history") else None,
            "emergency_contact_name": data.get("emergency_name"),
            "emergency_contact_phone": data.get("emergency_phone"),
        }
        # Remove None values
        patient_record = {k: v for k, v in patient_record.items() if v is not None}

        result = client.table("patients").insert(patient_record).execute()
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"create_patient error: {e}")
    return None


# ============================================
# CONSULTATION OPERATIONS
# ============================================

def create_consultation(data: Dict[str, Any]) -> Optional[Dict]:
    """Create a new consultation record."""
    client = get_client()
    if not client:
        return None
    try:
        result = client.table("consultations").insert(data).execute()
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"create_consultation error: {e}")
    return None


def get_consultations_for_patient(patient_id: str) -> List[Dict]:
    """Get all consultations for a patient."""
    client = get_client()
    if not client:
        return []
    try:
        result = (client.table("consultations")
                  .select("*")
                  .eq("patient_id", patient_id)
                  .order("timestamp", desc=True)
                  .execute())
        return result.data or []
    except Exception as e:
        logger.error(f"get_consultations_for_patient error: {e}")
    return []


# ============================================
# ACCESS CODE OPERATIONS
# ============================================

def create_access_code(data: Dict[str, Any]) -> Optional[Dict]:
    """Create a new access code."""
    client = get_client()
    if not client:
        return None
    try:
        result = client.table("access_codes").insert(data).execute()
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"create_access_code error: {e}")
    return None


def get_access_code(code: str) -> Optional[Dict]:
    """Look up an access code."""
    client = get_client()
    if not client:
        return None
    try:
        result = (client.table("access_codes")
                  .select("*")
                  .eq("code", code)
                  .eq("is_used", False)
                  .gt("expires_at", datetime.utcnow().isoformat())
                  .execute())
        if result.data:
            return result.data[0]
    except Exception as e:
        logger.error(f"get_access_code error: {e}")
    return None


def mark_access_code_used(code_id: str, used_by: str) -> bool:
    """Mark an access code as used."""
    client = get_client()
    if not client:
        return False
    try:
        client.table("access_codes").update({
            "is_used": True,
            "used_by": used_by,
            "used_at": datetime.utcnow().isoformat()
        }).eq("id", code_id).execute()
        return True
    except Exception as e:
        logger.error(f"mark_access_code_used error: {e}")
    return False


# ============================================
# AUDIT LOG
# ============================================

def log_audit(action: str, user_id: Optional[str] = None,
              patient_id: Optional[str] = None, details: Optional[Dict] = None) -> None:
    """Log an audit event. Fire-and-forget, never raises."""
    client = get_client()
    if not client:
        return
    try:
        record = {
            "action": action,
            "details": details or {},
        }
        if user_id:
            record["user_id"] = user_id
        if patient_id:
            record["patient_id"] = patient_id
        client.table("audit_log").insert(record).execute()
    except Exception as e:
        logger.error(f"log_audit error: {e}")
