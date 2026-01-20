"""
Enhanced Database Manager for AfiCare MediLink
Extends the basic DatabaseManager with advanced data persistence features
"""

import sqlite3
import json
import hashlib
import secrets
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
import logging
from cryptography.fernet import Fernet
import base64

logger = logging.getLogger(__name__)


class EnhancedDatabaseManager:
    """Enhanced database manager with advanced data persistence features"""
    
    def __init__(self, db_path: str = "aficare_enhanced.db"):
        self.db_path = db_path
        self.encryption_key = self._load_or_generate_encryption_key()
        self.cipher_suite = Fernet(self.encryption_key)
        self.init_database()
    
    def _load_or_generate_encryption_key(self) -> bytes:
        """Load or generate encryption key for sensitive data"""
        key_file = Path(self.db_path).parent / "encryption.key"
        
        if key_file.exists():
            with open(key_file, 'rb') as f:
                return f.read()
        else:
            key = Fernet.generate_key()
            key_file.parent.mkdir(parents=True, exist_ok=True)
            with open(key_file, 'wb') as f:
                f.write(key)
            return key
    
    def _encrypt_data(self, data: str) -> str:
        """Encrypt sensitive data"""
        if not data:
            return data
        return self.cipher_suite.encrypt(data.encode()).decode()
    
    def _decrypt_data(self, encrypted_data: str) -> str:
        """Decrypt sensitive data"""
        if not encrypted_data:
            return encrypted_data
        try:
            return self.cipher_suite.decrypt(encrypted_data.encode()).decode()
        except:
            return encrypted_data  # Return as-is if decryption fails (backward compatibility)
    
    def init_database(self):
        """Initialize database with all required tables including enhancements"""
        
        try:
            # Ensure directory exists
            db_dir = Path(self.db_path).parent
            db_dir.mkdir(parents=True, exist_ok=True)
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Enhanced Users table (backward compatible)
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS users (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        username TEXT UNIQUE NOT NULL,
                        password_hash TEXT NOT NULL,
                        role TEXT NOT NULL,
                        full_name TEXT NOT NULL,
                        medilink_id TEXT UNIQUE,
                        phone TEXT,
                        email TEXT,
                        age INTEGER,
                        gender TEXT,
                        location TEXT,
                        hospital_id TEXT,
                        department TEXT,
                        license_number TEXT,
                        specialization TEXT,
                        years_experience INTEGER,
                        medical_history TEXT,
                        allergies TEXT,
                        emergency_name TEXT,
                        emergency_phone TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Enhanced Consultations table (backward compatible)
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS consultations (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        doctor_username TEXT NOT NULL,
                        hospital_id TEXT,
                        consultation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        chief_complaint TEXT,
                        symptoms TEXT,
                        vital_signs TEXT,
                        triage_level TEXT,
                        suspected_conditions TEXT,
                        recommendations TEXT,
                        referral_needed BOOLEAN,
                        follow_up_required BOOLEAN,
                        confidence_score REAL,
                        notes TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (patient_medilink_id) REFERENCES users (medilink_id)
                    )
                ''')
                
                # Enhanced Access codes table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS access_codes (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        access_code TEXT UNIQUE NOT NULL,
                        expires_at TIMESTAMP NOT NULL,
                        duration_hours INTEGER DEFAULT 24,
                        permissions TEXT, -- JSON object with granular permissions
                        used_by TEXT,
                        used_at TIMESTAMP,
                        revoked_at TIMESTAMP,
                        revoked_by TEXT,
                        qr_code_data TEXT, -- Encrypted QR code payload
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (patient_medilink_id) REFERENCES users (medilink_id)
                    )
                ''')
                
                # Enhanced Audit log table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS audit_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        accessed_by TEXT NOT NULL,
                        access_type TEXT NOT NULL, -- 'login', 'view_records', 'create_consultation', 'export_data'
                        access_method TEXT, -- 'direct', 'access_code', 'qr_code'
                        ip_address TEXT,
                        user_agent TEXT,
                        success BOOLEAN DEFAULT TRUE,
                        failure_reason TEXT,
                        data_accessed TEXT, -- JSON array of data types accessed
                        session_id TEXT,
                        hospital_id TEXT,
                        accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # NEW: Enhanced patient profiles table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS patient_profiles (
                        medilink_id TEXT PRIMARY KEY,
                        allergies TEXT, -- JSON array of allergies
                        chronic_conditions TEXT, -- JSON array of conditions
                        current_medications TEXT, -- JSON array of medications
                        emergency_contacts TEXT, -- JSON array of emergency contacts
                        insurance_info TEXT, -- JSON object with insurance details
                        blood_type TEXT,
                        organ_donor BOOLEAN DEFAULT FALSE,
                        preferred_language TEXT DEFAULT 'English',
                        medical_alerts TEXT, -- JSON array of high-priority alerts
                        communication_preferences TEXT, -- JSON object with preferences
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_by TEXT,
                        FOREIGN KEY (medilink_id) REFERENCES users (medilink_id)
                    )
                ''')
                
                # NEW: Healthcare provider credentials table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS provider_credentials (
                        username TEXT PRIMARY KEY,
                        license_number TEXT,
                        specializations TEXT, -- JSON array of specializations
                        certifications TEXT, -- JSON array of certifications
                        medical_school TEXT,
                        residency_info TEXT,
                        years_experience INTEGER,
                        hospital_affiliations TEXT, -- JSON array of affiliations
                        verification_status TEXT DEFAULT 'pending',
                        verification_date TIMESTAMP,
                        professional_photo TEXT, -- Base64 encoded image
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (username) REFERENCES users (username)
                    )
                ''')
                
                # NEW: Data export log table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS export_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        exported_by TEXT NOT NULL,
                        export_format TEXT NOT NULL, -- 'pdf', 'json', 'csv'
                        date_range_start TIMESTAMP,
                        date_range_end TIMESTAMP,
                        data_types TEXT, -- JSON array of exported data types
                        file_size INTEGER,
                        checksum TEXT,
                        export_purpose TEXT, -- 'patient_request', 'provider_referral', etc.
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        downloaded_at TIMESTAMP,
                        FOREIGN KEY (patient_medilink_id) REFERENCES users (medilink_id)
                    )
                ''')
                
                # NEW: Backup log table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS backup_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        backup_type TEXT NOT NULL, -- 'full', 'incremental'
                        backup_file TEXT NOT NULL,
                        file_size INTEGER,
                        checksum TEXT,
                        compression_ratio REAL,
                        encryption_enabled BOOLEAN DEFAULT TRUE,
                        backup_duration REAL, -- seconds
                        records_count INTEGER,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        verified_at TIMESTAMP,
                        verification_status TEXT DEFAULT 'pending' -- 'pending', 'success', 'failed'
                    )
                ''')
                
                conn.commit()
                logger.info("Enhanced database initialized successfully")
                
        except Exception as e:
            logger.error(f"Failed to initialize enhanced database: {str(e)}")
            raise
    
    def hash_password(self, password: str) -> str:
        """Hash password for secure storage"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def verify_password(self, password: str, password_hash: str) -> bool:
        """Verify password against hash"""
        return hashlib.sha256(password.encode()).hexdigest() == password_hash
    
    # ENHANCED ACCESS CODE METHODS
    
    def generate_access_code(self, medilink_id: str, duration_hours: int = 24, 
                           permissions: Dict[str, bool] = None) -> Tuple[bool, str]:
        """Generate enhanced access code with custom permissions"""
        
        try:
            # Generate 6-digit code
            access_code = f"{secrets.randbelow(900000) + 100000}"
            expires_at = datetime.now() + timedelta(hours=duration_hours)
            
            # Default permissions
            if permissions is None:
                permissions = {
                    "view_basic_info": True,
                    "view_medical_history": True,
                    "view_consultations": True,
                    "view_medications": False,
                    "view_sensitive_data": False
                }
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Insert new code
                cursor.execute('''
                    INSERT INTO access_codes (
                        patient_medilink_id, access_code, expires_at, 
                        duration_hours, permissions
                    ) VALUES (?, ?, ?, ?, ?)
                ''', (
                    medilink_id, access_code, expires_at, 
                    duration_hours, json.dumps(permissions)
                ))
                
                conn.commit()
                
                logger.info(f"Enhanced access code generated for {medilink_id}")
                return True, access_code
                
        except Exception as e:
            logger.error(f"Failed to generate access code: {str(e)}")
            return False, "Failed to generate access code"
    
    def verify_access_code(self, access_code: str, used_by: str) -> Tuple[bool, Optional[str], Optional[Dict[str, bool]]]:
        """Verify access code and return MediLink ID and permissions if valid"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if code exists and is not expired or revoked
                cursor.execute('''
                    SELECT patient_medilink_id, permissions FROM access_codes 
                    WHERE access_code = ? AND expires_at > ? 
                    AND used_at IS NULL AND revoked_at IS NULL
                ''', (access_code, datetime.now()))
                
                result = cursor.fetchone()
                
                if result:
                    medilink_id, permissions_json = result
                    permissions = json.loads(permissions_json) if permissions_json else {}
                    
                    # Mark code as used
                    cursor.execute('''
                        UPDATE access_codes 
                        SET used_by = ?, used_at = ? 
                        WHERE access_code = ?
                    ''', (used_by, datetime.now(), access_code))
                    
                    conn.commit()
                    
                    logger.info(f"Access code verified for {medilink_id}")
                    return True, medilink_id, permissions
                else:
                    return False, None, None
                    
        except Exception as e:
            logger.error(f"Error verifying access code: {str(e)}")
            return False, None, None
    
    def revoke_access_code(self, access_code: str, patient_medilink_id: str, revoked_by: str) -> bool:
        """Revoke an active access code"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    UPDATE access_codes 
                    SET revoked_at = ?, revoked_by = ? 
                    WHERE access_code = ? AND patient_medilink_id = ? 
                    AND revoked_at IS NULL
                ''', (datetime.now(), revoked_by, access_code, patient_medilink_id))
                
                conn.commit()
                
                if cursor.rowcount > 0:
                    logger.info(f"Access code {access_code} revoked by {revoked_by}")
                    return True
                else:
                    return False
                    
        except Exception as e:
            logger.error(f"Error revoking access code: {str(e)}")
            return False
    
    def get_active_access_codes(self, medilink_id: str) -> List[Dict[str, Any]]:
        """Get all active access codes for a patient"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM access_codes 
                    WHERE patient_medilink_id = ? AND expires_at > ? 
                    AND revoked_at IS NULL
                    ORDER BY created_at DESC
                ''', (medilink_id, datetime.now()))
                
                codes = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                result = []
                for code in codes:
                    code_dict = dict(zip(columns, code))
                    if code_dict.get('permissions'):
                        code_dict['permissions'] = json.loads(code_dict['permissions'])
                    result.append(code_dict)
                
                return result
                
        except Exception as e:
            logger.error(f"Error getting active access codes: {str(e)}")
            return []
    
    # ENHANCED AUDIT LOGGING METHODS
    
    def log_access(self, patient_medilink_id: str, accessed_by: str, access_type: str,
                   access_method: str = 'direct', ip_address: str = None, 
                   user_agent: str = None, success: bool = True, 
                   failure_reason: str = None, data_accessed: List[str] = None,
                   session_id: str = None, hospital_id: str = None) -> bool:
        """Enhanced audit logging with comprehensive details"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO audit_log (
                        patient_medilink_id, accessed_by, access_type, access_method,
                        ip_address, user_agent, success, failure_reason, 
                        data_accessed, session_id, hospital_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    patient_medilink_id, accessed_by, access_type, access_method,
                    ip_address, user_agent, success, failure_reason,
                    json.dumps(data_accessed) if data_accessed else None,
                    session_id, hospital_id
                ))
                
                conn.commit()
                return True
                
        except Exception as e:
            logger.error(f"Failed to log access: {str(e)}")
            return False
    
    def get_access_log(self, medilink_id: str, days: int = 30) -> List[Dict[str, Any]]:
        """Get comprehensive access log for patient"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM audit_log 
                    WHERE patient_medilink_id = ? 
                    AND accessed_at >= datetime('now', '-{} days')
                    ORDER BY accessed_at DESC
                '''.format(days), (medilink_id,))
                
                log_rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                result = []
                for row in log_rows:
                    log_entry = dict(zip(columns, row))
                    if log_entry.get('data_accessed'):
                        log_entry['data_accessed'] = json.loads(log_entry['data_accessed'])
                    result.append(log_entry)
                
                return result
                
        except Exception as e:
            logger.error(f"Error getting access log: {str(e)}")
            return []
    
    def get_provider_activity(self, username: str, days: int = 7) -> List[Dict[str, Any]]:
        """Get provider activity summary"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM audit_log 
                    WHERE accessed_by = ? 
                    AND accessed_at >= datetime('now', '-{} days')
                    ORDER BY accessed_at DESC
                '''.format(days), (username,))
                
                activity_rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                result = []
                for row in activity_rows:
                    activity = dict(zip(columns, row))
                    if activity.get('data_accessed'):
                        activity['data_accessed'] = json.loads(activity['data_accessed'])
                    result.append(activity)
                
                return result
                
        except Exception as e:
            logger.error(f"Error getting provider activity: {str(e)}")
            return []
    
    # Continue with remaining methods in next part...
    
    def close(self):
        """Close database connection"""
        # SQLite connections are closed automatically with context managers
        pass


# Global enhanced database instance
enhanced_db_manager = None

def get_enhanced_database() -> EnhancedDatabaseManager:
    """Get global enhanced database manager instance"""
    global enhanced_db_manager
    if enhanced_db_manager is None:
        enhanced_db_manager = EnhancedDatabaseManager()
    return enhanced_db_manager