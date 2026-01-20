# AfiCare Patient Data Flow & History Management

## 📊 **WHERE PATIENT DATA GOES**

### **Database Location:**
```
File: aficare-agent/aficare.db (SQLite database)
Size: Grows with each patient and consultation
Backup: Automatically backed up (if configured)
```

---

## 🗄️ **DATABASE STRUCTURE**

### **3 Main Tables Store All Patient Information:**

#### **1. PATIENTS Table** (Demographics & Basic Info)
```sql
CREATE TABLE patients (
    id TEXT PRIMARY KEY,              -- "AFC-2024-00001"
    age INTEGER,                      -- 25
    gender TEXT,                      -- "male"/"female"
    weight REAL,                      -- 70.5 kg
    medical_history TEXT,             -- "Diabetes, Hypertension"
    current_medications TEXT,         -- "Metformin 500mg, Lisinopril 10mg"
    allergies TEXT,                   -- "Penicillin, Sulfa drugs"
    created_at TIMESTAMP,             -- When first registered
    updated_at TIMESTAMP              -- Last update
);
```

#### **2. CONSULTATIONS Table** (Every Doctor Visit)
```sql
CREATE TABLE consultations (
    id INTEGER PRIMARY KEY,           -- Auto-increment consultation ID
    patient_id TEXT,                  -- Links to patients table
    timestamp TIMESTAMP,              -- When consultation happened
    chief_complaint TEXT,             -- "Fever and headache for 3 days"
    symptoms TEXT,                    -- JSON: ["fever","headache","chills"]
    vital_signs TEXT,                 -- JSON: {"temperature":39.2,"pulse":95}
    triage_level TEXT,                -- "urgent"/"emergency"/"routine"
    suspected_conditions TEXT,        -- JSON: [{"name":"malaria","confidence":0.85}]
    recommendations TEXT,             -- JSON: ["Take Artemether-Lumefantrine"]
    referral_needed BOOLEAN,          -- true/false
    follow_up_required BOOLEAN,       -- true/false
    confidence_score REAL,            -- 0.85 (85% confidence)
    created_at TIMESTAMP              -- When record was saved
);
```

#### **3. VITAL_SIGNS_HISTORY Table** (Trends Over Time)
```sql
CREATE TABLE vital_signs_history (
    id INTEGER PRIMARY KEY,
    patient_id TEXT,                  -- Links to patients table
    consultation_id INTEGER,          -- Links to consultations table
    temperature REAL,                 -- 39.2°C
    systolic_bp INTEGER,              -- 120 mmHg
    diastolic_bp INTEGER,             -- 80 mmHg
    pulse INTEGER,                    -- 95 bpm
    respiratory_rate INTEGER,         -- 18 /min
    oxygen_saturation REAL,           -- 98%
    recorded_at TIMESTAMP             -- When measured
);
```

---

## 📈 **HOW PATIENT HISTORY WORKS**

### **When a Patient Returns:**

**Scenario:** Patient AFC-2024-00001 comes back after 1 week

**What the Doctor Sees:**

```
PATIENT: AFC-2024-00001 (John Doe, 25M)
═══════════════════════════════════════════

PREVIOUS VISITS:
┌─────────────────────────────────────────────────────────────┐
│ Visit 1: Jan 15, 2024 - Dr. Mary Wanjiku                   │
│ Chief Complaint: "Fever and headache for 3 days"          │
│ Diagnosis: Malaria (85% confidence)                        │
│ Treatment: Artemether-Lumefantrine 3 days                  │
│ Triage: URGENT                                             │
│ Vitals: Temp 39.2°C, BP 120/80, Pulse 95                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Visit 2: Jan 18, 2024 - Dr. John Kamau                    │
│ Chief Complaint: "Still feeling weak"                      │
│ Diagnosis: Malaria recovery (60% confidence)               │
│ Treatment: Continue rest, iron supplements                  │
│ Triage: ROUTINE                                            │
│ Vitals: Temp 37.1°C, BP 118/78, Pulse 82                 │
└─────────────────────────────────────────────────────────────┘

TODAY'S VISIT: Jan 22, 2024
Chief Complaint: "Cough and chest pain"
```

### **What AfiCare AI Considers:**

1. **Previous Diagnoses:** "Patient had malaria 1 week ago"
2. **Treatment History:** "Completed antimalarial treatment"
3. **Vital Signs Trends:** "Temperature normalized, but now has new symptoms"
4. **Risk Factors:** "Recent malaria infection may affect immune system"

**AI Analysis:**
```
🤖 ANALYSIS:
- Previous malaria treatment completed
- New respiratory symptoms suggest different condition
- Consider post-malaria complications vs new infection
- Recommend: Chest examination, possible pneumonia workup
```

---

## 🔍 **PATIENT SEARCH & RETRIEVAL**

### **How Doctors Find Previous Data:**

#### **Method 1: Patient ID Search**
```python
# Doctor enters: "AFC-2024-00001"
patient_history = get_patient_history("AFC-2024-00001")

# Returns:
{
    "patient": {
        "id": "AFC-2024-00001",
        "age": 25,
        "gender": "male",
        "medical_history": ["Diabetes", "Hypertension"],
        "allergies": ["Penicillin"]
    },
    "consultations": [
        {
            "date": "2024-01-15",
            "doctor": "Dr. Mary Wanjiku", 
            "diagnosis": "Malaria",
            "treatment": "Artemether-Lumefantrine"
        },
        {
            "date": "2024-01-18",
            "doctor": "Dr. John Kamau",
            "diagnosis": "Malaria recovery",
            "treatment": "Iron supplements"
        }
    ],
    "vital_trends": {
        "temperature": [39.2, 37.1, 36.8],
        "blood_pressure": ["120/80", "118/78", "115/75"]
    }
}
```

#### **Method 2: Symptom/Condition Search**
```python
# Doctor searches: "patients with malaria last month"
search_results = search_patients(
    hospital_id="HOSP001",
    condition="malaria",
    date_range="last_30_days"
)

# Returns list of patients with malaria diagnoses
```

---

## 💾 **DATA PERSISTENCE & BACKUP**

### **Where Data Is Physically Stored:**

**Local Installation:**
```
📁 aficare-agent/
├── aficare.db                    ← ALL PATIENT DATA HERE
├── backups/
│   ├── aficare_backup_20240115.db
│   ├── aficare_backup_20240116.db
│   └── aficare_backup_20240117.db
└── logs/
    ├── medical_events.log        ← Who accessed what patient
    └── aficare_20240115.log
```

**Hospital Network Installation:**
```
🏥 Hospital Server:
├── /var/lib/aficare/
│   ├── aficare_hospital.db       ← Central database
│   └── backups/
│       ├── daily_backup_20240115.sql
│       └── weekly_backup_20240114.sql
└── /var/log/aficare/
    └── access_logs.log           ← Audit trail
```

---

## 🔄 **DATA FLOW EXAMPLE**

### **Complete Patient Journey:**

#### **Visit 1: New Patient Registration**
```
1. Patient arrives → Receptionist enters basic info
   ↓
2. Data saved to PATIENTS table:
   - ID: AFC-2024-00001
   - Age: 25, Gender: Male
   - Medical History: "None known"
   
3. Doctor consultation → Symptoms entered
   ↓
4. AI Analysis → Diagnosis: Malaria (85%)
   ↓
5. Data saved to CONSULTATIONS table:
   - Patient ID: AFC-2024-00001
   - Symptoms: ["fever", "headache", "chills"]
   - Diagnosis: Malaria
   - Treatment: Artemether-Lumefantrine
   
6. Vital signs saved to VITAL_SIGNS_HISTORY:
   - Temperature: 39.2°C
   - Blood Pressure: 120/80
   - Pulse: 95 bpm
```

#### **Visit 2: Follow-up (1 week later)**
```
1. Patient returns → Doctor searches "AFC-2024-00001"
   ↓
2. System retrieves:
   - Previous diagnosis: Malaria
   - Previous treatment: Artemether-Lumefantrine
   - Previous vitals: Temp 39.2°C → Now 37.1°C
   
3. New consultation → New symptoms entered
   ↓
4. AI considers previous history:
   - "Patient had malaria, now recovered"
   - "New symptoms may be unrelated"
   
5. New consultation record saved
   - Links to same patient ID
   - Shows progression/recovery
```

---

## 📊 **PATIENT HISTORY FEATURES**

### **What Doctors Can See:**

#### **1. Complete Medical Timeline**
```
PATIENT TIMELINE: AFC-2024-00001
═══════════════════════════════════

Jan 15, 2024 │ MALARIA DIAGNOSIS
             │ • Fever 39.2°C, severe headache
             │ • Started Artemether-Lumefantrine
             │ • Triage: URGENT
             │
Jan 18, 2024 │ FOLLOW-UP VISIT  
             │ • Fever resolved (37.1°C)
             │ • Still weak, appetite poor
             │ • Continue treatment
             │
Jan 22, 2024 │ NEW SYMPTOMS
             │ • Cough, chest pain
             │ • Possible pneumonia?
             │ • Investigate further
```

#### **2. Vital Signs Trends**
```
TEMPERATURE TREND:
39.2°C ████████████████████ (Jan 15 - High fever)
37.1°C ████████             (Jan 18 - Improving)
36.8°C ██████               (Jan 22 - Normal)

BLOOD PRESSURE TREND:
120/80 ████████████ (Jan 15)
118/78 ███████████  (Jan 18) 
115/75 ██████████   (Jan 22)
```

#### **3. Treatment Response**
```
MALARIA TREATMENT RESPONSE:
Day 1: Started Artemether-Lumefantrine
Day 3: Fever reduced from 39.2°C to 37.1°C
Day 7: Treatment completed, symptoms resolved
Outcome: ✅ SUCCESSFUL TREATMENT
```

---

## 🔒 **DATA SECURITY & PRIVACY**

### **Who Can Access Patient Data:**

#### **Hospital-Wide Access Model:**
```
✅ Dr. Mary (Pediatrics) → Can see ALL patients
✅ Dr. John (Internal Medicine) → Can see ALL patients  
✅ Nurse Jane (Emergency) → Can see ALL patients
✅ Clinical Officer Peter → Can see ALL patients
❌ Receptionist Sarah → Can only see basic info
❌ External users → No access
```

#### **Audit Trail:**
```
ACCESS LOG:
2024-01-22 09:15 │ Dr. John Kamau │ VIEWED │ Patient AFC-2024-00001
2024-01-22 09:20 │ Dr. John Kamau │ ADDED  │ New consultation
2024-01-22 09:25 │ Nurse Jane     │ VIEWED │ Patient AFC-2024-00001
2024-01-22 10:30 │ Dr. Mary       │ VIEWED │ Patient AFC-2024-00001
```

---

## 💡 **KEY BENEFITS OF THIS SYSTEM**

### **For Doctors:**
✅ **Complete Patient History** - See every previous visit  
✅ **Treatment Tracking** - Know what worked/didn't work  
✅ **Vital Signs Trends** - Spot patterns and improvements  
✅ **Drug Allergy Alerts** - Avoid dangerous medications  
✅ **Continuity of Care** - Pick up where last doctor left off  

### **For Patients:**
✅ **No Lost Records** - History preserved forever  
✅ **Better Diagnoses** - AI considers full medical history  
✅ **Safer Treatment** - System remembers allergies/reactions  
✅ **Faster Service** - No need to repeat medical history  

### **For Hospital:**
✅ **Quality Metrics** - Track treatment outcomes  
✅ **Disease Surveillance** - Monitor outbreaks  
✅ **Resource Planning** - Predict medication needs  
✅ **Compliance** - Meet medical record requirements  

---

## 🚀 **SUMMARY**

**Patient data in AfiCare:**

1. **Stored permanently** in SQLite database (aficare.db)
2. **Linked by Patient ID** - all visits connected
3. **Accessible hospital-wide** - any doctor can see any patient
4. **Includes complete history** - symptoms, diagnoses, treatments, vitals
5. **Tracks trends over time** - vital signs, treatment responses
6. **Audit logged** - who accessed what when
7. **Backed up regularly** - data protection
8. **Searchable** - find patients by ID, condition, date

**Result:** Every time a patient returns, doctors have their complete medical history instantly available, leading to better diagnoses and continuity of care!

The system essentially creates a **digital medical record** that follows the patient throughout their healthcare journey at your hospital.