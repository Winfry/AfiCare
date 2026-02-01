#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AfiCare MediLink - Mobile Testing Guide
Complete guide for testing PWA on mobile devices
"""

import subprocess
import sys
import time
import socket
import requests
from pathlib import Path
import json
import os

# Fix Windows encoding issues
if sys.platform.startswith('win'):
    os.system('chcp 65001 > nul')

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def get_network_ip():
    """Get the local network IP address"""
    try:
        # Connect to a remote address to determine local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except:
        return "192.168.1.100"  # Fallback

def start_pwa_for_mobile(port=8503):
    """Start PWA with mobile-accessible configuration"""
    print(f"🚀 Starting AfiCare PWA for mobile testing on port {port}...")
    
    if not Path("medilink_simple.py").exists():
        print("❌ medilink_simple.py not found!")
        return None, None, None
    
    try:
        # Get network IP
        network_ip = get_network_ip()
        
        # Start Streamlit with network access enabled
        cmd = [
            sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
            "--server.port", str(port),
            "--server.address", "0.0.0.0",  # Allow external connections
            "--server.headless", "false",
            "--server.enableCORS", "false",
            "--server.enableXsrfProtection", "false",
            "--server.maxUploadSize", "200"
        ]
        
        print(f"🔧 Starting with command: {' '.join(cmd)}")
        
        process = subprocess.Popen(cmd, cwd=Path.cwd())
        
        # Wait for startup
        print("⏳ Waiting for PWA to start...")
        time.sleep(8)
        
        # URLs for access
        local_url = f"http://localhost:{port}"
        network_url = f"http://{network_ip}:{port}"
        
        # Test local access
        try:
            response = requests.get(local_url, timeout=5)
            if response.status_code == 200:
                print("✅ PWA is running locally!")
            else:
                print(f"⚠️  Local access responded with status {response.status_code}")
        except:
            print("⚠️  Could not test local access")
        
        return process, local_url, network_url
        
    except Exception as e:
        print(f"❌ Error starting PWA: {e}")
        return None, None, None

def show_mobile_testing_guide(local_url, network_url):
    """Show comprehensive mobile testing guide"""
    print_header("📱 MOBILE TESTING GUIDE")
    
    print("🌐 **ACCESS URLS:**")
    print(f"   💻 Desktop: {local_url}")
    print(f"   📱 Mobile: {network_url}")
    print()
    
    print("📱 **STEP 1: CONNECT YOUR PHONE**")
    print("   1. Make sure your phone is on the same WiFi network as your computer")
    print("   2. Open your phone's web browser (Chrome, Safari, etc.)")
    print(f"   3. Go to: {network_url}")
    print("   4. You should see the AfiCare MediLink login page")
    print()
    
    print("🔐 **STEP 2: TEST MOBILE LOGINS**")
    print("   Test all three demo accounts on your phone:")
    print()
    print("   👤 **Patient Account:**")
    print("      Email: patient@demo.com")
    print("      Password: demo123")
    print("      Expected: Health records, QR sharing, maternal health")
    print()
    print("   👨‍⚕️ **Doctor Account:**")
    print("      Email: doctor@demo.com")
    print("      Password: demo123")
    print("      Expected: Patient access, AI consultation, QR scanner")
    print()
    print("   👨‍💼 **Admin Account:**")
    print("      Email: admin@demo.com")
    print("      Password: demo123")
    print("      Expected: User management, system analytics")
    print()
    
    print("📱 **STEP 3: TEST MOBILE PWA FEATURES**")
    print("   1. **Install as App:**")
    print("      • Android: Look for 'Add to Home Screen' or '📱 Install App'")
    print("      • iPhone: Safari → Share → Add to Home Screen")
    print()
    print("   2. **Test Touch Interface:**")
    print("      • All buttons should be touch-friendly")
    print("      • Forms should be easy to fill on mobile")
    print("      • Text should be readable without zooming")
    print()
    print("   3. **Test QR Code Generation:**")
    print("      • Login as patient")
    print("      • Go to Health Records → QR Code Sharing")
    print("      • Generate QR code")
    print("      • QR code should be clearly visible on mobile")
    print()
    print("   4. **Test AI Consultation:**")
    print("      • Login as doctor")
    print("      • Go to AI Agent Demo")
    print("      • Enter symptoms: fever, headache, chills")
    print("      • Should get malaria diagnosis")
    print()
    
    print("📊 **STEP 4: CHECK MOBILE LOGS**")
    print("   **On Your Phone:**")
    print("   • Android Chrome: Menu → More Tools → Developer Tools")
    print("   • iPhone Safari: Settings → Safari → Advanced → Web Inspector")
    print("   • Look for JavaScript errors in Console tab")
    print()
    print("   **On Your Computer:**")
    print("   • Watch the terminal where PWA is running")
    print("   • Look for error messages or failed requests")
    print("   • Check for mobile-specific issues")
    print()
    
    print("🔍 **STEP 5: TEST MOBILE-SPECIFIC FEATURES**")
    print("   1. **Offline Mode:**")
    print("      • Install PWA as app")
    print("      • Turn off phone's internet")
    print("      • App should still open and show cached data")
    print()
    print("   2. **Camera Access (if implemented):**")
    print("      • Test QR code scanning")
    print("      • Test photo upload for patient records")
    print()
    print("   3. **Touch Gestures:**")
    print("      • Swipe navigation")
    print("      • Pinch to zoom on QR codes")
    print("      • Touch and hold for context menus")
    print()
    
    print("✅ **SUCCESS CRITERIA FOR MOBILE:**")
    print("   ✅ All demo accounts work on mobile")
    print("   ✅ PWA installs as mobile app")
    print("   ✅ Touch interface is responsive")
    print("   ✅ QR codes generate and display properly")
    print("   ✅ AI consultation works on mobile")
    print("   ✅ No JavaScript errors in mobile browser")
    print("   ✅ Offline mode works after installation")
    print()
    
    print("🚨 **COMMON MOBILE ISSUES TO CHECK:**")
    print("   ❌ Text too small to read")
    print("   ❌ Buttons too small to tap")
    print("   ❌ Forms don't work with mobile keyboard")
    print("   ❌ QR codes don't display properly")
    print("   ❌ PWA install button doesn't appear")
    print("   ❌ App doesn't work offline")

def show_log_monitoring_guide():
    """Show how to monitor logs during mobile testing"""
    print_header("📊 LOG MONITORING GUIDE")
    
    print("🖥️  **COMPUTER-SIDE LOGGING:**")
    print("   1. **Terminal Logs:**")
    print("      • Keep the terminal window visible")
    print("      • Watch for HTTP requests from your phone")
    print("      • Look for error messages or warnings")
    print()
    print("   2. **Streamlit Logs:**")
    print("      • Streamlit shows user interactions")
    print("      • Login attempts will be logged")
    print("      • Failed requests will show error details")
    print()
    print("   3. **Database Logs:**")
    print("      • Check logs/ directory for detailed logs")
    print("      • Look for authentication failures")
    print("      • Monitor patient data access")
    print()
    
    print("📱 **MOBILE-SIDE LOGGING:**")
    print("   1. **Android Chrome:**")
    print("      • Open Chrome on your phone")
    print("      • Go to chrome://inspect on your computer")
    print("      • Select your phone's browser tab")
    print("      • View console logs in real-time")
    print()
    print("   2. **iPhone Safari:**")
    print("      • Enable Web Inspector in iPhone Settings")
    print("      • Connect iPhone to Mac with cable")
    print("      • Open Safari on Mac → Develop → [Your iPhone]")
    print("      • Select the AfiCare tab to see logs")
    print()
    print("   3. **Browser Developer Tools:**")
    print("      • Most mobile browsers support F12 or menu → Developer Tools")
    print("      • Check Console tab for JavaScript errors")
    print("      • Check Network tab for failed requests")
    print()
    
    print("🔍 **WHAT TO LOOK FOR IN LOGS:**")
    print("   ✅ **Good Signs:**")
    print("      • 200 OK responses for all requests")
    print("      • Successful login messages")
    print("      • QR code generation success")
    print("      • AI consultation completions")
    print()
    print("   ❌ **Warning Signs:**")
    print("      • 404 Not Found errors")
    print("      • JavaScript console errors")
    print("      • Failed authentication attempts")
    print("      • Timeout errors")
    print("      • CORS (Cross-Origin) errors")

def create_mobile_test_checklist():
    """Create a mobile testing checklist file"""
    checklist = """# 📱 AfiCare Mobile Testing Checklist

## 🌐 Connection Test
- [ ] Phone connected to same WiFi as computer
- [ ] Can access PWA from phone browser
- [ ] PWA loads completely on mobile

## 🔐 Login Tests
- [ ] Patient login works (patient@demo.com / demo123)
- [ ] Doctor login works (doctor@demo.com / demo123)
- [ ] Admin login works (admin@demo.com / demo123)
- [ ] Mobile keyboard works with login forms
- [ ] Remember me checkbox works

## 📱 PWA Installation
- [ ] "Install App" button appears
- [ ] PWA installs successfully
- [ ] App icon appears on home screen
- [ ] App opens from home screen
- [ ] App works in standalone mode

## 🎯 Feature Tests
- [ ] QR code generation works on mobile
- [ ] QR codes display clearly
- [ ] AI consultation works from mobile
- [ ] Patient records load properly
- [ ] Mobile navigation is smooth

## 📊 Performance Tests
- [ ] App loads quickly on mobile
- [ ] No JavaScript errors in console
- [ ] Images and icons load properly
- [ ] Touch interactions are responsive
- [ ] Offline mode works after installation

## 🔍 Visual Tests
- [ ] Text is readable without zooming
- [ ] Buttons are large enough to tap
- [ ] Forms work with mobile keyboard
- [ ] Layout adapts to mobile screen
- [ ] No horizontal scrolling needed

## 📝 Notes
Write any issues found:
- 
- 
- 

## ✅ Final Result
- [ ] All tests passed - Ready for deployment
- [ ] Some issues found - Need fixes
- [ ] Major issues found - Requires debugging
"""
    
    with open("mobile_test_checklist.md", "w") as f:
        f.write(checklist)
    
    print("📝 Created mobile_test_checklist.md for tracking your tests")

def main():
    print("📱 AfiCare MediLink - Mobile Testing Setup")
    print("   Complete guide for testing PWA on mobile devices")
    
    try:
        # Create checklist
        create_mobile_test_checklist()
        
        # Start PWA for mobile
        print_header("🚀 Starting PWA for Mobile Testing")
        
        port = 8503
        process, local_url, network_url = start_pwa_for_mobile(port)
        
        if not process:
            print("❌ Failed to start PWA")
            return False
        
        # Show testing guides
        show_mobile_testing_guide(local_url, network_url)
        show_log_monitoring_guide()
        
        print("\n" + "="*60)
        print("📱 **MOBILE TESTING IS NOW READY!**")
        print("="*60)
        print(f"🌐 Open this URL on your phone: {network_url}")
        print("📝 Use mobile_test_checklist.md to track your testing")
        print("📊 Watch this terminal for logs while testing")
        print()
        print("Press Enter when you've completed mobile testing...")
        print("Or Ctrl+C to stop and fix any issues found")
        print("="*60)
        
        try:
            input()
            
            print("\n✅ Mobile testing complete!")
            print("🚀 Ready for Flutter setup or deployment!")
            
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
            print("🔧 Fix any mobile issues found and test again")
            return False
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = main()
    
    if success:
        print("\n🎯 **NEXT STEPS:**")
        print("1. Flutter setup: python setup_flutter_here.py")
        print("2. Global deployment: python deploy_both_apps.py")
    else:
        print("\n🔧 **TROUBLESHOOTING:**")
        print("1. Check network connectivity")
        print("2. Verify firewall settings")
        print("3. Test with different mobile browsers")
    
    input("\nPress Enter to exit...")
    sys.exit(0 if success else 1)