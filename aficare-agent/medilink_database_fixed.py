"""
MediLink Database Version - Self-contained with SQLite storage
Single app for patients, doctors, and admins with role-based interface
Includes rule-based medical AI for consultations
"""

import streamlit as st
from datetime import datetime, timedelta
import secrets
import sqlite3
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass

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
                
                # Users table
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
                        medical_histor