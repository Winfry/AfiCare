"""
Database Manager for AfiCare MediLink
Handles SQLite database operations for users, consultations, and medical records
"""

import sqlite3
import json
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
import logging

logger = logging.getLogger(__name__)


class DatabaseManager:
    """Manages all database operations for AfiCare MediLink"""
    
    def __init__(self, db_path: str = "aficare.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize database with all required tables"""
        
        try:
            # Ensure directory exists
            db_dir = Path(self.db_path).parent
            db_dir.mkdir(parents=True, exist_ok=True)
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Users table (patients, doctors, nurses, admins)
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
                
                # Consultations table
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
                
                # Access codes table (for patient record sharing)
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS access_codes (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        access_code TEXT UNIQUE NOT NULL,
                        expires_at TIMESTAMP NOT NULL,
                        used_by TEXT,
                        used_at TIMESTAMP,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (patient_medilink_id) REFERENCES users (medilink_id)
                    )
                ''')
                
                # Audit log table (who accessed what when)
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS audit_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_medilink_id TEXT NOT NULL,
                        accessed_by TEXT NOT NULL,
                        access_type TEXT NOT NULL,
                        hospital_id TEXT,
                        ip_address TEXT,
                        user_agent TEXT,
                        accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                conn.commit()
                logger.info("Database initialized successfully")
                
        except Exception as e:
            logger.error(f"Failed to initialize database: {str(e)}")
            raise
    
    def hash_password(self, password: str) -> str:
        """Hash password for secure storage"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def verify_password(self, password: str, password_hash: str) -> bool:
        """Verify password against hash"""
        return hashlib.sha256(password.encode()).hexdigest() == password_hash
    
    # USER MANAGEMENT METHODS
    
    def create_user(self, user_data: Dict[str, Any]) -> Tuple[bool, str]:
        """Create new user account"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if username already exists
                cursor.execute('SELECT username FROM users WHERE username = ?', (user_data['username'],))
                if cursor.fetchone():
                    return False, "Username already exists"
                
                # Check if MediLink ID already exists (for patients)
                if user_data.get('medilink_id'):
                    cursor.execute('SELECT medilink_id FROM users WHERE medilink_id = ?', (user_data['medilink_id'],))
                    if cursor.fetchone():
                        return False, "MediLink ID already exists"
                
                # Hash password
                password_hash = self.hash_password(user_data['password'])
                
                # Insert user
                cursor.execute('''
                    INSERT INTO users (
                        username, password_hash, role, full_name, medilink_id,
                        phone, email, age, gender, location, hospital_id,
                        department, license_number, specialization, years_experience,
                        medical_history, allergies, emergency_name, emergency_phone
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_data['username'],
                    password_hash,
                    user_data['role'],
                    user_data['full_name'],
                    user_data.get('medilink_id'),
                    user_data.get('phone'),
                    user_data.get('email'),
                    user_data.get('age'),
                    user_data.get('gender'),
                    user_data.get('location'),
                    user_data.get('hospital_id'),
                    user_data.get('department'),
                    user_data.get('license_number'),
                    user_data.get('specialization'),
                    user_data.get('years_experience'),
                    user_data.get('medical_history'),
                    user_data.get('allergies'),
                    user_data.get('emergency_name'),
                    user_data.get('emergency_phone')
                ))
                
                conn.commit()
                logger.info(f"User created: {user_data['username']} ({user_data['role']})")
                return True, "User created successfully"
                
        except Exception as e:
            logger.error(f"Failed to create user: {str(e)}")
            return False, f"Database error: {str(e)}"
    
    def authenticate_user(self, username: str, password: str, role: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Authenticate user login"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Get user by username and role
                cursor.execute('''
                    SELECT * FROM users 
                    WHERE username = ? AND role = ?
                ''', (username, role))
                
                user_row = cursor.fetchone()
                
                if not user_row:
                    return False, None
                
                # Get column names
                columns = [desc[0] for desc in cursor.description]
                user_data = dict(zip(columns, user_row))
                
                # Verify password
                if self.verify_password(password, user_data['password_hash']):
                    # Remove password hash from returned data
                    del user_data['password_hash']
                    logger.info(f"User authenticated: {username} ({role})")
                    return True, user_data
                else:
                    return False, None
                    
        except Exception as e:
            logger.error(f"Authentication error: {str(e)}")
            return False, None
    
    def get_user_by_medilink_id(self, medilink_id: str) -> Optional[Dict[str, Any]]:
        """Get user by MediLink ID"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('SELECT * FROM users WHERE medilink_id = ?', (medilink_id,))
                user_row = cursor.fetchone()
                
                if user_row:
                    columns = [desc[0] for desc in cursor.description]
                    user_data = dict(zip(columns, user_row))
                    del user_data['password_hash']  # Remove password hash
                    return user_data
                
                return None
                
        except Exception as e:
            logger.error(f"Error getting user by MediLink ID: {str(e)}")
            return None
    
    # CONSULTATION METHODS
    
    def save_consultation(self, consultation_data: Dict[str, Any]) -> Tuple[bool, str]:
        """Save consultation to database"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO consultations (
                        patient_medilink_id, doctor_username, hospital_id,
                        chief_complaint, symptoms, vital_signs, triage_level,
                        suspected_conditions, recommendations, referral_needed,
                        follow_up_required, confidence_score, notes
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    consultation_data['patient_medilink_id'],
                    consultation_data['doctor_username'],
                    consultation_data.get('hospital_id'),
                    consultation_data.get('chief_complaint'),
                    json.dumps(consultation_data.get('symptoms', [])),
                    json.dumps(consultation_data.get('vital_signs', {})),
                    consultation_data.get('triage_level'),
                    json.dumps(consultation_data.get('suspected_conditions', [])),
                    json.dumps(consultation_data.get('recommendations', [])),
                    consultation_data.get('referral_needed', False),
                    consultation_data.get('follow_up_required', False),
                    consultation_data.get('confidence_score', 0.0),
                    consultation_data.get('notes')
                ))
                
                consultation_id = cursor.lastrowid
                conn.commit()
                
                logger.info(f"Consultation saved: ID {consultation_id}")
                return True, f"Consultation saved with ID {consultation_id}"
                
        except Exception as e:
            logger.error(f"Failed to save consultation: {str(e)}")
            return False, f"Database error: {str(e)}"
    
    def get_patient_consultations(self, medilink_id: str) -> List[Dict[str, Any]]:
        """Get all consultations for a patient"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM consultations 
                    WHERE patient_medilink_id = ? 
                    ORDER BY consultation_date DESC
                ''', (medilink_id,))
                
                consultation_rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                consultations = []
                for row in consultation_rows:
                    consultation = dict(zip(columns, row))
                    
                    # Parse JSON fields
                    if consultation.get('symptoms'):
                        consultation['symptoms'] = json.loads(consultation['symptoms'])
                    if consultation.get('vital_signs'):
                        consultation['vital_signs'] = json.loads(consultation['vital_signs'])
                    if consultation.get('suspected_conditions'):
                        consultation['suspected_conditions'] = json.loads(consultation['suspected_conditions'])
                    if consultation.get('recommendations'):
                        consultation['recommendations'] = json.loads(consultation['recommendations'])
                    
                    consultations.append(consultation)
                
                return consultations
                
        except Exception as e:
            logger.error(f"Error getting patient consultations: {str(e)}")
            return []
    
    # ACCESS CODE METHODS
    
    def generate_access_code(self, medilink_id: str, expires_hours: int = 24) -> Tuple[bool, str]:
        """Generate temporary access code for patient"""
        
        try:
            import secrets
            from datetime import timedelta
            
            # Generate 6-digit code
            access_code = f"{secrets.randbelow(900000) + 100000}"
            expires_at = datetime.now() + timedelta(hours=expires_hours)
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Deactivate old codes for this patient
                cursor.execute('''
                    DELETE FROM access_codes 
                    WHERE patient_medilink_id = ? AND expires_at > ?
                ''', (medilink_id, datetime.now()))
                
                # Insert new code
                cursor.execute('''
                    INSERT INTO access_codes (patient_medilink_id, access_code, expires_at)
                    VALUES (?, ?, ?)
                ''', (medilink_id, access_code, expires_at))
                
                conn.commit()
                
                logger.info(f"Access code generated for {medilink_id}")
                return True, access_code
                
        except Exception as e:
            logger.error(f"Failed to generate access code: {str(e)}")
            return False, "Failed to generate access code"
    
    def verify_access_code(self, access_code: str, used_by: str) -> Tuple[bool, Optional[str]]:
        """Verify access code and return MediLink ID if valid"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if code exists and is not expired
                cursor.execute('''
                    SELECT patient_medilink_id FROM access_codes 
                    WHERE access_code = ? AND expires_at > ? AND used_at IS NULL
                ''', (access_code, datetime.now()))
                
                result = cursor.fetchone()
                
                if result:
                    medilink_id = result[0]
                    
                    # Mark code as used
                    cursor.execute('''
                        UPDATE access_codes 
                        SET used_by = ?, used_at = ? 
                        WHERE access_code = ?
                    ''', (used_by, datetime.now(), access_code))
                    
                    conn.commit()
                    
                    logger.info(f"Access code verified for {medilink_id}")
                    return True, medilink_id
                else:
                    return False, None
                    
        except Exception as e:
            logger.error(f"Error verifying access code: {str(e)}")
            return False, None
    
    # AUDIT LOG METHODS
    
    def log_access(self, patient_medilink_id: str, accessed_by: str, access_type: str, 
                   hospital_id: str = None, ip_address: str = None, user_agent: str = None):
        """Log patient record access for audit trail"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO audit_log (
                        patient_medilink_id, accessed_by, access_type,
                        hospital_id, ip_address, user_agent
                    ) VALUES (?, ?, ?, ?, ?, ?)
                ''', (patient_medilink_id, accessed_by, access_type, hospital_id, ip_address, user_agent))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to log access: {str(e)}")
    
    def get_access_log(self, medilink_id: str) -> List[Dict[str, Any]]:
        """Get access log for patient"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM audit_log 
                    WHERE patient_medilink_id = ? 
                    ORDER BY accessed_at DESC
                ''', (medilink_id,))
                
                log_rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                
                return [dict(zip(columns, row)) for row in log_rows]
                
        except Exception as e:
            logger.error(f"Error getting access log: {str(e)}")
            return []
    
    # STATISTICS METHODS
    
    def get_system_stats(self) -> Dict[str, Any]:
        """Get system statistics"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Count users by role
                cursor.execute('SELECT role, COUNT(*) FROM users GROUP BY role')
                user_counts = dict(cursor.fetchall())
                
                # Count total consultations
                cursor.execute('SELECT COUNT(*) FROM consultations')
                total_consultations = cursor.fetchone()[0]
                
                # Count consultations in last 7 days
                cursor.execute('''
                    SELECT COUNT(*) FROM consultations 
                    WHERE consultation_date >= datetime('now', '-7 days')
                ''')
                recent_consultations = cursor.fetchone()[0]
                
                # Count active access codes
                cursor.execute('''
                    SELECT COUNT(*) FROM access_codes 
                    WHERE expires_at > datetime('now') AND used_at IS NULL
                ''')
                active_codes = cursor.fetchone()[0]
                
                return {
                    'user_counts': user_counts,
                    'total_consultations': total_consultations,
                    'recent_consultations': recent_consultations,
                    'active_access_codes': active_codes,
                    'database_size': Path(self.db_path).stat().st_size if Path(self.db_path).exists() else 0
                }
                
        except Exception as e:
            logger.error(f"Error getting system stats: {str(e)}")
            return {}
    
    def close(self):
        """Close database connection"""
        # SQLite connections are closed automatically with context managers
        pass


# Global database instance
db_manager = None

def get_database() -> DatabaseManager:
    """Get global database manager instance"""
    global db_manager
    if db_manager is None:
        db_manager = DatabaseManager()
    return db_manager