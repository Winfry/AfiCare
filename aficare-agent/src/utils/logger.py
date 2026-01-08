"""
Logging Configuration for AfiCare Agent
"""

import logging
import logging.handlers
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional


def setup_logging(
    level: str = "INFO",
    log_file: Optional[str] = None,
    max_file_size: int = 10 * 1024 * 1024,  # 10MB
    backup_count: int = 5
):
    """
    Setup logging configuration for AfiCare Agent
    
    Args:
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional log file path
        max_file_size: Maximum log file size in bytes
        backup_count: Number of backup log files to keep
    """
    
    # Create logs directory if it doesn't exist
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    # Set default log file if not provided
    if log_file is None:
        timestamp = datetime.now().strftime("%Y%m%d")
        log_file = log_dir / f"aficare_{timestamp}.log"
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, level.upper()))
    
    # Clear existing handlers
    root_logger.handlers.clear()
    
    # Create formatters
    detailed_formatter = logging.Formatter(
        fmt='%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    simple_formatter = logging.Formatter(
        fmt='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%H:%M:%S'
    )
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, level.upper()))
    console_handler.setFormatter(simple_formatter)
    
    # Add color support for console output
    if hasattr(sys.stdout, 'isatty') and sys.stdout.isatty():
        console_handler.setFormatter(ColoredFormatter())
    
    root_logger.addHandler(console_handler)
    
    # File handler with rotation
    try:
        file_handler = logging.handlers.RotatingFileHandler(
            filename=log_file,
            maxBytes=max_file_size,
            backupCount=backup_count,
            encoding='utf-8'
        )
        file_handler.setLevel(logging.DEBUG)  # Always log everything to file
        file_handler.setFormatter(detailed_formatter)
        root_logger.addHandler(file_handler)
        
    except Exception as e:
        print(f"Warning: Could not setup file logging: {e}")
    
    # Setup specific loggers
    setup_medical_logger()
    setup_security_logger()
    
    # Log startup message
    logger = logging.getLogger(__name__)
    logger.info(f"Logging initialized - Level: {level}, File: {log_file}")


def setup_medical_logger():
    """Setup specialized logger for medical events"""
    
    medical_logger = logging.getLogger('aficare.medical')
    
    # Create medical events log file
    log_dir = Path("logs")
    medical_log_file = log_dir / "medical_events.log"
    
    try:
        medical_handler = logging.handlers.RotatingFileHandler(
            filename=medical_log_file,
            maxBytes=5 * 1024 * 1024,  # 5MB
            backupCount=10,
            encoding='utf-8'
        )
        
        medical_formatter = logging.Formatter(
            fmt='%(asctime)s - MEDICAL - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        medical_handler.setFormatter(medical_formatter)
        medical_logger.addHandler(medical_handler)
        medical_logger.setLevel(logging.INFO)
        
    except Exception as e:
        print(f"Warning: Could not setup medical logging: {e}")


def setup_security_logger():
    """Setup specialized logger for security events"""
    
    security_logger = logging.getLogger('aficare.security')
    
    # Create security log file
    log_dir = Path("logs")
    security_log_file = log_dir / "security.log"
    
    try:
        security_handler = logging.handlers.RotatingFileHandler(
            filename=security_log_file,
            maxBytes=5 * 1024 * 1024,  # 5MB
            backupCount=10,
            encoding='utf-8'
        )
        
        security_formatter = logging.Formatter(
            fmt='%(asctime)s - SECURITY - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        security_handler.setFormatter(security_formatter)
        security_logger.addHandler(security_handler)
        security_logger.setLevel(logging.WARNING)
        
    except Exception as e:
        print(f"Warning: Could not setup security logging: {e}")


class ColoredFormatter(logging.Formatter):
    """Colored console formatter for better readability"""
    
    # ANSI color codes
    COLORS = {
        'DEBUG': '\033[36m',      # Cyan
        'INFO': '\033[32m',       # Green
        'WARNING': '\033[33m',    # Yellow
        'ERROR': '\033[31m',      # Red
        'CRITICAL': '\033[35m',   # Magenta
        'RESET': '\033[0m'        # Reset
    }
    
    def __init__(self):
        super().__init__(
            fmt='%(asctime)s - %(levelname)s - %(message)s',
            datefmt='%H:%M:%S'
        )
    
    def format(self, record):
        # Add color to level name
        level_color = self.COLORS.get(record.levelname, '')
        reset_color = self.COLORS['RESET']
        
        # Create colored record
        colored_record = logging.makeLogRecord(record.__dict__)
        colored_record.levelname = f"{level_color}{record.levelname}{reset_color}"
        
        return super().format(colored_record)


def get_medical_logger():
    """Get the medical events logger"""
    return logging.getLogger('aficare.medical')


def get_security_logger():
    """Get the security events logger"""
    return logging.getLogger('aficare.security')


def log_medical_event(
    event_type: str,
    patient_id: str,
    details: str,
    level: str = "INFO"
):
    """
    Log a medical event
    
    Args:
        event_type: Type of medical event (consultation, diagnosis, treatment, etc.)
        patient_id: Patient identifier
        details: Event details
        level: Log level
    """
    
    medical_logger = get_medical_logger()
    
    message = f"[{event_type.upper()}] Patient: {patient_id} - {details}"
    
    log_level = getattr(logging, level.upper(), logging.INFO)
    medical_logger.log(log_level, message)


def log_security_event(
    event_type: str,
    user_id: Optional[str],
    details: str,
    level: str = "WARNING"
):
    """
    Log a security event
    
    Args:
        event_type: Type of security event (login, access, error, etc.)
        user_id: User identifier (if applicable)
        details: Event details
        level: Log level
    """
    
    security_logger = get_security_logger()
    
    user_info = f"User: {user_id}" if user_id else "Anonymous"
    message = f"[{event_type.upper()}] {user_info} - {details}"
    
    log_level = getattr(logging, level.upper(), logging.WARNING)
    security_logger.log(log_level, message)


class MedicalEventLogger:
    """Context manager for logging medical events"""
    
    def __init__(self, event_type: str, patient_id: str):
        self.event_type = event_type
        self.patient_id = patient_id
        self.start_time = None
    
    def __enter__(self):
        self.start_time = datetime.now()
        log_medical_event(
            self.event_type,
            self.patient_id,
            f"Started at {self.start_time.strftime('%H:%M:%S')}"
        )
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        end_time = datetime.now()
        duration = (end_time - self.start_time).total_seconds()
        
        if exc_type is None:
            log_medical_event(
                self.event_type,
                self.patient_id,
                f"Completed successfully in {duration:.2f}s"
            )
        else:
            log_medical_event(
                self.event_type,
                self.patient_id,
                f"Failed after {duration:.2f}s: {exc_val}",
                level="ERROR"
            )
    
    def log_progress(self, message: str):
        """Log progress during the event"""
        log_medical_event(self.event_type, self.patient_id, message)