#!/usr/bin/env python3
"""
AfiCare MediLink - Comprehensive Feature Test
Test all PWA features systematically
"""

import requests
import time
import webbrowser
import json
from pathlib import Path

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def print_test(test_name, status="TESTING"):
    if status == "TESTING":
        print(f"🧪 {test_name}...")
    elif status == "PASS":
        print(f"✅ {test_name} - PASSED")
    elif status == "FAIL":
        print(f"❌ {test_name} - FAILED")
    elif status == "SKIP":
        print(f"⏭️  {test_name} - SKIPPED")

def test_pwa_accessibility():
    """Test if PWA is accessible"""
    print_test("PWA Accessibility Check")
    
    ports_to_test = [8503, 8502, 8504, 8505]
    
    for port in ports_to_test:
        try:
            url = f"http://localhost:{port}"
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                if "AfiCare" in response.text or "MediLink" in response.text:
                    print_test(f"PWA running on {url}", "PASS")
                    return url
                    
        except requests.exceptions.RequestException:
            continue
    
    print_test("PWA Accessibility", "FAIL")
    return None

def test_qr_code_generation():
    """Test QR code functionality"""
    print_test("QR Code Generation")
    
    try:
        import qrcode
        from io import BytesIO
        import base64
        
        # Test QR code creation
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data("Test QR Code for AfiCare")
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        img_buffer = BytesIO()
        img.save(img_buffer, format='PNG')
        img_b64 = base64.b64encode(img_buffer.getvalue()).decode()
        
        if len(img_b64) > 100:  # Valid base64 image should be substantial
            print_test("QR Code Generation", "PASS")
            return True
        else:
            print_test("QR Code Generation", "FAIL")
            return False
            
    except Exception as e:
        print(f"   Error: {e}")
        print_test("QR Code Generation", "FAIL")
        return False

def test_ai_agent_import():
    """Test AI agent imports"""
    print_test("AI Agent Import")
    
    try:
        import sys
        sys.path.insert(0, 'src')
        
        from core.agent import AfiCareAgent
        print_test("Core AI Agent Import", "PASS")
        
        try:
            from ai.hybrid_medical_agent import HybridMedicalAgent
            print_test("Hybrid AI Agent Import", "PASS")
        except ImportError:
            print_test("Hybrid AI Agent Import", "SKIP")
        
        try:
            from core.langchain_agent import create_medical_agent
            print_test("LangChain Agent Import", "PASS")
        except ImportError:
            print_test("LangChain Agent Import", "SKIP")
        
        return True
        
    except Exception as e:
        print(f"   Error: {e}")
        print_test("AI Agent Import", "FAIL")
        return False

def test_database_connectivity():
    """Test database functionality"""
    print_test("Database Connectivity")
    
    try:
        import sqlite3
        
        # Check if database files exist
        db_files = ["aficare.db", "aficare_enhanced.db", "aficare_medilink.db"]
        found_db = False
        
        for db_file in db_files:
            if Path(db_file).exists():
                print(f"   Found database: {db_file}")
                found_db = True
                
                # Test connection
                conn = sqlite3.connect(db_file)
                cursor = conn.cursor()
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
                tables = cursor.fetchall()
                conn.close()
                
                if tables:
                    print(f"   Tables in {db_file}: {len(tables)}")
        
        if found_db:
            print_test("Database Connectivity", "PASS")
            return True
        else:
            print_test("Database Connectivity", "FAIL")
            return False
            
    except Exception as e:
        print(f"   Error: {e}")
        print_test("Database Connectivity", "FAIL")
        return False

def show_manual_test_guide(url):
    """Show manual testing guide"""
    print_header("🎯 Manual Testing Guide")
    
    print(f"🌐 Your PWA is running at: {url}")
    print()
    print("📋 **COMPLETE TESTING CHECKLIST**")
    print()
    
    print("1. **LOGIN TESTS** ✅")
    print("   👤 Patient Login:")
    print("      Email: patient@demo.com")
    print("      Password: demo123")
    print("      Expected: Access to Health Records, QR Sharing")
    print()
    print("   👨‍⚕️ Doctor Login:")
    print("      Email: doctor@demo.com") 
    print("      Password: demo123")
    print("      Expected: Patient Access, AI Agent Demo")
    print()
    print("   👨‍💼 Admin Login:")
    print("      Email: admin@demo.com")
    print("      Password: demo123")
    print("      Expected: User Management, System Analytics")
    print()
    
    print("2. **QR CODE TESTS** 📱")
    print("   • Login as patient")
    print("   • Go to 'Health Records' tab")
    print("   • Click '📱 Generate QR Code'")
    print("   • Select QR type (Emergency Access, Full Records, etc.)")
    print("   • Click 'Generate QR Code' button")
    print("   • ✅ EXPECTED: Actual QR code image appears")
    print("   • ❌ FAILURE: 'Install qrcode library' message")
    print()
    
    print("3. **AI CONSULTATION TESTS** 🤖")
    print("   • Login as doctor")
    print("   • Go to 'AI Agent Demo' tab")
    print("   • Enter patient symptoms:")
    print("     - fever, headache, chills (should suggest malaria)")
    print("     - cough, fever, difficulty breathing (should suggest pneumonia)")
    print("   • ✅ EXPECTED: Diagnosis with confidence score")
    print("   • ✅ EXPECTED: Treatment recommendations")
    print("   • ✅ EXPECTED: Triage level (URGENT, NON_URGENT, etc.)")
    print()
    
    print("4. **MOBILE PWA TESTS** 📱")
    print("   • Look for '📱 Install App' button (should appear)")
    print("   • Test mobile responsiveness (resize browser)")
    print("   • Check touch-friendly buttons")
    print("   • Test offline capability (disconnect internet)")
    print()
    
    print("5. **PATIENT RECORDS TESTS** 📋")
    print("   • Login as patient")
    print("   • Check 'Health Summary' with AI health score")
    print("   • View 'Visit History' with past consultations")
    print("   • Test 'Maternal Health' features (if female patient)")
    print("   • Check 'Medication Management'")
    print()
    
    print("6. **SECURITY TESTS** 🔒")
    print("   • Try accessing patient data without login")
    print("   • Test session timeout")
    print("   • Verify encrypted data storage")
    print("   • Test access code expiration")
    print()
    
    print("🎯 **SUCCESS CRITERIA:**")
    print("   ✅ All demo accounts work")
    print("   ✅ QR codes generate (no error messages)")
    print("   ✅ AI gives medical diagnoses")
    print("   ✅ PWA install button appears")
    print("   ✅ Mobile-responsive interface")
    print("   ✅ No raw HTML/CSS display")

def main():
    print("🏥 AfiCare MediLink - Comprehensive Feature Test")
    print("   Testing all PWA features systematically")
    
    # Automated tests
    print_header("🤖 Automated Tests")
    
    url = test_pwa_accessibility()
    if not url:
        print("\n❌ PWA not accessible. Start it first:")
        print("   python start_phone_app.py")
        return
    
    qr_ok = test_qr_code_generation()
    ai_ok = test_ai_agent_import()
    db_ok = test_database_connectivity()
    
    # Summary of automated tests
    print_header("📊 Automated Test Results")
    print(f"✅ PWA Accessibility: PASSED ({url})")
    print(f"{'✅' if qr_ok else '❌'} QR Code Generation: {'PASSED' if qr_ok else 'FAILED'}")
    print(f"{'✅' if ai_ok else '❌'} AI Agent Import: {'PASSED' if ai_ok else 'FAILED'}")
    print(f"{'✅' if db_ok else '❌'} Database Connectivity: {'PASSED' if db_ok else 'FAILED'}")
    
    # Open browser for manual testing
    print(f"\n🌐 Opening {url} for manual testing...")
    webbrowser.open(url)
    
    # Show manual testing guide
    show_manual_test_guide(url)
    
    print("\n" + "="*60)
    print("🎯 **NEXT STEPS:**")
    print("1. Complete the manual tests above")
    print("2. Verify all features work as expected")
    print("3. When satisfied, proceed with Flutter setup")
    print("4. Run: python setup_flutter_here.py")
    print("="*60)
    
    input("\nPress Enter when you've completed manual testing...")
    
    print("\n✅ PWA testing complete!")
    print("🚀 Ready for Flutter setup!")

if __name__ == "__main__":
    main()