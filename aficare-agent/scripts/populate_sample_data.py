#!/usr/bin/env python3
"""
AfiCare MediLink - Sample Data Population
Creates realistic sample data for immediate testing and demo
"""

import sqlite3
import json
from datetime import datetime, timedelta
import os

def create_sample_data():
    """Create realistic sample data for AfiCare MediLink"""
    
    # Ensure we're in the right directory
    db_path = 'aficare.db'
    if not os.path.exists(db_path):
        print(f"❌ Database not found at {db_path}")
        print("🔄 Creating new database...")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # First, let's check and update the existing schema to add missing columns
    
    # Add missing columns to patients table
    try:
        cursor.execute("ALTER TABLE patients ADD COLUMN medilink_id TEXT")
        print("✅ Added medilink_id column to patients table")
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    try:
        cursor.execute("ALTER TABLE patients ADD COLUMN full_name TEXT")
        print("✅ Added full_name column to patients table")
    except sqlite3.OperationalError:
        pass
    
    try:
        cursor.execute("ALTER TABLE patients ADD COLUMN phone TEXT")
        print("✅ Added phone column to patients table")
    except sqlite3.OperationalError:
        pass
    
    try:
        cursor.execute("ALTER TABLE patients ADD COLUMN email TEXT")
        print("✅ Added email column to patients table")
    except sqlite3.OperationalError:
        pass
    
    try:
        cursor.execute("ALTER TABLE patients ADD COLUMN emergency_contact TEXT")
        print("✅ Added emergency_contact column to patients table")
    except sqlite3.OperationalError:
        pass
    
    try:
        cursor.execute("ALTER TABLE patients ADD COLUMN location TEXT")
        print("✅ Added location column to patients table")
    except sqlite3.OperationalError:
        pass
    
    # Add missing columns to consultations table
    try:
        cursor.execute("ALTER TABLE consultations ADD COLUMN doctor_name TEXT")
        print("✅ Added doctor_name column to consultations table")
    except sqlite3.OperationalError:
        pass
    
    try:
        cursor.execute("ALTER TABLE consultations ADD COLUMN diagnosis TEXT")
        print("✅ Added diagnosis column to consultations table")
    except sqlite3.OperationalError:
        pass
    
    try:
        cursor.execute("ALTER TABLE consultations ADD COLUMN treatment_plan TEXT")
        print("✅ Added treatment_plan column to consultations table")
    except sqlite3.OperationalError:
        pass
    
    # Add missing columns to vital_signs_history table
    try:
        cursor.execute("ALTER TABLE vital_signs_history ADD COLUMN blood_pressure TEXT")
        print("✅ Added blood_pressure column to vital_signs_history table")
    except sqlite3.OperationalError:
        pass
    
    # Sample patients with MediLink IDs (matching existing schema)
    sample_patients = [
        {
            'id': 'ML-NBO-A1B2C3',  # Using existing 'id' column as TEXT
            'medilink_id': 'ML-NBO-A1B2C3',
            'full_name': 'John Doe Kamau',
            'age': 35,
            'gender': 'Male',
            'phone': '+254712345678',
            'email': 'john.kamau@example.com',
            'medical_history': 'Hypertension, Type 2 Diabetes',
            'allergies': 'Penicillin',
            'emergency_contact': 'Mary Kamau - +254712345679',
            'location': 'Nairobi',
            'weight': 75.5,
            'current_medications': 'Metformin 500mg, Amlodipine 5mg'
        },
        {
            'id': 'ML-MSA-D4E5F6',
            'medilink_id': 'ML-MSA-D4E5F6',
            'full_name': 'Aisha Mohammed Ali',
            'age': 28,
            'gender': 'Female',
            'phone': '+254723456789',
            'email': 'aisha.ali@example.com',
            'medical_history': 'Asthma',
            'allergies': 'Sulfa drugs',
            'emergency_contact': 'Omar Ali - +254723456790',
            'location': 'Mombasa',
            'weight': 62.0,
            'current_medications': 'Salbutamol inhaler'
        },
        {
            'id': 'ML-KSM-G7H8I9',
            'medilink_id': 'ML-KSM-G7H8I9',
            'full_name': 'Peter Ochieng Otieno',
            'age': 42,
            'gender': 'Male',
            'phone': '+254734567890',
            'email': 'peter.otieno@example.com',
            'medical_history': 'None',
            'allergies': 'None',
            'emergency_contact': 'Grace Otieno - +254734567891',
            'location': 'Kisumu',
            'weight': 80.2,
            'current_medications': 'None'
        },
        {
            'id': 'ML-NBO-J1K2L3',
            'medilink_id': 'ML-NBO-J1K2L3',
            'full_name': 'Sarah Wanjiku Mwangi',
            'age': 31,
            'gender': 'Female',
            'phone': '+254745678901',
            'email': 'sarah.mwangi@example.com',
            'medical_history': 'Pregnancy (32 weeks)',
            'allergies': 'None',
            'emergency_contact': 'David Mwangi - +254745678902',
            'location': 'Nairobi',
            'weight': 68.5,
            'current_medications': 'Prenatal vitamins, Iron supplements'
        },
        {
            'id': 'ML-ELD-M4N5O6',
            'medilink_id': 'ML-ELD-M4N5O6',
            'full_name': 'James Kipchoge Ruto',
            'age': 67,
            'gender': 'Male',
            'phone': '+254756789012',
            'email': 'james.ruto@example.com',
            'medical_history': 'Hypertension, Arthritis',
            'allergies': 'Aspirin',
            'emergency_contact': 'Rose Ruto - +254756789013',
            'location': 'Eldoret',
            'weight': 72.8,
            'current_medications': 'Amlodipine 5mg, Ibuprofen 400mg'
        },
        {
            'id': 'ML-NBO-DEMO1',
            'medilink_id': 'ML-NBO-DEMO1',
            'full_name': 'Demo Patient',
            'age': 30,
            'gender': 'Male',
            'phone': '+254700000000',
            'email': 'demo@aficare.com',
            'medical_history': 'None',
            'allergies': 'None',
            'emergency_contact': 'Demo Contact - +254700000001',
            'location': 'Nairobi',
            'weight': 70.0,
            'current_medications': 'None'
        }
    ]
    
    # Insert patients using the existing schema
    for patient in sample_patients:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO patients 
                (id, age, gender, weight, medical_history, current_medications, allergies,
                 medilink_id, full_name, phone, email, emergency_contact, location)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                patient['id'], patient['age'], patient['gender'], patient['weight'],
                patient['medical_history'], patient['current_medications'], patient['allergies'],
                patient['medilink_id'], patient['full_name'], patient['phone'], 
                patient['email'], patient['emergency_contact'], patient['location']
            ))
            print(f"✅ Added patient: {patient['full_name']} ({patient['medilink_id']})")
        except Exception as e:
            print(f"❌ Error adding patient {patient['full_name']}: {e}")
    
    # Sample consultations
    sample_consultations = [
        {
            'patient_id': 1,  # John Doe
            'doctor_name': 'Dr. Mary Wanjiku',
            'symptoms': json.dumps(['fever', 'headache', 'muscle aches', 'chills']),
            'vital_signs': json.dumps({
                'temperature': 38.5,
                'systolic_bp': 140,
                'diastolic_bp': 90,
                'pulse': 95,
                'respiratory_rate': 18
            }),
            'diagnosis': 'Malaria (suspected based on symptoms and fever pattern)',
            'treatment_plan': 'Artemether-Lumefantrine 20/120mg twice daily for 3 days, Paracetamol 500mg every 6 hours for fever, ORS for hydration, Rest and follow-up in 3 days',
            'triage_level': 'URGENT',
            'consultation_date': '2024-02-10 09:30:00',
            'follow_up_required': 1
        },
        {
            'patient_id': 2,  # Aisha Mohammed
            'doctor_name': 'Dr. Ahmed Hassan',
            'symptoms': json.dumps(['cough', 'difficulty breathing', 'chest tightness', 'wheezing']),
            'vital_signs': json.dumps({
                'temperature': 37.2,
                'systolic_bp': 120,
                'diastolic_bp': 80,
                'pulse': 88,
                'respiratory_rate': 22
            }),
            'diagnosis': 'Asthma exacerbation (mild to moderate)',
            'treatment_plan': 'Salbutamol inhaler 2 puffs every 4-6 hours as needed, Prednisolone 30mg daily for 5 days, Avoid triggers, Follow-up in 1 week',
            'triage_level': 'LESS_URGENT',
            'consultation_date': '2024-02-12 14:15:00',
            'follow_up_required': 1
        },
        {
            'patient_id': 3,  # Peter Ochieng
            'doctor_name': 'Dr. Grace Nyong',
            'symptoms': json.dumps(['cough', 'fever', 'chest pain', 'difficulty breathing']),
            'vital_signs': json.dumps({
                'temperature': 39.1,
                'systolic_bp': 130,
                'diastolic_bp': 85,
                'pulse': 102,
                'respiratory_rate': 24
            }),
            'diagnosis': 'Community-acquired pneumonia (right lower lobe)',
            'treatment_plan': 'Amoxicillin 500mg three times daily for 7 days, Paracetamol for fever and pain, Adequate fluid intake, Rest, Follow-up in 3 days or if symptoms worsen',
            'triage_level': 'URGENT',
            'consultation_date': '2024-02-14 10:45:00',
            'follow_up_required': 1
        },
        {
            'patient_id': 4,  # Sarah Wanjiku (Pregnant)
            'doctor_name': 'Dr. Elizabeth Muthoni',
            'symptoms': json.dumps(['nausea', 'fatigue', 'back pain', 'swollen feet']),
            'vital_signs': json.dumps({
                'temperature': 37.0,
                'systolic_bp': 110,
                'diastolic_bp': 70,
                'pulse': 78,
                'respiratory_rate': 16
            }),
            'diagnosis': 'Normal pregnancy symptoms at 32 weeks gestation',
            'treatment_plan': 'Prenatal vitamins daily, Iron supplements, Adequate rest, Regular antenatal checkups, Monitor blood pressure, Next visit in 2 weeks',
            'triage_level': 'NON_URGENT',
            'consultation_date': '2024-02-15 11:30:00',
            'follow_up_required': 1
        },
        {
            'patient_id': 5,  # James Kipchoge
            'doctor_name': 'Dr. Samuel Kiprotich',
            'symptoms': json.dumps(['joint pain', 'morning stiffness', 'headache']),
            'vital_signs': json.dumps({
                'temperature': 37.1,
                'systolic_bp': 150,
                'diastolic_bp': 95,
                'pulse': 82,
                'respiratory_rate': 16
            }),
            'diagnosis': 'Hypertension (uncontrolled) and Osteoarthritis flare-up',
            'treatment_plan': 'Amlodipine 5mg daily for blood pressure, Ibuprofen 400mg twice daily for joint pain (short term), Low salt diet, Regular exercise, Monitor BP weekly',
            'triage_level': 'LESS_URGENT',
            'consultation_date': '2024-02-16 15:20:00',
            'follow_up_required': 1
        },
        {
            'patient_id': 6,  # Demo Patient
            'doctor_name': 'Dr. Demo Doctor',
            'symptoms': json.dumps(['runny nose', 'sore throat', 'mild cough']),
            'vital_signs': json.dumps({
                'temperature': 37.3,
                'systolic_bp': 120,
                'diastolic_bp': 80,
                'pulse': 75,
                'respiratory_rate': 16
            }),
            'diagnosis': 'Common cold (viral upper respiratory infection)',
            'treatment_plan': 'Rest and adequate sleep, Increase fluid intake, Paracetamol for comfort, Warm salt water gargling, Return if symptoms worsen or persist beyond 7 days',
            'triage_level': 'NON_URGENT',
            'consultation_date': '2024-02-17 10:00:00',
            'follow_up_required': 0
        }
    ]
    
    # Insert consultations
    for consultation in sample_consultations:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO consultations 
                (patient_id, doctor_name, symptoms, vital_signs, diagnosis, 
                 treatment_plan, triage_level, consultation_date, follow_up_required)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                consultation['patient_id'], consultation['doctor_name'],
                consultation['symptoms'], consultation['vital_signs'],
                consultation['diagnosis'], consultation['treatment_plan'],
                consultation['triage_level'], consultation['consultation_date'],
                consultation['follow_up_required']
            ))
            print(f"✅ Added consultation for patient ID {consultation['patient_id']}")
        except Exception as e:
            print(f"❌ Error adding consultation: {e}")
    
    # Add some vital signs history
    vital_signs_data = [
        (1, 38.5, '140/90', 95, 18, '2024-02-10 09:30:00'),
        (2, 37.2, '120/80', 88, 22, '2024-02-12 14:15:00'),
        (3, 39.1, '130/85', 102, 24, '2024-02-14 10:45:00'),
        (4, 37.0, '110/70', 78, 16, '2024-02-15 11:30:00'),
        (5, 37.1, '150/95', 82, 16, '2024-02-16 15:20:00'),
        (6, 37.3, '120/80', 75, 16, '2024-02-17 10:00:00'),
    ]
    
    for vital in vital_signs_data:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO vital_signs_history 
                (patient_id, temperature, blood_pressure, pulse, respiratory_rate, recorded_at)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', vital)
        except Exception as e:
            print(f"❌ Error adding vital signs: {e}")
    
    conn.commit()
    conn.close()
    
    print("\n" + "="*50)
    print("✅ Sample data created successfully!")
    print("📊 Database populated with:")
    print("   • 6 patients with realistic MediLink IDs")
    print("   • 6 consultations with medical AI diagnoses")
    print("   • 6 vital signs records")
    print("   • Complete medical histories and treatments")
    print("\n🎯 Ready for testing and demo!")
    print("🌐 Your app now has data from day one!")
    print("="*50)

def verify_data():
    """Verify that data was created successfully"""
    try:
        conn = sqlite3.connect('aficare.db')
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM patients")
        patient_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM consultations")
        consultation_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM vital_signs_history")
        vitals_count = cursor.fetchone()[0]
        
        conn.close()
        
        print(f"\n📊 Data Verification:")
        print(f"   • Patients: {patient_count}")
        print(f"   • Consultations: {consultation_count}")
        print(f"   • Vital Signs: {vitals_count}")
        
        if patient_count > 0 and consultation_count > 0:
            print("✅ Database is ready for production!")
            return True
        else:
            print("❌ Database appears to be empty")
            return False
            
    except Exception as e:
        print(f"❌ Error verifying data: {e}")
        return False

if __name__ == "__main__":
    print("🏥 AfiCare MediLink - Sample Data Population")
    print("=" * 50)
    
    try:
        create_sample_data()
        verify_data()
    except Exception as e:
        print(f"❌ Error creating sample data: {e}")
        exit(1)