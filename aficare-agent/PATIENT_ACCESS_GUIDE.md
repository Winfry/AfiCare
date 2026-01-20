# AfiCare Patient Data Access Guide

## 📊 **Current Patient Data Storage**

### **Database Location:**
```
aficare-agent/aficare.db (SQLite database)
```

### **Database Tables:**
- `patients` - Patient demographics and medical history
- `consultations` - AI consultation results and diagnoses
- `vital_signs_history` - Time-series vital signs data

---

## 🏥 **HOSPITAL-WIDE ACCESS MODEL**

### **How It Works:**

**Current Status:** ❌ No access control (anyone with database file can access)

**Recommended Setup for Hospital:**

### **Option 1: Shared Network Database (Recommended)**

**Setup:**
1. Install AfiCare on a central hospital server
2. All doctors/nurses access via web browser
3. Single shared database - everyone sees all patients
4. Add user login for audit trail

**Advantages:**
- ✅ All staff can access any patient
- ✅ Real-time data sharing
- ✅ Centralized backups
- ✅ Audit trail of who accessed what

**Implementation:**
```bash
# On hospital server
cd aficare-agent
python run.py --mode both --host 0.0.0.0 --api-port 8000 --ui-port 8501

# Doctors access from their computers
http://hospital-server-ip:8501
```

---

### **Option 2: PostgreSQL Central Database**

**For larger hospitals with multiple departments:**

**Setup Steps:**

1. **Install PostgreSQL** on hospital server
```bash
# Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib

# Create database
sudo -u postgres createdb aficare_hospital
sudo -u postgres createuser aficare_user -P
```

2. **Update AfiCare Configuration**

Edit `config/default.yaml`:
```yaml
database:
  url: "postgresql://aficare_user:password@hospital-server:5432/aficare_hospital"
  echo: false
  pool_size: 20
  max_overflow: 40
```

3. **Benefits:**
- ✅ Supports 100+ concurrent users
- ✅ Better performance
- ✅ Advanced backup/restore
- ✅ Hospital-wide patient records
- ✅ Department-level reporting

---

## 👥 **MULTI-USER ACCESS SYSTEM**

### **User Roles:**

| Role | Permissions |
|------|-------------|
| **Doctor** | Full access to all patients, can create/edit consultations |
| **Nurse** | Full access to all patients, can create consultations |
| **Clinical Officer** | Full access to all patients |
| **Admin** | User management, system configuration, reports |
| **Receptionist** | Patient registration only, view basic info |

### **Access Control Rules:**

**Hospital-Wide Access:**
- ✅ All medical staff in same hospital can access ALL patients
- ✅ No patient-specific restrictions
- ✅ Audit log tracks who accessed which patient
- ✅ Cross-hospital referrals require explicit permission

---

## 🔐 **IMPLEMENTING USER AUTHENTICATION**

### **Quick Setup Script:**

Create `setup_users.py`:

```python
import sqlite3
import hashlib
import secrets

def create_hospital_and_users():
    conn = sqlite3.connect('aficare.db')
    cursor = conn.cursor()
    
    # Create hospitals table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS hospitals (
            hospital_id TEXT PRIMARY KEY,
            hospital_name TEXT NOT NULL,
            location TEXT
        )
    ''')
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            full_name TEXT NOT NULL,
            role TEXT NOT NULL,
            hospital_id TEXT NOT NULL,
            is_active BOOLEAN DEFAULT 1,
            FOREIGN KEY (hospital_id) REFERENCES hospitals (hospital_id)
        )
    ''')
    
    # Add your hospital
    cursor.execute('''
        INSERT OR IGNORE INTO hospitals (hospital_id, hospital_name, location)
        VALUES ('HOSP001', 'Nairobi General Hospital', 'Nairobi, Kenya')
    ''')
    
    # Add doctors
    doctors = [
        ('dr_john', 'password123', 'Dr. John Kamau', 'doctor'),
        ('dr_mary', 'password123', 'Dr. Mary Wanjiku', 'doctor'),
        ('nurse_jane', 'password123', 'Nurse Jane Akinyi', 'nurse'),
    ]
    
    for username, password, full_name, role in doctors:
        # Hash password
        salt = secrets.token_hex(16)
        pwd_hash = hashlib.sha256((password + salt).encode()).hexdigest()
        password_hash = f"{salt}${pwd_hash}"
        
        user_id = f"USR-{secrets.token_hex(4).upper()}"
        
        cursor.execute('''
            INSERT OR IGNORE INTO users 
            (user_id, username, password_hash, full_name, role, hospital_id)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (user_id, username, password_hash, full_name, role, 'HOSP001'))
    
    conn.commit()
    conn.close()
    print("✅ Hospital and users created!")
    print("\nLogin credentials:")
    print("Username: dr_john, Password: password123")
    print("Username: dr_mary, Password: password123")
    print("Username: nurse_jane, Password: password123")

if __name__ == "__main__":
    create_hospital_and_users()
```

Run it:
```bash
cd aficare-agent
python setup_users.py
```

---

## 🔍 **PATIENT SEARCH ACROSS HOSPITAL**

### **Search Functionality:**

```python
def search_patients(hospital_id, search_term):
    """Search all patients in hospital"""
    conn = sqlite3.connect('aficare.db')
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT p.id, p.age, p.gender, 
               COUNT(c.id) as consultation_count,
               MAX(c.timestamp) as last_visit
        FROM patients p
        LEFT JOIN consultations c ON p.id = c.patient_id
        WHERE p.id LIKE ? OR p.medical_history LIKE ?
        GROUP BY p.id
        ORDER BY last_visit DESC
    ''', (f'%{search_term}%', f'%{search_term}%'))
    
    return cursor.fetchall()
```

---

## 📱 **ACCESS METHODS**

### **1. Web Interface (Streamlit)**
```
http://hospital-server:8501
- Login with username/password
- Access all patients
- Create consultations
- View history
```

### **2. API Access**
```bash
# Login
curl -X POST http://hospital-server:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"dr_john","password":"password123"}'

# Get patient
curl http://hospital-server:8000/api/patients/AFC-2024-00001 \
  -H "Authorization: Bearer <token>"
```

### **3. Mobile App (Future)**
- Native Android/iOS apps
- Same database access
- Offline sync capability

---

## 🔒 **SECURITY & PRIVACY**

### **Data Protection:**

1. **Encryption at Rest:**
```yaml
# config/default.yaml
security:
  encrypt_database: true
  encryption_key: "your-32-byte-key-here"
```

2. **Access Logging:**
```python
# Every patient access is logged
access_logs table:
- who accessed
- which patient
- when
- what action
- from which IP
```

3. **HIPAA Compliance:**
- ✅ Audit trails
- ✅ User authentication
- ✅ Data encryption
- ✅ Access controls
- ✅ Automatic logout after inactivity

---

## 📊 **VIEWING PATIENT DATA**

### **Any Doctor Can:**

1. **Search for Patient:**
   - By Patient ID
   - By name (if stored)
   - By date of visit

2. **View Complete History:**
   - All past consultations
   - All diagnoses
   - All treatments prescribed
   - Vital signs trends
   - Medical history

3. **Add New Consultation:**
   - System records which doctor added it
   - Timestamp automatically recorded
   - Linked to patient record

4. **View Statistics:**
   - Hospital-wide patient count
   - Department statistics
   - Disease prevalence
   - Treatment outcomes

---

## 🚀 **DEPLOYMENT FOR HOSPITAL**

### **Step-by-Step:**

**1. Server Setup:**
```bash
# Install on Ubuntu server
sudo apt-get update
sudo apt-get install python3 python3-pip postgresql

# Clone AfiCare
git clone <your-repo>
cd aficare-agent

# Install dependencies
pip3 install -r requirements.txt
```

**2. Configure for Network Access:**
```yaml
# config/default.yaml
api:
  host: "0.0.0.0"  # Allow network access
  port: 8000

ui:
  host: "0.0.0.0"
  port: 8501

database:
  url: "postgresql://aficare:password@localhost/aficare_hospital"
```

**3. Start Services:**
```bash
# Run as system service
python3 run.py --mode both
```

**4. Access from Any Computer:**
```
http://192.168.1.100:8501  (replace with server IP)
```

---

## 💡 **BEST PRACTICES**

### **For Hospital-Wide Deployment:**

1. **Single Central Database** ✅
   - One source of truth
   - All doctors see same data
   - Real-time updates

2. **Regular Backups** ✅
   ```bash
   # Daily backup script
   pg_dump aficare_hospital > backup_$(date +%Y%m%d).sql
   ```

3. **User Training** ✅
   - Train all staff on system use
   - Emphasize data privacy
   - Document workflows

4. **Network Security** ✅
   - Use hospital internal network
   - VPN for remote access
   - Firewall rules

5. **Audit Reviews** ✅
   - Monthly review of access logs
   - Identify unusual patterns
   - Ensure compliance

---

## 📞 **SUMMARY**

**Current State:**
- ❌ No access control
- ❌ Local database only
- ❌ No user authentication

**Recommended Setup:**
- ✅ Central server with PostgreSQL
- ✅ User authentication system
- ✅ Hospital-wide access (all doctors can see all patients)
- ✅ Audit logging
- ✅ Web-based access from any computer

**Result:**
- Any doctor in the hospital can access any patient's complete medical history
- System tracks who accessed what for accountability
- Centralized, secure, and compliant with medical data standards

---

**Need Help Setting This Up?**
The user authentication system and PostgreSQL migration can be implemented in about 2-3 days of development work.