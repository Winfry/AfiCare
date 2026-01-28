#!/usr/bin/env python3
"""
AfiCare MediLink - Fix Database Schema and Add Sample Data
Matches the existing database structure exactly
"""

import sqlite3
import json
from datetime import datetime
import os

def fix_and_populate_database():
    """Fix database schema and add sample data"""
    
    db_path = 'aficare.db'
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("🔧 Fixing database schema...")
    
    # Add missing columns to patients table
    missing_columns = [
        ('medilink_id', 'TEXT'),
        ('full_name', 'TEXT'),
        ('phone', 'TEXT'),
        ('email', 'TEXT'),
        ('emergency_contact', 'TEXT'),
        ('location', 'TEXT')
    ]
    
    for column_name, column_type in missing_columns:
        try:
            cursor.execute(f"ALTER TABLE patients ADD COLUMN {column_name} {column_type}")
            print(f"✅ Added {column_name} column to patients table")
        except sqlite3.OperationalError:
            print(f"ℹ️ Column {column_name} already exists")
    
    # Add missing columns to consultations table
    consultation_columns = [
        ('doctor_name', 'TEXT'),
        ('diagnosis', 'TEXT'),
        ('treatment_plan', 'TEXT'),
        ('chief_complaint', 'TEXT')
    ]
    
    for column_name, column_type in consultation_columns:
        try:
            cursor.execute(f"ALTER TABLE consultations ADD COLUMN {column_name} {column_type}")
            print(f"✅ Added {column_name} column to consultations table")
        except sqlite3.OperationalError:
            print(f"ℹ️ Column {column_name} already exists")
    
    # Add missing columns to vital_signs_history table
    try:
        cursor.execute("ALTER TABLE vital_signs_history ADD COLUMN blood_pressure TEXT")
        print("✅ Added blood_pressure column to vital_signs_history table")
    except sqlite3.OperationalError:
        print("ℹ️ Column blood_pressure already exists")
    
    print("\n📊 Adding sample data...")
    
    # Sample patients - matching all 15 columns exactly
    patients_data = [
        # (id, age, gender, weight, medical_history, current_medications, allergies, created_at, updated_at, medilink_id, full_name, phone, email, emergency_contact, location)
        ('ML-NBO-A1B2C3', 35, 'Male', 75.5, 'Hypertension, Type 2 Diabetes', 'Metformin, Amlodipine', 'Penicillin', '2024-02-10 08:00:00', '2024-02-10 08:00:00', 'ML-NBO-A1B2C3', 'John Doe Kamau', '+254712345678', 'john.kamau@example.com', 'Mary Kamau - +254712345679', 'Nairobi'),
        ('ML-MSA-D4E5F6', 28, 'Female', 62.0, 'Asthma', 'Salbutamol inhaler', 'Sulfa drugs', '2024-02-10 08:00:00', '2024-02-10 08:00:00', 'ML-MSA-D4E5F6', 'Aisha Mohammed Ali', '+254723456789', 'aisha.ali@example.com', 'Omar Ali - +254723456790', 'Mombasa'),
        ('ML-KSM-G7H8I9', 42, 'Male', 80.2, 'None', 'None', 'None', '2024-02-10 08:00:00', '2024-02-10 08:00:00', 'ML-KSM-G7H8I9', 'Peter Ochieng Otieno', '+254734567890', 'peter.otieno@example.com', 'Grace Otieno - +254734567891', 'Kisumu'),
        ('ML-NBO-J1K2L3', 31, 'Female', 68.5, 'Pregnancy (32 weeks)', 'Prenatal vitamins', 'None', '2024-02-10 08:00:00', '2024-02-10 08:00:00', 'ML-NBO-J1K2L3', 'Sarah Wanjiku Mwangi', '+254745678901', 'sarah.mwangi@example.com', 'David Mwangi - +254745678902', 'Nairobi'),
        ('ML-ELD-M4N5O6', 67, 'Male', 72.8, 'Hypertension, Arthritis', 'Amlodipine, Ibuprofen', 'Aspirin', '2024-02-10 08:00:00', '2024-02-10 08:00:00', 'ML-ELD-M4N5O6', 'James Kipchoge Ruto', '+254756789012', 'james.ruto@example.com', 'Rose Ruto - +254756789013', 'Eldoret'),
        ('ML-NBO-DEMO1', 30, 'Male', 70.0, 'None', 'None', 'None', '2024-02-10 08:00:00', '2024-02-10 08:00:00', 'ML-NBO-DEMO1', 'Demo Patient', '+254700000000', 'demo@aficare.com', 'Demo Contact - +254700000001', 'Nairobi')
    ]
    
    # Insert patients with all 15 columns
    for patient in patients_data:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO patients 
                (id, age, gender, weight, medical_history, current_medications, allergies, 
                 created_at, updated_at, medilink_id, full_name, phone, email, emergency_contact, location)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', patient)
            print(f"✅ Added patient: {patient[10]} ({patient[9]})")  # full_name (medilink_id)
        except Exception as e:
            print(f"❌ Error adding patient {patient[10]}: {e}")
    
    # Sample consultations
    consultations_data = [
        ('ML-NBO-A1B2C3', '2024-02-10 09:30:00', 'Fever and body aches for 3 days', 
         json.dumps(['fever', 'headache', 'muscle aches', 'chills']),
         json.dumps({'temperature': 38.5, 'systolic_bp': 140, 'diastolic_bp': 90, 'pulse': 95, 'respiratory_rate': 18}),
         'URGENT', json.dumps(['Malaria', 'Viral fever']),
         json.dumps(['Artemether-Lumefantrine', 'Paracetamol', 'ORS', 'Rest']),
         False, True, 0.85, 'Dr. Mary Wanjiku', 'Malaria (suspected)', 'Artemether-Lumefantrine 20/120mg twice daily for 3 days'),
        
        ('ML-MSA-D4E5F6', '2024-02-12 14:15:00', 'Difficulty breathing and chest tightness',
         json.dumps(['cough', 'difficulty breathing', 'chest tightness', 'wheezing']),
         json.dumps({'temperature': 37.2, 'systolic_bp': 120, 'diastolic_bp': 80, 'pulse': 88, 'respiratory_rate': 22}),
         'LESS_URGENT', json.dumps(['Asthma exacerbation']),
         json.dumps(['Salbutamol inhaler', 'Prednisolone', 'Avoid triggers']),
         False, True, 0.92, 'Dr. Ahmed Hassan', 'Asthma exacerbation', 'Salbutamol inhaler 2 puffs every 4-6 hours'),
        
        ('ML-KSM-G7H8I9', '2024-02-14 10:45:00', 'Persistent cough with fever',
         json.dumps(['cough', 'fever', 'chest pain', 'difficulty breathing']),
         json.dumps({'temperature': 39.1, 'systolic_bp': 130, 'diastolic_bp': 85, 'pulse': 102, 'respiratory_rate': 24}),
         'URGENT', json.dumps(['Pneumonia', 'Respiratory infection']),
         json.dumps(['Amoxicillin', 'Paracetamol', 'Fluid intake', 'Rest']),
         False, True, 0.88, 'Dr. Grace Nyong', 'Community-acquired pneumonia', 'Amoxicillin 500mg three times daily for 7 days'),
        
        ('ML-NBO-DEMO1', '2024-02-17 10:00:00', 'Common cold symptoms',
         json.dumps(['runny nose', 'sore throat', 'mild cough']),
         json.dumps({'temperature': 37.3, 'systolic_bp': 120, 'diastolic_bp': 80, 'pulse': 75, 'respiratory_rate': 16}),
         'NON_URGENT', json.dumps(['Common cold']),
         json.dumps(['Rest', 'Fluids', 'Paracetamol', 'Gargling']),
         False, False, 0.90, 'Dr. Demo Doctor', 'Common cold', 'Rest and adequate sleep, increase fluid intake')
    ]
    
    # Insert consultations
    for consultation in consultations_data:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO consultations 
                (patient_id, timestamp, chief_complaint, symptoms, vital_signs, 
                 triage_level, suspected_conditions, recommendations, referral_needed, 
                 follow_up_required, confidence_score, doctor_name, diagnosis, treatment_plan)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', consultation)
            print(f"✅ Added consultation for patient {consultation[0]}")
        except Exception as e:
            print(f"❌ Error adding consultation: {e}")
    
    # Add vital signs history
    vital_signs_data = [
        ('ML-NBO-A1B2C3', 1, 38.5, 140, 90, 95, 18, 98.0, '140/90', '2024-02-10 09:30:00'),
        ('ML-MSA-D4E5F6', 2, 37.2, 120, 80, 88, 22, 96.0, '120/80', '2024-02-12 14:15:00'),
        ('ML-KSM-G7H8I9', 3, 39.1, 130, 85, 102, 24, 94.0, '130/85', '2024-02-14 10:45:00'),
        ('ML-NBO-DEMO1', 4, 37.3, 120, 80, 75, 16, 99.0, '120/80', '2024-02-17 10:00:00')
    ]
    
    for vital in vital_signs_data:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO vital_signs_history 
                (patient_id, consultation_id, temperature, systolic_bp, diastolic_bp, 
                 pulse, respiratory_rate, oxygen_saturation, blood_pressure, recorded_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', vital)
            print(f"✅ Added vital signs for patient {vital[0]}")
        except Exception as e:
            print(f"❌ Error adding vital signs: {e}")
    
    conn.commit()
    conn.close()
    
    print("\n" + "="*50)
    print("✅ Database fixed and sample data added successfully!")
    print("📊 Database now contains:")
    
    # Verify data
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM patients")
    patient_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM consultations")
    consultation_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM vital_signs_history")
    vitals_count = cursor.fetchone()[0]
    
    print(f"   • {patient_count} patients with MediLink IDs")
    print(f"   • {consultation_count} consultations with AI diagnoses")
    print(f"   • {vitals_count} vital signs records")
    
    # Show sample data
    print("\n🎯 Sample Patients:")
    cursor.execute("SELECT medilink_id, full_name, age, gender FROM patients LIMIT 3")
    for row in cursor.fetchall():
        print(f"   • {row[0]} - {row[1]} ({row[2]}y, {row[3]})")
    
    print("\n🏥 Sample Consultations:")
    cursor.execute("SELECT patient_id, doctor_name, diagnosis FROM consultations LIMIT 3")
    for row in cursor.fetchall():
        print(f"   • {row[0]} - {row[1]} - {row[2]}")
    
    conn.close()
    
    print("\n🌐 Your app now has data from day one!")
    print("🚀 Ready for testing and deployment!")
    print("="*50)

if __name__ == "__main__":
    print("🏥 AfiCare MediLink - Database Fix & Sample Data")
    print("=" * 50)
    
    try:
        fix_and_populate_database()
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)