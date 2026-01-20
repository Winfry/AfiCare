# Data Persistence Enhancement - Design Document

## Overview

The Data Persistence Enhancement builds upon the existing AfiCare MediLink system to provide advanced data management capabilities. The current system already implements basic SQLite database functionality with user authentication, consultation storage, and simple access codes. This enhancement adds comprehensive audit logging, enhanced patient profiles, QR code sharing, data export capabilities, and robust backup/recovery systems.

The design maintains the existing architecture while extending it with new database tables, API methods, and user interface components. The system continues to use SQLite for data persistence, Python for backend logic, and Streamlit for the web interface, ensuring consistency with the current implementation.

Key enhancement areas include:
- **Enhanced Access Control**: Extended access code system with QR codes and granular permissions
- **Comprehensive Audit Trail**: Complete logging of all patient record access and system activities
- **Rich Patient Profiles**: Extended patient information including medical alerts, emergency contacts, and preferences
- **Healthcare Provider Credentials**: Professional credential management and verification
- **Data Portability**: Multi-format export capabilities for patient records
- **Enterprise Backup**: Automated backup and recovery systems with integrity verification

## Architecture

### System Architecture Overview

The enhanced system maintains the existing three-tier architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐│
│  │   Patient UI    │ │  Provider UI    │ │   Admin UI      ││
│  │   (Streamlit)   │ │   (Streamlit)   │ │  (Streamlit)    ││
│  └─────────────────┘ └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic Layer                      │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐│
│  │ Access Control  │ │  Audit Manager  │ │ Export Manager  ││
│  │    Manager      │ │                 │ │                 ││
│  └─────────────────┘ └─────────────────┘ └─────────────────┘│
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐│
│  │ Profile Manager │ │ Backup Manager  │ │   QR Manager    ││
│  │                 │ │                 │ │                 ││
│  └─────────────────┘ └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Data Persistence Layer                    │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                SQLite Database                          │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐   │ │
│  │  │   Users     │ │Consultations│ │  Access Codes   │   │ │
│  │  └─────────────┘ └─────────────┘ └─────────────────┘   │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐   │ │
│  │  │ Audit Log   │ │  Profiles   │ │   Credentials   │   │ │
│  │  └─────────────┘ └─────────────┘ └─────────────────┘   │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Database Schema Extensions

The enhanced system extends the existing database schema with new tables while maintaining backward compatibility:

**Existing Tables (Enhanced)**:
- `users` - Extended with additional profile fields
- `consultations` - Maintained as-is
- `access_codes` - Enhanced with duration and revocation capabilities
- `audit_log` - Enhanced with additional tracking fields

**New Tables**:
- `patient_profiles` - Extended patient medical information
- `provider_credentials` - Healthcare provider professional information
- `backup_log` - Backup and recovery tracking
- `export_log` - Data export activity tracking

### Security Architecture

The security model implements multiple layers of protection:

1. **Authentication Layer**: Username/password with role-based access
2. **Authorization Layer**: Role-based permissions with granular access control
3. **Audit Layer**: Comprehensive logging of all data access and modifications
4. **Encryption Layer**: Sensitive data encryption at rest and in transit
5. **Access Control Layer**: Temporary access codes and QR-based sharing

## Components and Interfaces

### Enhanced Database Manager

The `DatabaseManager` class is extended with new methods for enhanced functionality:

```python
class EnhancedDatabaseManager(DatabaseManager):
    """Extended database manager with enhanced persistence features"""
    
    # Access Code Management
    def generate_access_code(self, medilink_id: str, duration_hours: int = 24, 
                           permissions: Dict[str, bool] = None) -> Tuple[bool, str]
    def verify_access_code(self, access_code: str, used_by: str) -> Tuple[bool, Optional[str]]
    def revoke_access_code(self, access_code: str, patient_medilink_id: str) -> bool
    def get_active_access_codes(self, medilink_id: str) -> List[Dict[str, Any]]
    
    # Enhanced Audit Logging
    def log_access(self, patient_medilink_id: str, accessed_by: str, access_type: str,
                   access_method: str = 'direct', ip_address: str = None, 
                   user_agent: str = None, success: bool = True, 
                   failure_reason: str = None) -> bool
    def get_access_log(self, medilink_id: str, days: int = 30) -> List[Dict[str, Any]]
    def get_provider_activity(self, username: str, days: int = 7) -> List[Dict[str, Any]]
    def get_system_audit_summary(self, days: int = 7) -> Dict[str, Any]
    
    # Patient Profile Management
    def update_patient_profile(self, medilink_id: str, profile_data: Dict[str, Any]) -> bool
    def get_patient_profile(self, medilink_id: str) -> Optional[Dict[str, Any]]
    def get_patient_emergency_info(self, medilink_id: str) -> Optional[Dict[str, Any]]
    
    # Provider Credential Management
    def update_provider_credentials(self, username: str, credentials: Dict[str, Any]) -> bool
    def get_provider_credentials(self, username: str) -> Optional[Dict[str, Any]]
    def verify_provider_license(self, license_number: str) -> bool
    
    # Data Export
    def export_patient_data(self, medilink_id: str, format: str = 'pdf', 
                           date_range: Tuple[str, str] = None) -> bytes
    def generate_patient_summary(self, medilink_id: str, provider: str, 
                               purpose: str = 'consultation') -> Dict[str, Any]
    def log_export_activity(self, medilink_id: str, exported_by: str, 
                           format: str, success: bool) -> bool
    
    # Backup and Recovery
    def create_backup(self, backup_path: str = None) -> Tuple[bool, str]
    def restore_from_backup(self, backup_file: str) -> Tuple[bool, str]
    def verify_backup_integrity(self, backup_file: str) -> bool
    def get_backup_history(self, days: int = 30) -> List[Dict[str, Any]]
    def schedule_automated_backup(self, interval_hours: int = 24) -> bool
```

### QR Code Manager

New component for handling QR code generation and validation:

```python
class QRCodeManager:
    """Manages QR code generation and validation for patient access"""
    
    def __init__(self, database_manager: EnhancedDatabaseManager):
        self.db = database_manager
        self.encryption_key = self._load_or_generate_key()
    
    def generate_patient_qr(self, medilink_id: str, duration_hours: int = 24,
                           permissions: Dict[str, bool] = None) -> Tuple[bool, bytes]
    def validate_qr_data(self, qr_data: str, accessed_by: str) -> Tuple[bool, Optional[str]]
    def create_qr_image(self, qr_data: str, size: int = 200) -> bytes
    def _encrypt_qr_payload(self, payload: Dict[str, Any]) -> str
    def _decrypt_qr_payload(self, encrypted_data: str) -> Optional[Dict[str, Any]]
```

### Export Manager

Component for handling data export in multiple formats:

```python
class ExportManager:
    """Manages patient data export in various formats"""
    
    def __init__(self, database_manager: EnhancedDatabaseManager):
        self.db = database_manager
    
    def export_to_pdf(self, patient_data: Dict[str, Any], 
                     consultations: List[Dict[str, Any]]) -> bytes
    def export_to_json(self, patient_data: Dict[str, Any], 
                      consultations: List[Dict[str, Any]]) -> str
    def export_to_csv(self, consultations: List[Dict[str, Any]]) -> str
    def generate_medical_summary(self, patient_data: Dict[str, Any], 
                               consultations: List[Dict[str, Any]], 
                               purpose: str) -> Dict[str, Any]
    def create_verification_qr(self, export_data: Dict[str, Any]) -> bytes
```

### Backup Manager

Component for automated backup and recovery operations:

```python
class BackupManager:
    """Manages database backup and recovery operations"""
    
    def __init__(self, database_manager: EnhancedDatabaseManager, 
                 backup_directory: str = "backups"):
        self.db = database_manager
        self.backup_dir = Path(backup_directory)
        self.backup_dir.mkdir(exist_ok=True)
    
    def create_full_backup(self) -> Tuple[bool, str]
    def create_incremental_backup(self) -> Tuple[bool, str]
    def restore_database(self, backup_file: str, verify_integrity: bool = True) -> bool
    def verify_backup(self, backup_file: str) -> Tuple[bool, Dict[str, Any]]
    def cleanup_old_backups(self, retention_days: int = 30) -> int
    def schedule_backup_job(self, interval_hours: int = 24) -> bool
    def encrypt_backup(self, backup_file: str) -> bool
    def decrypt_backup(self, encrypted_file: str) -> str
```

### Enhanced User Interface Components

The Streamlit interface is extended with new components for each user role:

**Patient Interface Extensions**:
- Enhanced profile management with medical alerts and emergency contacts
- QR code generation and management interface
- Access code creation with customizable permissions and duration
- Data export interface with format selection and date ranges
- Privacy settings with granular data sharing controls

**Healthcare Provider Interface Extensions**:
- QR code scanning capability for patient access
- Enhanced patient record view with comprehensive medical history
- Provider credential management interface
- Patient summary report generation
- Activity dashboard with access patterns

**Administrator Interface Extensions**:
- Comprehensive audit trail viewer with filtering and search
- System backup and recovery management interface
- User credential verification and management
- System performance and security monitoring dashboard
- Backup scheduling and retention policy configuration

## Data Models

### Enhanced Patient Profile Model

```python
@dataclass
class PatientProfile:
    medilink_id: str
    allergies: List[str]
    chronic_conditions: List[str]
    current_medications: List[Dict[str, Any]]  # {name, dosage, frequency, prescriber}
    emergency_contacts: List[Dict[str, Any]]   # {name, phone, relationship, primary}
    insurance_info: Optional[Dict[str, Any]]   # {provider, policy_number, group}
    blood_type: Optional[str]
    organ_donor: bool
    preferred_language: str
    medical_alerts: List[str]  # High-priority medical flags
    communication_preferences: Dict[str, bool]
    updated_at: datetime
    updated_by: str
```

### Provider Credentials Model

```python
@dataclass
class ProviderCredentials:
    username: str
    license_number: str
    specializations: List[str]
    certifications: List[Dict[str, Any]]  # {name, issuer, date, expiry}
    medical_school: str
    residency_info: Optional[str]
    years_experience: int
    hospital_affiliations: List[str]
    verification_status: str  # pending, verified, expired
    verification_date: Optional[datetime]
    updated_at: datetime
```

### Enhanced Access Code Model

```python
@dataclass
class AccessCode:
    id: int
    patient_medilink_id: str
    access_code: str
    expires_at: datetime
    duration_hours: int
    permissions: Dict[str, bool]  # {view_history, view_vitals, view_medications}
    used_by: Optional[str]
    used_at: Optional[datetime]
    revoked_at: Optional[datetime]
    revoked_by: Optional[str]
    created_at: datetime
    qr_code_data: Optional[str]
```

### Comprehensive Audit Log Model

```python
@dataclass
class AuditLogEntry:
    id: int
    patient_medilink_id: str
    accessed_by: str
    access_type: str  # login, view_records, create_consultation, export_data, etc.
    access_method: str  # direct, access_code, qr_code
    ip_address: Optional[str]
    user_agent: Optional[str]
    success: bool
    failure_reason: Optional[str]
    data_accessed: Optional[List[str]]  # List of data types accessed
    session_id: Optional[str]
    accessed_at: datetime
```

### Data Export Model

```python
@dataclass
class DataExport:
    id: int
    patient_medilink_id: str
    exported_by: str
    export_format: str  # pdf, json, csv
    date_range_start: Optional[datetime]
    date_range_end: Optional[datetime]
    data_types: List[str]  # consultations, vitals, medications, etc.
    file_size: int
    checksum: str
    export_purpose: str  # patient_request, provider_referral, legal_compliance
    created_at: datetime
    downloaded_at: Optional[datetime]
```

### Backup Record Model

```python
@dataclass
class BackupRecord:
    id: int
    backup_type: str  # full, incremental
    backup_file: str
    file_size: int
    checksum: str
    compression_ratio: float
    encryption_enabled: bool
    backup_duration: float  # seconds
    records_count: int
    created_at: datetime
    verified_at: Optional[datetime]
    verification_status: str  # pending, success, failed
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Access Code Generation and Validation
*For any* patient MediLink ID and valid duration setting, generating an access code should produce a unique 6-digit code that expires at the correct time and can be successfully validated by healthcare providers until expiration or revocation.
**Validates: Requirements 1.1, 1.2, 1.3, 1.4**

### Property 2: Access Code Management and Revocation  
*For any* active access code, the patient should be able to revoke it at any time, and revoked codes should immediately become invalid for healthcare provider access, with the system accurately tracking the count of active codes.
**Validates: Requirements 1.5, 1.6, 1.7**

### Property 3: QR Code Generation and Encryption
*For any* valid access code, generating a QR code should produce encrypted data that contains all necessary access information and can be successfully validated by healthcare providers, with QR code expiration tied to the underlying access code expiration.
**Validates: Requirements 2.1, 2.3, 2.4, 2.5, 2.6**

### Property 4: Comprehensive Audit Logging
*For any* patient record access event, the system should create an immutable audit log entry containing timestamp, accessing user, access method, IP address, and success/failure status, with logs being retrievable by patients and administrators.
**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.7**

### Property 5: Provider Activity Tracking
*For any* healthcare provider action, the system should track and link the activity to specific patient interactions, generate accurate activity summaries, flag unusual access patterns, and produce compliance reports.
**Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6**

### Property 6: Patient Profile Completeness
*For any* patient profile, the system should support storing and retrieving all required medical information including allergies, chronic conditions, medications, emergency contacts, insurance information, blood type, organ donor status, preferred language, and medical alerts.
**Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6**

### Property 7: Profile Update Functionality
*For any* patient or healthcare provider, the system should allow them to update their own profile information, with changes being properly validated, stored, and retrievable.
**Validates: Requirements 5.7, 6.7**

### Property 8: Provider Credential Management
*For any* healthcare provider profile, the system should support storing and retrieving all professional information including license number, specializations, certifications, medical school, residency information, years of experience, hospital affiliations, and verification status.
**Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6**

### Property 9: Multi-Format Data Export
*For any* patient medical data and specified date range, the system should generate exports in multiple formats (PDF, JSON, CSV) containing all requested medical information including consultations, diagnoses, treatments, and vital signs, with verification QR codes and visual charts where applicable.
**Validates: Requirements 7.1, 7.2, 7.4, 7.5, 7.6, 7.7**

### Property 10: Provider Report Generation
*For any* healthcare provider and patient combination, the system should generate customizable summary reports for different purposes (referral, consultation, discharge) that include recent consultations, key health indicators, and AI analysis summaries while maintaining patient privacy controls.
**Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6**

### Property 11: Automated Backup Creation and Storage
*For any* scheduled backup operation, the system should create complete database backups, store them in multiple locations with encryption, automatically verify backup integrity, and maintain backups according to the retention policy.
**Validates: Requirements 9.1, 9.2, 9.3, 9.6, 9.7**

### Property 12: Backup Restoration and Recovery
*For any* valid backup file, the system should be able to restore the database without data loss, verify data integrity after restoration, preserve all patient data, and notify users of recovery operations.
**Validates: Requirements 9.4, 10.3, 10.4, 10.6**

## Error Handling

The enhanced system implements comprehensive error handling across all components:

### Database Error Handling
- **Connection Failures**: Automatic retry with exponential backoff for transient connection issues
- **Constraint Violations**: Graceful handling of unique constraint violations with user-friendly error messages
- **Transaction Rollback**: Automatic rollback of failed transactions to maintain data consistency
- **Corruption Detection**: Integrity checks with automatic backup restoration for corrupted databases

### Access Control Error Handling
- **Invalid Access Codes**: Clear error messages for expired, revoked, or non-existent access codes
- **Permission Denied**: Appropriate error responses for unauthorized access attempts with audit logging
- **QR Code Errors**: Validation of QR code format and encryption with fallback to manual code entry
- **Session Timeout**: Graceful session expiration with automatic logout and data preservation

### Export Error Handling
- **Large Dataset Exports**: Chunked processing for large exports with progress indicators and timeout handling
- **Format Conversion Errors**: Fallback to alternative formats when primary format generation fails
- **File System Errors**: Temporary storage management with cleanup and retry mechanisms
- **Network Interruptions**: Resume capability for interrupted downloads with integrity verification

### Backup Error Handling
- **Storage Failures**: Multiple backup location attempts with failure notification and manual intervention triggers
- **Encryption Errors**: Key management error handling with secure key recovery procedures
- **Verification Failures**: Automatic re-backup when integrity verification fails
- **Recovery Errors**: Step-by-step recovery validation with rollback capability for failed restorations

### User Interface Error Handling
- **Input Validation**: Real-time validation with clear error messages and correction guidance
- **Network Connectivity**: Offline mode detection with data synchronization when connectivity returns
- **Browser Compatibility**: Graceful degradation for unsupported features with alternative workflows
- **Mobile Device Handling**: Responsive error messages and touch-friendly error recovery options

## Testing Strategy

The testing strategy employs a comprehensive dual approach combining unit tests for specific scenarios and property-based tests for universal correctness validation.

### Unit Testing Approach

Unit tests focus on specific examples, edge cases, and integration points:

**Database Operations**:
- Test specific CRUD operations for all new tables
- Verify foreign key constraints and data integrity
- Test transaction rollback scenarios
- Validate database schema migrations

**Access Control Scenarios**:
- Test access code generation with specific durations
- Verify QR code encryption/decryption with known test data
- Test permission validation for different user roles
- Validate session timeout and cleanup

**Export Functionality**:
- Test PDF generation with sample patient data
- Verify JSON export format compliance
- Test CSV export with various data types
- Validate export file integrity and checksums

**Error Conditions**:
- Test invalid input handling for all user interfaces
- Verify error logging and notification systems
- Test system behavior under resource constraints
- Validate recovery procedures with corrupted test data

### Property-Based Testing Configuration

Property-based tests verify universal properties across randomized inputs using **Hypothesis** (Python's property-based testing library):

**Test Configuration**:
- Minimum 100 iterations per property test to ensure comprehensive coverage
- Custom generators for medical data types (MediLink IDs, medical conditions, vital signs)
- Stateful testing for complex workflows (access code lifecycle, audit trail consistency)
- Shrinking enabled to find minimal failing examples

**Property Test Implementation**:
Each correctness property must be implemented as a single property-based test with the following tag format:

```python
@given(strategies.medilink_ids(), strategies.durations())
def test_access_code_generation_and_validation(medilink_id, duration_hours):
    """
    Feature: data-persistence-enhancement, Property 1: Access Code Generation and Validation
    """
    # Property test implementation
```

**Data Generators**:
- `strategies.medilink_ids()`: Generate valid MediLink ID formats
- `strategies.medical_conditions()`: Generate realistic medical condition names
- `strategies.vital_signs()`: Generate physiologically valid vital sign ranges
- `strategies.access_permissions()`: Generate valid permission combinations
- `strategies.date_ranges()`: Generate valid date ranges for exports

**Stateful Testing Scenarios**:
- Access code lifecycle: generation → validation → expiration/revocation
- Audit trail consistency: action → log entry → retrieval → export
- Backup and recovery: backup creation → verification → restoration → integrity check

### Integration Testing

Integration tests verify end-to-end workflows across system components:

**Patient Record Sharing Workflow**:
1. Patient generates access code with specific permissions
2. Healthcare provider uses code to access records
3. System logs access event with complete audit trail
4. Patient views access history and revokes code
5. Verify revoked code no longer grants access

**Data Export and Verification Workflow**:
1. Patient requests data export with date range
2. System generates export in multiple formats
3. Export includes verification QR code
4. Healthcare provider scans QR code to verify authenticity
5. Audit log records export and verification events

**Backup and Recovery Workflow**:
1. System creates automated backup with encryption
2. Backup integrity is verified automatically
3. Simulate system failure and restore from backup
4. Verify all patient data is preserved and accessible
5. Confirm audit trail continuity across backup/restore

### Performance Testing

Performance tests ensure system scalability and responsiveness:

**Load Testing Scenarios**:
- 1,000+ concurrent users accessing patient records
- Large dataset exports (10,000+ consultations)
- Bulk access code generation and validation
- Database backup with 10GB+ data size

**Response Time Requirements**:
- Access code generation: < 1 second
- Patient record retrieval: < 2 seconds  
- Audit log queries: < 3 seconds
- Data export generation: < 30 seconds
- Database backup: < 5 minutes (background)

### Security Testing

Security tests validate protection mechanisms and audit capabilities:

**Access Control Testing**:
- Brute force protection for access codes
- Session hijacking prevention
- SQL injection prevention in all database queries
- Cross-site scripting (XSS) prevention in web interface

**Audit Trail Testing**:
- Tamper detection for audit log entries
- Complete audit coverage for all sensitive operations
- Audit log export integrity and authenticity
- Long-term audit log retention and retrieval

**Data Protection Testing**:
- Encryption validation for sensitive data at rest
- Secure transmission of patient data
- Backup file encryption and key management
- QR code data encryption and decryption security

The comprehensive testing strategy ensures both functional correctness through property-based testing and operational reliability through integration and performance testing, providing confidence in the system's ability to securely manage sensitive medical data while maintaining high availability and performance standards.