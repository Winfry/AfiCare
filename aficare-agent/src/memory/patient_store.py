"""
Patient Data Store for AfiCare Agent
Handles patient information storage and retrieval
"""

import json
import sqlite3
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class PatientStore:
    """Patient data storage and management"""
    
    def __init__(self, config):
        self.config = config
        self.db_path = self._get_db_path()
        self._initialize_database()
    
    def _get_db_path(self) -> str:
        """Get database path from configuration"""
        db_url = self.config.get('database.url', 'sqlite:///./aficare.db')
        
        if db_url.startswith('sqlite:///'):
            return db_url[10:]  # Remove 'sqlite:///'
        else:
            # For other database types, return a default SQLite path
            return './aficare.db'
    
    def _initialize_database(self):
        """Initialize database tables"""
        
        try:
            # Ensure directory exists
            db_dir = Path(self.db_path).parent
            db_dir.mkdir(parents=True, exist_ok=True)
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Patients table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS patients (
                        id TEXT PRIMARY KEY,
                        age INTEGER,
                        gender TEXT,
                        weight REAL,
                        medical_history TEXT,
                        current_medications TEXT,
                        allergies TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Consultations table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS consultations (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_id TEXT,
                        timestamp TIMESTAMP,
                        chief_complaint TEXT,
                        symptoms TEXT,
                        vital_signs TEXT,
                        triage_level TEXT,
                        suspected_conditions TEXT,
                        recommendations TEXT,
                        referral_needed BOOLEAN,
                        follow_up_required BOOLEAN,
                        confidence_score REAL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (patient_id) REFERENCES patients (id)
                    )
                ''')
                
                # Vital signs history table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS vital_signs_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_id TEXT,
                        consultation_id INTEGER,
                        temperature REAL,
                        systolic_bp INTEGER,
                        diastolic_bp INTEGER,
                        pulse INTEGER,
                        respiratory_rate INTEGER,
                        oxygen_saturation REAL,
                        recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (patient_id) REFERENCES patients (id),
                        FOREIGN KEY (consultation_id) REFERENCES consultations (id)
                    )
                ''')
                
                conn.commit()
                logger.info("Database initialized successfully")
                
        except Exception as e:
            logger.error(f"Failed to initialize database: {str(e)}")
            raise
    
    async def save_consultation(self, consultation_result: Any) -> bool:
        """Save consultation result to database"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Insert consultation record
                cursor.execute('''
                    INSERT INTO consultations (
                        patient_id, timestamp, triage_level, suspected_conditions,
                        recommendations, referral_needed, follow_up_required, confidence_score
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    consultation_result.patient_id,
                    consultation_result.timestamp.isoformat(),
                    consultation_result.triage_level,
                    json.dumps(consultation_result.suspected_conditions),
                    json.dumps(consultation_result.recommendations),
                    consultation_result.referral_needed,
                    consultation_result.follow_up_required,
                    consultation_result.confidence_score
                ))
                
                conn.commit()
                logger.info(f"Consultation saved for patient {consultation_result.patient_id}")
                return True
                
        except Exception as e:
            logger.error(f"Failed to save consultation: {str(e)}")
            return False
    
    async def get_patient_history(self, patient_id: str) -> Dict[str, Any]:
        """Get patient consultation history"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Get patient info
                cursor.execute('SELECT * FROM patients WHERE id = ?', (patient_id,))
                patient_row = cursor.fetchone()
                
                # Get consultations
                cursor.execute('''
                    SELECT * FROM consultations 
                    WHERE patient_id = ? 
                    ORDER BY timestamp DESC
                ''', (patient_id,))
                consultation_rows = cursor.fetchall()
                
                # Get column names
                patient_columns = [desc[0] for desc in cursor.description] if patient_row else []
                consultation_columns = [desc[0] for desc in cursor.description]
                
                # Format patient data
                patient_data = dict(zip(patient_columns, patient_row)) if patient_row else None
                
                # Format consultations
                consultations = []
                for row in consultation_rows:
                    consultation = dict(zip(consultation_columns, row))
                    # Parse JSON fields
                    if consultation.get('suspected_conditions'):
                        consultation['suspected_conditions'] = json.loads(consultation['suspected_conditions'])
                    if consultation.get('recommendations'):
                        consultation['recommendations'] = json.loads(consultation['recommendations'])
                    consultations.append(consultation)
                
                return {
                    'patient': patient_data,
                    'consultations': consultations,
                    'total_consultations': len(consultations)
                }
                
        except Exception as e:
            logger.error(f"Failed to get patient history: {str(e)}")
            return {'patient': None, 'consultations': [], 'total_consultations': 0}
    
    async def update_patient(self, patient_id: str, updates: Dict[str, Any]) -> bool:
        """Update patient information"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if patient exists
                cursor.execute('SELECT id FROM patients WHERE id = ?', (patient_id,))
                exists = cursor.fetchone()
                
                if exists:
                    # Update existing patient
                    set_clause = ', '.join([f"{key} = ?" for key in updates.keys()])
                    values = list(updates.values()) + [patient_id]
                    
                    cursor.execute(f'''
                        UPDATE patients 
                        SET {set_clause}, updated_at = CURRENT_TIMESTAMP 
                        WHERE id = ?
                    ''', values)
                else:
                    # Insert new patient
                    columns = ', '.join(updates.keys())
                    placeholders = ', '.join(['?' for _ in updates])
                    values = [patient_id] + list(updates.values())
                    
                    cursor.execute(f'''
                        INSERT INTO patients (id, {columns}) 
                        VALUES (?, {placeholders})
                    ''', values)
                
                conn.commit()
                logger.info(f"Patient {patient_id} updated successfully")
                return True
                
        except Exception as e:
            logger.error(f"Failed to update patient: {str(e)}")
            return False
    
    def is_connected(self) -> bool:
        """Check if database connection is working"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute('SELECT 1')
                return True
        except Exception:
            return False
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get database statistics"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Count patients
                cursor.execute('SELECT COUNT(*) FROM patients')
                patient_count = cursor.fetchone()[0]
                
                # Count consultations
                cursor.execute('SELECT COUNT(*) FROM consultations')
                consultation_count = cursor.fetchone()[0]
                
                # Get recent activity
                cursor.execute('''
                    SELECT COUNT(*) FROM consultations 
                    WHERE created_at >= datetime('now', '-7 days')
                ''')
                recent_consultations = cursor.fetchone()[0]
                
                return {
                    'total_patients': patient_count,
                    'total_consultations': consultation_count,
                    'consultations_last_7_days': recent_consultations,
                    'database_size': Path(self.db_path).stat().st_size if Path(self.db_path).exists() else 0
                }
                
        except Exception as e:
            logger.error(f"Failed to get statistics: {str(e)}")
            return {
                'total_patients': 0,
                'total_consultations': 0,
                'consultations_last_7_days': 0,
                'database_size': 0
            }