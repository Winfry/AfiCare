#!/usr/bin/env python3
"""
AfiCare MediLink - Quick Start and Test
Start PWA and run comprehensive tests
"""

import subprocess
import sys
import time
import webbrowser
import requests
from pathlib import Path
import socket

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def kill_streamlit_processes():
    """Kill any existing Streamlit processes"""
    print("🔧 Stopping any existing Streamlit processes...")
    
    try:
        # Windows - kill streamlit processes
        subprocess.run(["taskkill", "/F", "/IM", "streamlit.exe"], 
                      capture_output=True, text=True, check=False)
        subprocess.run(["taskkill", "/F", "/IM", "python.exe", "/FI", "WINDOWTITLE eq streamlit*"], 
                      capture_output=True, text=True, check=False)
        print("✅ Cleared existing processes")
        time.sleep(2)
    except:
        print("ℹ️  No processes to clear")

def find_free_port():
    """Find a free port to use"""
    ports_to_try = [8503, 8502, 8504, 8505, 8506]
    
    for port in ports_to_try:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                print(f"✅ Port {port} is available")
                return port
        except OSError:
            print(f"⚠️  Port {port} is in use")
            continue
    
    return 8503  # Default fallback

def start_pwa(port):
    """Start the PWA"""
    print(f"🚀 Starting AfiCare MediLink PWA on port {port}...")
    
    if not Path("medilink_simple.py").exists():
        print("❌ medilink_simple.py not found!")
        return None, None
    
    try:
        # Start Streamlit
        cmd = [
            sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
            "--server.port", str(port),
            "--server.headless", "false",
            "--server.enableCORS", "false",
            "--server.enableXsrfProtection", "false"
        ]
        
        process = subprocess.Popen(cmd, cwd=Path.cwd())
        
        # Wait for startup
        print("⏳ Waiting for PWA to start...")
        time.sleep(8)
        
        # Test if running
        url = f"http://localhost:{port}"
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                print("✅ PWA is running successfully!")
                return process, url
            else:
                print(f"⚠️  PWA responded with status {response.status_code}")
                return process, url
        except:
            print("⚠️  Could not test PWA response, but it should be running")
            return process, url
        
    except Exception as e:
        print(f"❌ Error starting PWA: {e}")
        return None, None

def test_features_quickly():
    """Quick automated feature tests"""
    print_header("🧪 Quick Feature Tests")
    
    # Test QR code generation
    try:
        import qrcode
        from io import BytesIO
        
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data("Test")
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        
        print("✅ QR Code Generation: WORKING")
    except Exception as e:
        print(f"❌ QR Code Generation: FAILED - {e}")
    
    # Test AI imports
    try:
        import sys
        sys.path.insert(0, 'src')
        from core.agent import AfiCareAgent
        print("✅ AI Agent Import: WORKING")
    except Exception as e:
        print(f"❌ AI Agent Import: FAILED - {e}")
    
    # Test database
    try:
        import sqlite3
        db_files = ["aficare.db", "aficare_enhanced.db", "aficare_medilink.db"]
        found_db = False
        
        for db_file in db_files:
            if Path(db_file).exists():
                found_db = True
                break
        
        if found_db:
            print("✅ Database: FOUND")
        else:
            print("⚠️  Database: NOT FOUND (will create on first use)")
    except Exception as e:
        print(f"❌ Database Test: FAILED - {e}")

def show_testing_guide(url):
    """Show comprehensive testing guide"""
    print_header("🎯 COMPREHENSIVE TESTING GUIDE")
    
    print(f"🌐 Your PWA is running at: {url}")
    print()
    print("📋 **STEP-BY-STEP TESTING:**")
    print()
    
    print("1. **LOGIN TESTS** (Test all 3 accounts)")
    print("   👤 Patient: patient@demo.com / demo123")
    print("   👨‍⚕️ Doctor: doctor@demo.com / demo123") 
    print("   👨‍💼 Admin: admin@demo.com / demo123")
    print()
    
    print("2. **QR CODE TEST** (Most Important!)")
    print("   • Login as patient")
    print("   • Go to 'Health Records' tab")
    print("   • Click '📱 Generate QR Code'")
    print("   • Select any QR type")
    print("   • Click 'Generate QR Code' button")
    print("   • ✅ SUCCESS: You see an actual QR code image")
    print("   • ❌ FAILURE: You see 'Install qrcode library' message")
    print()
    
    print("3. **AI CONSULTATION TEST**")
    print("   • Login as doctor")
    print("   • Go to 'AI Agent Demo' tab")
    print("   • Enter symptoms: fever, headache, chills")
    print("   • Click 'Run Consultation'")
    print("   • ✅ SUCCESS: Get malaria diagnosis with confidence score")
    print("   • ❌ FAILURE: Error messages or no diagnosis")
    print()
    
    print("4. **MOBILE PWA TEST**")
    print("   • Look for '📱 Install App' button")
    print("   • Resize browser window to mobile size")
    print("   • Check if interface adapts properly")
    print()
    
    print("5. **PATIENT RECORDS TEST**")
    print("   • Login as patient")
    print("   • Check 'Health Summary' tab")
    print("   • View 'Visit History'")
    print("   • Test 'Maternal Health' (if applicable)")
    print()
    
    print("🎯 **CRITICAL SUCCESS CRITERIA:**")
    print("   ✅ All demo accounts work")
    print("   ✅ QR codes generate (NO error messages)")
    print("   ✅ AI gives medical diagnoses")
    print("   ✅ No raw HTML/CSS code visible")
    print("   ✅ Mobile-responsive interface")

def main():
    print("🏥 AfiCare MediLink - Quick Start and Test")
    print("   Starting PWA and running comprehensive tests")
    
    try:
        # Step 1: Clean up
        kill_streamlit_processes()
        
        # Step 2: Find port
        port = find_free_port()
        
        # Step 3: Start PWA
        process, url = start_pwa(port)
        
        if not process or not url:
            print("❌ Failed to start PWA")
            return False
        
        # Step 4: Quick tests
        test_features_quickly()
        
        # Step 5: Open browser
        print(f"🌐 Opening {url} in browser...")
        webbrowser.open(url)
        
        # Step 6: Show testing guide
        show_testing_guide(url)
        
        print("\n" + "="*60)
        print("🎯 **YOUR TURN - TEST THE PWA NOW!**")
        print("="*60)
        print("Follow the testing guide above to verify all features work.")
        print("Pay special attention to QR code generation!")
        print()
        print("When you're done testing, come back here and:")
        print("1. Press Enter if everything works ✅")
        print("2. Or Ctrl+C if you found issues ❌")
        print("="*60)
        
        try:
            input("\nPress Enter when you've completed testing...")
            
            print("\n✅ PWA testing complete!")
            print("🚀 Ready to proceed with Flutter setup!")
            
            # Stop PWA
            print("🛑 Stopping PWA...")
            process.terminate()
            time.sleep(2)
            print("✅ PWA stopped")
            
            return True
            
        except KeyboardInterrupt:
            print("\n🛑 Stopping PWA...")
            process.terminate()
            time.sleep(2)
            print("✅ PWA stopped")
            print("❌ Testing cancelled - please fix any issues found")
            return False
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = main()
    
    if success:
        print("\n🎯 **NEXT STEP: FLUTTER SETUP**")
        print("Run: python setup_flutter_here.py")
    else:
        print("\n🔧 **TROUBLESHOOTING NEEDED**")
        print("Fix any issues found during testing")
    
    input("\nPress Enter to exit...")
    sys.exit(0 if success else 1)