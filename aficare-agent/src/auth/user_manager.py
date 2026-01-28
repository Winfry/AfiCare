"""
User Authentication and Authorization System for AfiCare
Enables multi-user access with role-based permissions
"""

import sqlite3
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from dataclasses import dataclass
from pathlib import Path
import logging

logger = logging.getLogger(__name__)


@dataclass
class User:
    """User information"""
    user_id: str
    username: str
    full_name: str
    role: str  # doctor, nurse, clinical_officer, admin
    hospital_id: str
    department: str
    email: str
    is_active: bool
    created_at: datetime
    last_login: Optional[datetime] = None


@dataclass
class Session:
    """User session information"""
    session_id: str
    user_id: str
    username: str
    role: str
    hospital_id: str
    created_at: datetime
    expires_at: datetime


class UserManager:
    """Manages user authentication and authorization"""
    
    def __init__(self, db_path: str = "aficare.db"):
        self.db_path = db_path
        self._initialize_database()
    
    def _initialize_database(self):
        """Initialize user management tables"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Users table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS users (
                        user_id TEXT PRIMARY KEY,
                        username TEXT UNIQUE NOT NULL,
                        password_hash TEXT NOT NULL,
                        full_name TEXT NOT NULL,
                        role TEXT NOT NULL,
                        hospital_id TEXT NOT NULL,
                        department TEXT,
                        email TEXT,
                        phone TEXT,
                        is_active BOOLEAN DEFAULT 1,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        last_login TIMESTAMP,
                        created_by TEXT,
                        FOREIGN KEY (hospital_id) REFERENCES hospitals (hospital_id)
                    )
                ''')
                
                # Sessions table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS sessions (
                        session_id TEXT PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        expires_at TIMESTAMP NOT NULL,
                        ip_address TEXT,
                        user_agent TEXT,
                        is_active BOOLEAN DEFAULT 1,
                        FOREIGN KEY (user_id) REFERENCES users (user_id)
                    )
                ''')
                
                # Hospitals table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS hospitals (
                        hospital_id TEXT PRIMARY KEY,
                        hospital_name TEXT NOT NULL,
                        location TEXT,
                        contact_phone TEXT,
                        contact_email TEXT,
                        address TEXT,
                        is_active BOOLEAN DEFAULT 1,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Access logs table (audit trail)
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS access_logs (
                        log_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id TEXT NOT NULL,
                        action TEXT NOT NULL,
                        resource_type TEXT,
                        resource_id TEXT,
                        ip_address TEXT,
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        details TEXT,
                        FOREIGN KEY (user_id) REFERENCES users (user_id)
                    )
                ''')
                
                # Patient access permissions (optional - for restricted access)
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS patient_access (
                        access_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        patient_id TEXT NOT NULL,
                        user_id TEXT NOT NULL,
                        granted_by TEXT NOT NULL,
                        granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        expires_at TIMESTAMP,
                        reason TEXT,
                        FOREIGN KEY (patient_id) REFERENCES patients (id),
                        FOREIGN KEY (user_id) REFERENCES users (user_id)
                    )
                ''')
                
                conn.commit()
                logger.info("User management database initialized")
                
        except Exception as e:
            logger.error(f"Failed to initialize user database: {str(e)}")
            raise
    
    def _hash_password(self, password: str) -> str:
        """Hash password using SHA-256 with salt"""
        salt = secrets.token_hex(16)
        pwd_hash = hashlib.sha256((password + salt).encode()).hexdigest()
        return f"{salt}${pwd_hash}"
    
    def _verify_password(self, password: str, password_hash: str) -> bool:
        """Verify password against hash"""
        try:
            salt, pwd_hash = password_hash.split('$')
            test_hash = hashlib.sha256((password + salt).encode()).hexdigest()
            return test_hash == pwd_hash
        except Exception:
            return False
    
    def create_hospital(
        self,
        hospital_id: str,
        hospital_name: str,
        location: str = "",
        contact_phone: str = "",
        contact_email: str = "",
        address: str = ""
    ) -> bool:
        """Create a new hospital in the system"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO hospitals (
                        hospital_id, hospital_name, location, 
                        contact_phone, contact_email, address
                    ) VALUES (?, ?, ?, ?, ?, ?)
                ''', (hospital_id, hospital_name, location, 
                      contact_phone, contact_email, address))
                
                conn.commit()
                logger.info(f"Hospital created: {hospital_name}")
                return True
                
        except sqlite3.IntegrityError:
            logger.warning(f"Hospital {hospital_id} already exists")
            return False
        except Exception as e:
            logger.error(f"Failed to create hospital: {str(e)}")
            return False
    
    def create_user(
        self,
        username: str,
        password: str,
        full_name: str,
        role: str,
        hospital_id: str,
        department: str = "",
        email: str = "",
        phone: str = "",
        created_by: str = "system"
    ) -> Optional[str]:
        """
        Create a new user
        
        Args:
            username: Unique username
            password: Plain text password (will be hashed)
            full_name: User's full name
            role: doctor, nurse, clinical_officer, admin
            hospital_id: Hospital identifier
            department: Department name
            email: Email address
            phone: Phone number
            created_by: User ID of creator
            
        Returns:
            User ID if successful, None otherwise
        """
        
        try:
            user_id = f"USR-{secrets.token_hex(8).upper()}"
            password_hash = self._hash_password(password)
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO users (
                        user_id, username, password_hash, full_name, role,
                        hospital_id, department, email, phone, created_by
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (user_id, username, password_hash, full_name, role,
                      hospital_id, department, email, phone, created_by))
                
                conn.commit()
                logger.info(f"User created: {username} ({role})")
                
                # Log the action
                self._log_access(created_by, "CREATE_USER", "user", user_id, 
                               f"Created user {username}")
                
                return user_id
                
        except sqlite3.IntegrityError:
            logger.warning(f"Username {username} already exists")
            return None
        except Exception as e:
            logger.error(f"Failed to create user: {str(e)}")
            return None
    
    def authenticate(
        self,
        username: str,
        password: str,
        ip_address: str = "",
        user_agent: str = ""
    ) -> Optional[Session]:
        """
        Authenticate user and create session
        
        Args:
            username: Username
            password: Password
            ip_address: Client IP address
            user_agent: Client user agent
            
        Returns:
            Session object if successful, None otherwise
        """
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Get user
                cursor.execute('''
                    SELECT user_id, password_hash, role, hospital_id, is_active
                    FROM users WHERE username = ?
                ''', (username,))
                
                result = cursor.fetchone()
                
                if not result:
                    logger.warning(f"Login failed: User {username} not found")
                    return None
                
                user_id, password_hash, role, hospital_id, is_active = result
                
                # Check if user is active
                if not is_active:
                    logger.warning(f"Login failed: User {username} is inactive")
                    return None
                
                # Verify password
                if not self._verify_password(password, password_hash):
                    logger.warning(f"Login failed: Invalid password for {username}")
                    self._log_access(user_id, "LOGIN_FAILED", "authentication", None,
                                   "Invalid password", ip_address)
                    return None
                
                # Create session
                session_id = secrets.token_urlsafe(32)
                created_at = datetime.now()
                expires_at = created_at + timedelta(hours=8)  # 8-hour session
                
                cursor.execute('''
                    INSERT INTO sessions (
                        session_id, user_id, created_at, expires_at,
                        ip_address, user_agent
                    ) VALUES (?, ?, ?, ?, ?, ?)
                ''', (session_id, user_id, created_at, expires_at,
                      ip_address, user_agent))
                
                # Update last login
                cursor.execute('''
                    UPDATE users SET last_login = ? WHERE user_id = ?
                ''', (created_at, user_id))
                
                conn.commit()
                
                # Log successful login
                self._log_access(user_id, "LOGIN_SUCCESS", "authentication", None,
                               f"User logged in", ip_address)
                
                logger.info(f"User {username} logged in successfully")
                
                return Session(
                    session_id=session_id,
                    user_id=user_id,
                    username=username,
                    role=role,
                    hospital_id=hospital_id,
                    created_at=created_at,
                    expires_at=expires_at
                )
                
        except Exception as e:
            logger.error(f"Authentication error: {str(e)}")
            return None
    
    def validate_session(self, session_id: str) -> Optional[Session]:
        """Validate session and return session info"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT s.user_id, u.username, u.role, u.hospital_id,
                           s.created_at, s.expires_at
                    FROM sessions s
                    JOIN users u ON s.user_id = u.user_id
                    WHERE s.session_id = ? AND s.is_active = 1
                ''', (session_id,))
                
                result = cursor.fetchone()
                
                if not result:
                    return None
                
                user_id, username, role, hospital_id, created_at, expires_at = result
                
                # Check if session expired
                expires_at_dt = datetime.fromisoformat(expires_at)
                if datetime.now() > expires_at_dt:
                    logger.info(f"Session {session_id} expired")
                    return None
                
                return Session(
                    session_id=session_id,
                    user_id=user_id,
                    username=username,
                    role=role,
                    hospital_id=hospital_id,
                    created_at=datetime.fromisoformat(created_at),
                    expires_at=expires_at_dt
                )
                
        except Exception as e:
            logger.error(f"Session validation error: {str(e)}")
            return None
    
    def logout(self, session_id: str) -> bool:
        """Logout user by invalidating session"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Get user_id before invalidating
                cursor.execute('SELECT user_id FROM sessions WHERE session_id = ?', 
                             (session_id,))
                result = cursor.fetchone()
                
                if result:
                    user_id = result[0]
                    
                    # Invalidate session
                    cursor.execute('''
                        UPDATE sessions SET is_active = 0 
                        WHERE session_id = ?
                    ''', (session_id,))
                    
                    conn.commit()
                    
                    # Log logout
                    self._log_access(user_id, "LOGOUT", "authentication", None,
                                   "User logged out")
                    
                    logger.info(f"User {user_id} logged out")
                    return True
                
                return False
                
        except Exception as e:
            logger.error(f"Logout error: {str(e)}")
            return False
    
    def can_access_patient(
        self,
        user_id: str,
        patient_id: str,
        hospital_id: str
    ) -> bool:
        """
        Check if user can access patient data
        
        In hospital-wide access model:
        - All users from same hospital can access all patients
        - Optionally check patient_access table for restricted access
        """
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if user is from same hospital
                cursor.execute('''
                    SELECT hospital_id FROM users WHERE user_id = ?
                ''', (user_id,))
                
                result = cursor.fetchone()
                
                if not result:
                    return False
                
                user_hospital_id = result[0]
                
                # Hospital-wide access: same hospital = access granted
                if user_hospital_id == hospital_id:
                    return True
                
                # Check for explicit access grants (cross-hospital referrals)
                cursor.execute('''
                    SELECT COUNT(*) FROM patient_access
                    WHERE patient_id = ? AND user_id = ?
                    AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
                ''', (patient_id, user_id))
                
                count = cursor.fetchone()[0]
                return count > 0
                
        except Exception as e:
            logger.error(f"Access check error: {str(e)}")
            return False
    
    def _log_access(
        self,
        user_id: str,
        action: str,
        resource_type: Optional[str] = None,
        resource_id: Optional[str] = None,
        details: Optional[str] = None,
        ip_address: Optional[str] = None
    ):
        """Log user access for audit trail"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO access_logs (
                        user_id, action, resource_type, resource_id,
                        ip_address, details
                    ) VALUES (?, ?, ?, ?, ?, ?)
                ''', (user_id, action, resource_type, resource_id,
                      ip_address, details))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to log access: {str(e)}")
    
    def get_user(self, user_id: str) -> Optional[User]:
        """Get user information"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT user_id, username, full_name, role, hospital_id,
                           department, email, is_active, created_at, last_login
                    FROM users WHERE user_id = ?
                ''', (user_id,))
                
                result = cursor.fetchone()
                
                if not result:
                    return None
                
                return User(
                    user_id=result[0],
                    username=result[1],
                    full_name=result[2],
                    role=result[3],
                    hospital_id=result[4],
                    department=result[5],
                    email=result[6],
                    is_active=bool(result[7]),
                    created_at=datetime.fromisoformat(result[8]),
                    last_login=datetime.fromisoformat(result[9]) if result[9] else None
                )
                
        except Exception as e:
            logger.error(f"Failed to get user: {str(e)}")
            return None
    
    def list_hospital_users(self, hospital_id: str) -> List[User]:
        """List all users in a hospital"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT user_id, username, full_name, role, hospital_id,
                           department, email, is_active, created_at, last_login
                    FROM users WHERE hospital_id = ? ORDER BY full_name
                ''', (hospital_id,))
                
                users = []
                for row in cursor.fetchall():
                    users.append(User(
                        user_id=row[0],
                        username=row[1],
                        full_name=row[2],
                        role=row[3],
                        hospital_id=row[4],
                        department=row[5],
                        email=row[6],
                        is_active=bool(row[7]),
                        created_at=datetime.fromisoformat(row[8]),
                        last_login=datetime.fromisoformat(row[9]) if row[9] else None
                    ))
                
                return users
                
        except Exception as e:
            logger.error(f"Failed to list users: {str(e)}")
            return []
    
    def get_access_logs(
        self,
        user_id: Optional[str] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get access logs for audit"""
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                if user_id:
                    cursor.execute('''
                        SELECT log_id, user_id, action, resource_type,
                               resource_id, ip_address, timestamp, details
                        FROM access_logs
                        WHERE user_id = ?
                        ORDER BY timestamp DESC
                        LIMIT ?
                    ''', (user_id, limit))
                else:
                    cursor.execute('''
                        SELECT log_id, user_id, action, resource_type,
                               resource_id, ip_address, timestamp, details
                        FROM access_logs
                        ORDER BY timestamp DESC
                        LIMIT ?
                    ''', (limit,))
                
                logs = []
                for row in cursor.fetchall():
                    logs.append({
                       