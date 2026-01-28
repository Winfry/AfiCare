"""
Enhanced Database Manager for AfiCare MediLink
Extends the existing DatabaseManager with advanced data persistence features
"""

import sqlite3
import json
import hashlib
import secrets
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
import logging
from dataclasses import dataclass

# Import the base database manager
from .database_manager import DatabaseManager

logger = logging.getLogger(__name__)


@dataclass
class AccessCodeInfo:
    """Access code information structure"""
    id: int
    patient_medilink_id: str
    access_code: str
    expires_at: datetime
    duration_hours: int
    permissions: Dict[str, bool]
    used_by: Optional[str] = None
    used_at: Optional[datetime] = None
    revoked_at: Optional[datetime] = None
    revoked_by: Optional[str] = None
    created_at: Optional[datetime] = None


@dataclass
class AuditLogEntry:
    """Audit log entry structure"""
    id: int
    patient_medilink_id: str
    accessed_by: str
    access_type: str
    access_method: str
    ip_address: Optional[str]
    user_agent: Optional[str]
    success: bool
    failure_reason: Optional[str]
    data_accessed: Optional[List[str]]
    accessed_at: datetime


class EnhancedDatabaseManager(DatabaseManager):
    """Enhanced database manager with advanced persistence features"""
    
    def __init__(self, db_path: str = "aficare_enhanced.db"):
        # Initialize base database manager
        super().__init__(db_path)
        # Initialize enhanced tables
        self.init_enhanced_tables()
    
    def init_enhanced_tables(self):
        """Initialize enhanced database tables"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Enhanced access codes table with permissions
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS access_codes_enhanced (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        access_code TEXT UNIQUE NOT NULL,
                        expires_at TIMESTAMP NOT NULL,
                        duration_hours INTEGER DEFAULT 24,
                        permissions TEXT DEFAULT '{}',  -- JSON permissions
                        used_by TEXT,
                        used_at TIMESTAMP,
                        revoked_at TIMESTAMP,
                        revoked_by TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (patient_medilink_id) REFERENCES users (medilink_id)
                    )
                ''')
                
                # Enhanced audit log table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS audit_log_enhanced (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        accessed_by TEXT NOT NULL,
                        access_type TEXT NOT NULL,  -- 'login', 'view_records', 'create_consultation', 'export_data'
                        access_method TEXT DEFAULT 'direct',  -- 'direct', 'access_code', 'qr_code'
                        ip_address TEXT,
                        user_agent TEXT,
                        success BOOLEAN DEFAULT TRUE,
                        failure_reason TEXT,
                        data_accessed TEXT,  -- JSON array of data types accessed
                        session_id TEXT,
                        accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Enhanced patient profiles table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS patient_profiles_enhanced (
                        medilink_id TEXT PRIMARY KEY,
                        allergies TEXT,  -- JSON array
                        chronic_conditions TEXT,  -- JSON array
                        current_medications TEXT,  -- JSON array of medication objects
                        emergency_contacts TEXT,  -- JSON array of contact objects
                        insurance_info TEXT,  -- JSON object
                        blood_type TEXT,
                        organ_donor BOOLEAN DEFAULT FALSE,
                        preferred_language TEXT DEFAULT 'English',
                        medical_alerts TEXT,  -- JSON array of alert strings
                        communication_preferences TEXT DEFAULT '{}',  -- JSON object
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_by TEXT,
                        FOREIGN KEY (medilink_id) REFERENCES users (medilink_id)
                    )
                ''')
                
                # Healthcare provider credentials table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS provider_credentials (
                        username TEXT PRIMARY KEY,
                        license_number TEXT,
                        specializations TEXT,  -- JSON array
                        certifications TEXT,  -- JSON array of certification objects
                        medical_school TEXT,
                        residency_info TEXT,
                        years_experience INTEGER,
                        hospital_affiliations TEXT,  -- JSON array
                        verification_status TEXT DEFAULT 'pending',
                        verification_date TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (username) REFERENCES users (username)
                    )
                ''')
                
                # Data export log table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS export_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        exported_by TEXT NOT NULL,
                        export_format TEXT NOT NULL,  -- 'pdf', 'json', 'csv'
                        date_range_start TIMESTAMP,
                        date_range_end TIMESTAMP,
                        data_types TEXT,  -- JSON array
                        file_size INTEGER,
                        checksum TEXT,
                        export_purpose TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        downloaded_at TIMESTAMP
                    )
                ''')
                
                # Backup log table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS backup_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        backup_type TEXT NOT NULL,  -- 'full', 'incremental'
                        backup_file TEXT NOT NULL,
                        file_size INTEGER,
                        checksum TEXT,
                        compression_ratio REAL,
                        encryption_enabled BOOLEAN DEFAULT TRUE,
                        backup_duration REAL,  -- seconds
                        records_count INTEGER,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        verified_at TIMESTAMP,
                        verification_status TEXT DEFAULT 'pending'
                    )
                ''')
                
                # Create indexes for performance
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_access_codes_patient ON access_codes_enhanced(patient_medilink_id)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_access_codes_expires ON access_codes_enhanced(expires_at)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_audit_log_patient ON audit_log_enhanced(patient_medilink_id)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_audit_log_accessed_by ON audit_log_enhanced(accessed_by)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_audit_log_date ON audit_log_enhanced(accessed_at)')
                
                conn.commit()
                logger.info("Enhanced database tables initialized successfully")
                
        except Exception as e:
            logger.error(f"Failed to initialize enhanced database tables: {str(e)}")
            raise
    
    # ACCESS CODE MANAGEMENT METHODS
    
    def generate_access_code(self, medilink_id: str, duration_hours: int = 24, 
                           permissions: Dict[str, bool] = None) -> Tuple[bool, str]:
        """Generate temporary access code for patient record sharing"""
        
        try:
            # Generate cryptographically secure 6-digit code
            access_code = f"{secrets.randbelow(900000) + 100000}"
            expires_at = datetime.now() + timedelta(hours=duration_hours)
            
            # Default permissions
            if permissions is None:
                permissions = {
                    "view_basic_info": True,
                    "view_medical_history": True,
                    "view_consultations": True,
                    "view_medications": True,
                    "view_vitals": True,
                    "create_consultation": False,
                    "export_data": False
                }
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Insert new access code
                cursor.execute('''
                    INSERT INTO access_codes_enhanced 
                    (patient_medilink_id, access_code, expires_at, duration_hours, permissions)
                    VALUES (?, ?, ?, ?, ?)
                ''', (medilink_id, access_code, expires_at, duration_hours, json.dumps(permissions)))
                
                conn.commit()
                
                # Log the access code generation
                self.log_access_enhanced(
                    patient_medilink_id=medilink_id,
                    accessed_by="system",
                    access_type="generate_access_code",
                    access_method="direct",
                    success=True
                )
                
                logger.info(f"Access code generated for {medilink_id}, expires at {expires_at}")
                return True, access_code
                
        except Exception as e:
            logger.error(f"Failed to generate access code: {str(e)}")
            return False, "Failed to generate access code"
    
    def verify_access_code(self, access_code: str, used_by: str, 
                          mark_as_used: bool = True) -> Tuple[bool, Optional[str], Optional[Dict[str, bool]]]:
        """Verify access code and return MediLink ID and permissions if valid"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if code exists, is not expired, not used, and not revoked
                cursor.execute('''
                    SELECT patient_medilink_id, permissions FROM access_codes_enhanced 
                    WHERE access_code = ? AND expires_at > ? AND used_at IS NULL AND revoked_at IS NULL
                ''', (access_code, datetime.now()))
                
                result = cursor.fetchone()
                
                if result:
                    medilink_id, permissions_json = result
                    permissions = json.loads(permissions_json) if permissions_json else {}
                    
                    if mark_as_used:
                        # Mark code as used
                        cursor.execute('''
                            UPDATE access_codes_enhanced 
                            SET used_by = ?, used_at = ? 
                            WHERE access_code = ?
                        ''', (used_by, datetime.now(), access_code))
                        
                        conn.commit()
                    
                    # Log successful access
                    self.log_access_enhanced(
                        patient_medilink_id=medilink_id,
                        accessed_by=used_by,
                        access_type="verify_access_code",
                        access_method="access_code",
                        success=True
                    )
                    
                    logger.info(f"Access code verified for {medilink_id} by {used_by}")
                    return True, medilink_id, permissions
                else:
                    # Log failed access attempt
                    self.log_access_enhanced(
                        patient_medilink_id="unknown",
                        accessed_by=used_by,
                        access_type="verify_access_code",
                        access_method="access_code",
                        success=False,
                        failure_reason="Invalid or expired access code"
                    )
                    return False, None, None
                    
        except Exception as e:
            logger.error(f"Error verifying access code: {str(e)}")
            return False, None, None
    
    def revoke_access_code(self, access_code: str, patient_medilink_id: str, 
                          revoked_by: str = None) -> bool:
        """Revoke an active access code"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Revoke the access code
                cursor.execute('''
                    UPDATE access_codes_enhanced 
                    SET revoked_at = ?, revoked_by = ? 
                    WHERE access_code = ? AND patient_medilink_id = ? AND revoked_at IS NULL
                ''', (datetime.now(), revoked_by or patient_medilink_id, access_code, patient_medilink_id))
                
                if cursor.rowcount > 0:
                    conn.commit()
                    
                    # Log the revocation
                    self.log_access_enhanced(
                        patient_medilink_id=patient_medilink_id,
                        accessed_by=revoked_by or patient_medilink_id,
                        access_type="revoke_access_code",
                        access_method="direct",
                        success=True
                    )
                    
                    logger.info(f"Access code {access_code} revoked for {patient_medilink_id}")
                    return True
                else:
                    return False
                    
        except Exception as e:
            logger.error(f"Failed to revoke access code: {str(e)}")
            return False
    
    def get_active_access_codes(self, medilink_id: str) -> List[Dict[str, Any]]:
        """Get all active access codes for a patient"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM access_codes_enhanced 
                    WHERE patient_medilink_id = ? AND expires_at > ? AND revoked_at IS NULL
                    ORDER BY created_at DESC
                ''', (medilink_id, datetime.now()))
                
                codes = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                active_codes = []
                for code in codes:
                    code_dict = dict(zip(columns, code))
                    # Parse JSON permissions
                    if code_dict.get('permissions'):
                        code_dict['permissions'] = json.loads(code_dict['permissions'])
                    active_codes.append(code_dict)
                
                return active_codes
                
        except Exception as e:
            logger.error(f"Error getting active access codes: {str(e)}")
            return []
    
    def cleanup_expired_access_codes(self) -> int:
        """Clean up expired access codes and return count of cleaned codes"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Delete expired codes
                cursor.execute('''
                    DELETE FROM access_codes_enhanced 
                    WHERE expires_at <= ?
                ''', (datetime.now(),))
                
                deleted_count = cursor.rowcount
                conn.commit()
                
                if deleted_count > 0:
                    logger.info(f"Cleaned up {deleted_count} expired access codes")
                
                return deleted_count
                
        except Exception as e:
            logger.error(f"Error cleaning up expired access codes: {str(e)}")
            return 0
    
    # ENHANCED AUDIT LOGGING METHODS
    
    def log_access_enhanced(self, patient_medilink_id: str, accessed_by: str, access_type: str,
                           access_method: str = "direct", ip_address: str = None, 
                           user_agent: str = None, success: bool = True, 
                           failure_reason: str = None, data_accessed: List[str] = None,
                           session_id: str = None) -> bool:
        """Enhanced audit logging with comprehensive tracking"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO audit_log_enhanced (
                        patient_medilink_id, accessed_by, access_type, access_method,
                        ip_address, user_agent, success, failure_reason, data_accessed, session_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    patient_medilink_id, accessed_by, access_type, access_method,
                    ip_address, user_agent, success, failure_reason,
                    json.dumps(data_accessed) if data_accessed else None, session_id
                ))
                
                conn.commit()
                return True
                
        except Exception as e:
            logger.error(f"Failed to log access: {str(e)}")
            return False
    
    def get_access_log_enhanced(self, medilink_id: str, days: int = 30, 
                               limit: int = 100) -> List[Dict[str, Any]]:
        """Get enhanced access log for patient"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM audit_log_enhanced 
                    WHERE patient_medilink_id = ? AND accessed_at >= datetime('now', '-{} days')
                    ORDER BY accessed_at DESC LIMIT ?
                '''.format(days), (medilink_id, limit))
                
                log_rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                access_log = []
                for row in log_rows:
                    log_entry = dict(zip(columns, row))
                    # Parse JSON data_accessed
                    if log_entry.get('data_accessed'):
                        log_entry['data_accessed'] = json.loads(log_entry['data_accessed'])
                    access_log.append(log_entry)
                
                return access_log
                
        except Exception as e:
            logger.error(f"Error getting access log: {str(e)}")
            return []
    
    def get_provider_activity(self, username: str, days: int = 7) -> List[Dict[str, Any]]:
        """Get healthcare provider activity summary"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM audit_log_enhanced 
                    WHERE accessed_by = ? AND accessed_at >= datetime('now', '-{} days')
                    ORDER BY accessed_at DESC
                '''.format(days), (username,))
                
                activity_rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                activities = []
                for row in activity_rows:
                    activity = dict(zip(columns, row))
                    if activity.get('data_accessed'):
                        activity['data_accessed'] = json.loads(activity['data_accessed'])
                    activities.append(activity)
                
                return activities
                
        except Exception as e:
            logger.error(f"Error getting provider activity: {str(e)}")
            return []
    
    def get_system_audit_summary(self, days: int = 7) -> Dict[str, Any]:
        """Get system-wide audit summary for administrators"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Total access events
                cursor.execute('''
                    SELECT COUNT(*) FROM audit_log_enhanced 
                    WHERE accessed_at >= datetime('now', '-{} days')
                '''.format(days))
                total_events = cursor.fetchone()[0]
                
                # Failed access attempts
                cursor.execute('''
                    SELECT COUNT(*) FROM audit_log_enhanced 
                    WHERE accessed_at >= datetime('now', '-{} days') AND success = FALSE
                '''.format(days))
                failed_attempts = cursor.fetchone()[0]
                
                # Access by method
                cursor.execute('''
                    SELECT access_method, COUNT(*) FROM audit_log_enhanced 
                    WHERE accessed_at >= datetime('now', '-{} days')
                    GROUP BY access_method
                '''.format(days))
                access_by_method = dict(cursor.fetchall())
                
                # Most active providers
                cursor.execute('''
                    SELECT accessed_by, COUNT(*) as activity_count FROM audit_log_enhanced 
                    WHERE accessed_at >= datetime('now', '-{} days') AND accessed_by != 'system'
                    GROUP BY accessed_by ORDER BY activity_count DESC LIMIT 10
                '''.format(days))
                top_providers = cursor.fetchall()
                
                return {
                    'total_events': total_events,
                    'failed_attempts': failed_attempts,
                    'success_rate': ((total_events - failed_attempts) / total_events * 100) if total_events > 0 else 100,
                    'access_by_method': access_by_method,
                    'top_providers': [{'username': p[0], 'activity_count': p[1]} for p in top_providers]
                }
                
        except Exception as e:
            logger.error(f"Error getting system audit summary: {str(e)}")
            return {}


# Global enhanced database instance
enhanced_db_manager = None

def get_enhanced_database() -> EnhancedDatabaseManager:
    """Get global enhanced database manager instance"""
    global enhanced_db_manager
    if enhanced_db_manager is None:
        enhanced_db_manager = EnhancedDatabaseManager()
    return enhanced_db_manager
    
    # PATIENT PROFILE MANAGEMENT METHODS
    
    def update_patient_profile(self, medilink_id: str, profile_data: Dict[str, Any], 
                              updated_by: str = None) -> bool:
        """Update comprehensive patient profile information"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Prepare profile data with JSON serialization
                profile_fields = {
                    'allergies': json.dumps(profile_data.get('allergies', [])),
                    'chronic_conditions': json.dumps(profile_data.get('chronic_conditions', [])),
                    'current_medications': json.dumps(profile_data.get('current_medications', [])),
                    'emergency_contacts': json.dumps(profile_data.get('emergency_contacts', [])),
                    'insurance_info': json.dumps(profile_data.get('insurance_info', {})),
                    'blood_type': profile_data.get('blood_type'),
                    'organ_donor': profile_data.get('organ_donor', False),
                    'preferred_language': profile_data.get('preferred_language', 'English'),
                    'medical_alerts': json.dumps(profile_data.get('medical_alerts', [])),
                    'communication_preferences': json.dumps(profile_data.get('communication_preferences', {})),
                    'updated_by': updated_by or medilink_id
                }
                
                # Check if profile exists
                cursor.execute('SELECT medilink_id FROM patient_profiles_enhanced WHERE medilink_id = ?', (medilink_id,))
                exists = cursor.fetchone()
                
                if exists:
                    # Update existing profile
                    cursor.execute('''
                        UPDATE patient_profiles_enhanced SET
                        allergies = ?, chronic_conditions = ?, current_medications = ?,
                        emergency_contacts = ?, insurance_info = ?, blood_type = ?,
                        organ_donor = ?, preferred_language = ?, medical_alerts = ?,
                        communication_preferences = ?, updated_at = CURRENT_TIMESTAMP, updated_by = ?
                        WHERE medilink_id = ?
                    ''', (
                        profile_fields['allergies'], profile_fields['chronic_conditions'],
                        profile_fields['current_medications'], profile_fields['emergency_contacts'],
                        profile_fields['insurance_info'], profile_fields['blood_type'],
                        profile_fields['organ_donor'], profile_fields['preferred_language'],
                        profile_fields['medical_alerts'], profile_fields['communication_preferences'],
                        profile_fields['updated_by'], medilink_id
                    ))
                else:
                    # Insert new profile
                    cursor.execute('''
                        INSERT INTO patient_profiles_enhanced (
                            medilink_id, allergies, chronic_conditions, current_medications,
                            emergency_contacts, insurance_info, blood_type, organ_donor,
                            preferred_language, medical_alerts, communication_preferences, updated_by
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        medilink_id, profile_fields['allergies'], profile_fields['chronic_conditions'],
                        profile_fields['current_medications'], profile_fields['emergency_contacts'],
                        profile_fields['insurance_info'], profile_fields['blood_type'],
                        profile_fields['organ_donor'], profile_fields['preferred_language'],
                        profile_fields['medical_alerts'], profile_fields['communication_preferences'],
                        profile_fields['updated_by']
                    ))
                
                conn.commit()
                
                # Log profile update
                self.log_access_enhanced(
                    patient_medilink_id=medilink_id,
                    accessed_by=updated_by or medilink_id,
                    access_type="update_patient_profile",
                    access_method="direct",
                    success=True,
                    data_accessed=list(profile_data.keys())
                )
                
                logger.info(f"Patient profile updated for {medilink_id}")
                return True
                
        except Exception as e:
            logger.error(f"Failed to update patient profile: {str(e)}")
            return False
    
    def get_patient_profile(self, medilink_id: str) -> Optional[Dict[str, Any]]:
        """Get comprehensive patient profile information"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('SELECT * FROM patient_profiles_enhanced WHERE medilink_id = ?', (medilink_id,))
                profile_row = cursor.fetchone()
                
                if profile_row:
                    columns = [desc[0] for desc in cursor.description]
                    profile = dict(zip(columns, profile_row))
                    
                    # Parse JSON fields
                    json_fields = ['allergies', 'chronic_conditions', 'current_medications', 
                                 'emergency_contacts', 'insurance_info', 'medical_alerts', 
                                 'communication_preferences']
                    
                    for field in json_fields:
                        if profile.get(field):
                            try:
                                profile[field] = json.loads(profile[field])
                            except json.JSONDecodeError:
                                profile[field] = [] if field != 'insurance_info' and field != 'communication_preferences' else {}
                    
                    return profile
                
                return None
                
        except Exception as e:
            logger.error(f"Error getting patient profile: {str(e)}")
            return None
    
    def get_patient_emergency_info(self, medilink_id: str) -> Optional[Dict[str, Any]]:
        """Get patient emergency information quickly"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Get basic patient info
                cursor.execute('''
                    SELECT full_name, age, gender, phone FROM users 
                    WHERE medilink_id = ?
                ''', (medilink_id,))
                user_info = cursor.fetchone()
                
                if not user_info:
                    return None
                
                # Get emergency profile info
                cursor.execute('''
                    SELECT allergies, chronic_conditions, blood_type, medical_alerts, emergency_contacts 
                    FROM patient_profiles_enhanced WHERE medilink_id = ?
                ''', (medilink_id,))
                profile_info = cursor.fetchone()
                
                emergency_info = {
                    'full_name': user_info[0],
                    'age': user_info[1],
                    'gender': user_info[2],
                    'phone': user_info[3],
                    'medilink_id': medilink_id
                }
                
                if profile_info:
                    emergency_info.update({
                        'allergies': json.loads(profile_info[0]) if profile_info[0] else [],
                        'chronic_conditions': json.loads(profile_info[1]) if profile_info[1] else [],
                        'blood_type': profile_info[2],
                        'medical_alerts': json.loads(profile_info[3]) if profile_info[3] else [],
                        'emergency_contacts': json.loads(profile_info[4]) if profile_info[4] else []
                    })
                
                return emergency_info
                
        except Exception as e:
            logger.error(f"Error getting patient emergency info: {str(e)}")
            return None
    
    # HEALTHCARE PROVIDER CREDENTIAL METHODS
    
    def update_provider_credentials(self, username: str, credentials: Dict[str, Any]) -> bool:
        """Update healthcare provider professional credentials"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Prepare credentials data
                cred_fields = {
                    'license_number': credentials.get('license_number'),
                    'specializations': json.dumps(credentials.get('specializations', [])),
                    'certifications': json.dumps(credentials.get('certifications', [])),
                    'medical_school': credentials.get('medical_school'),
                    'residency_info': credentials.get('residency_info'),
                    'years_experience': credentials.get('years_experience', 0),
                    'hospital_affiliations': json.dumps(credentials.get('hospital_affiliations', [])),
                    'verification_status': credentials.get('verification_status', 'pending')
                }
                
                # Check if credentials exist
                cursor.execute('SELECT username FROM provider_credentials WHERE username = ?', (username,))
                exists = cursor.fetchone()
                
                if exists:
                    # Update existing credentials
                    cursor.execute('''
                        UPDATE provider_credentials SET
                        license_number = ?, specializations = ?, certifications = ?,
                        medical_school = ?, residency_info = ?, years_experience = ?,
                        hospital_affiliations = ?, verification_status = ?, updated_at = CURRENT_TIMESTAMP
                        WHERE username = ?
                    ''', (
                        cred_fields['license_number'], cred_fields['specializations'],
                        cred_fields['certifications'], cred_fields['medical_school'],
                        cred_fields['residency_info'], cred_fields['years_experience'],
                        cred_fields['hospital_affiliations'], cred_fields['verification_status'],
                        username
                    ))
                else:
                    # Insert new credentials
                    cursor.execute('''
                        INSERT INTO provider_credentials (
                            username, license_number, specializations, certifications,
                            medical_school, residency_info, years_experience,
                            hospital_affiliations, verification_status
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        username, cred_fields['license_number'], cred_fields['specializations'],
                        cred_fields['certifications'], cred_fields['medical_school'],
                        cred_fields['residency_info'], cred_fields['years_experience'],
                        cred_fields['hospital_affiliations'], cred_fields['verification_status']
                    ))
                
                conn.commit()
                
                # Log credential update
                self.log_access_enhanced(
                    patient_medilink_id="system",
                    accessed_by=username,
                    access_type="update_provider_credentials",
                    access_method="direct",
                    success=True
                )
                
                logger.info(f"Provider credentials updated for {username}")
                return True
                
        except Exception as e:
            logger.error(f"Failed to update provider credentials: {str(e)}")
            return False
    
    def get_provider_credentials(self, username: str) -> Optional[Dict[str, Any]]:
        """Get healthcare provider professional credentials"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('SELECT * FROM provider_credentials WHERE username = ?', (username,))
                cred_row = cursor.fetchone()
                
                if cred_row:
                    columns = [desc[0] for desc in cursor.description]
                    credentials = dict(zip(columns, cred_row))
                    
                    # Parse JSON fields
                    json_fields = ['specializations', 'certifications', 'hospital_affiliations']
                    for field in json_fields:
                        if credentials.get(field):
                            try:
                                credentials[field] = json.loads(credentials[field])
                            except json.JSONDecodeError:
                                credentials[field] = []
                    
                    return credentials
                
                return None
                
        except Exception as e:
            logger.error(f"Error getting provider credentials: {str(e)}")
            return None
    
    def verify_provider_license(self, license_number: str) -> bool:
        """Verify healthcare provider license (placeholder for external verification)"""
        
        try:
            # This is a placeholder for actual license verification
            # In a real system, this would connect to medical board APIs
            
            if not license_number or len(license_number) < 5:
                return False
            
            # For demo purposes, consider licenses starting with 'MD' as verified
            is_verified = license_number.upper().startswith('MD')
            
            logger.info(f"License verification for {license_number}: {'verified' if is_verified else 'pending'}")
            return is_verified
            
        except Exception as e:
            logger.error(f"Error verifying provider license: {str(e)}")
            return False
    
    # DATA EXPORT LOGGING METHODS
    
    def log_export_activity(self, medilink_id: str, exported_by: str, export_format: str,
                           data_types: List[str], file_size: int = 0, checksum: str = None,
                           export_purpose: str = "patient_request", success: bool = True) -> bool:
        """Log data export activity"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO export_log (
                        patient_medilink_id, exported_by, export_format, data_types,
                        file_size, checksum, export_purpose
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    medilink_id, exported_by, export_format, json.dumps(data_types),
                    file_size, checksum, export_purpose
                ))
                
                conn.commit()
                
                # Also log in audit trail
                self.log_access_enhanced(
                    patient_medilink_id=medilink_id,
                    accessed_by=exported_by,
                    access_type="export_data",
                    access_method="direct",
                    success=success,
                    data_accessed=data_types
                )
                
                return True
                
        except Exception as e:
            logger.error(f"Failed to log export activity: {str(e)}")
            return False
    
    def get_export_history(self, medilink_id: str, days: int = 30) -> List[Dict[str, Any]]:
        """Get patient data export history"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM export_log 
                    WHERE patient_medilink_id = ? AND created_at >= datetime('now', '-{} days')
                    ORDER BY created_at DESC
                '''.format(days), (medilink_id,))
                
                export_rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                exports = []
                for row in export_rows:
                    export = dict(zip(columns, row))
                    if export.get('data_types'):
                        export['data_types'] = json.loads(export['data_types'])
                    exports.append(export)
                
                return exports
                
        except Exception as e:
            logger.error(f"Error getting export history: {str(e)}")
            return []
    
    # ENHANCED SYSTEM STATISTICS
    
    def get_enhanced_system_stats(self) -> Dict[str, Any]:
        """Get comprehensive system statistics"""
        
        try:
            # Get base stats
            base_stats = self.get_system_stats()
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Active access codes
                cursor.execute('''
                    SELECT COUNT(*) FROM access_codes_enhanced 
                    WHERE expires_at > datetime('now') AND revoked_at IS NULL
                ''')
                active_access_codes = cursor.fetchone()[0]
                
                # Total audit log entries
                cursor.execute('SELECT COUNT(*) FROM audit_log_enhanced')
                total_audit_entries = cursor.fetchone()[0]
                
                # Recent exports
                cursor.execute('''
                    SELECT COUNT(*) FROM export_log 
                    WHERE created_at >= datetime('now', '-7 days')
                ''')
                recent_exports = cursor.fetchone()[0]
                
                # Patient profiles completion
                cursor.execute('''
                    SELECT COUNT(*) FROM patient_profiles_enhanced 
                    WHERE allergies IS NOT NULL AND emergency_contacts IS NOT NULL
                ''')
                complete_profiles = cursor.fetchone()[0]
                
                # Provider credentials
                cursor.execute('SELECT COUNT(*) FROM provider_credentials')
                provider_credentials = cursor.fetchone()[0]
                
                enhanced_stats = {
                    **base_stats,
                    'active_access_codes': active_access_codes,
                    'total_audit_entries': total_audit_entries,
                    'recent_exports': recent_exports,
                    'complete_patient_profiles': complete_profiles,
                    'provider_credentials': provider_credentials
                }
                
                return enhanced_stats
                
        except Exception as e:
            logger.error(f"Error getting enhanced system stats: {str(e)}")
            return self.get_system_stats()  # Fallback to base stats