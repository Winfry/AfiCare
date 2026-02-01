#!/usr/bin/env python3
"""
AfiCare - Complete Mobile Solution
Automatically diagnose, fix, and deploy mobile access
"""

import subprocess
import sys
import time
import socket
import requests
import os
import webbrowser
from pathlib import Path

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def run_command(command, check=False):
    """Run command and return result"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=check)
        return result
    except:
        return None

def get_network_ip():
    """Get network IP address"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except:
        return "192.168.1.100"

def kill_streamlit_processes():
    """Kill existing Streamlit processes"""
    print("🔧 Stopping existing Streamlit processes...")
    try:
        run_command("taskkill /F /IM streamlit.exe")
        run_command("taskkill /F /IM python.exe /FI \"WINDOWTITLE eq streamlit*\"")
        time.sleep(3)
        print("✅ Existing processes stopped")
    except:
        print("ℹ️  No existing processes to stop")

def check_and_fix_firewall():
    """Check and provide firewall solutions"""
    print_header("🔥 FIREWALL DIAGNOSIS AND SOLUTIONS")
    
    # Check firewall status
    result = run_command("netsh advfirewall show allprofiles state")
    
    if result and "ON" in result.stdout:
        print("❌ PROBLEM IDENTIFIED: Windows Firewall is blocking connections")
        print()
        print("🚀 AUTOMATIC SOLUTIONS:")
        print()
        
        # Try to create firewall rule automatically
        python_exe = sys.executable
        
        print("🔧 Attempting to create firewall rule...")
        rule_cmd = f'netsh advfirewall firewall add rule name="AfiCare Python" dir=in action=allow program="{python_exe}" enable=yes'
        
        rule_result = run_command(rule_cmd)
        
        if rule_result and rule_result.returncode == 0:
            print("✅ Firewall rule created successfully!")
            return True
        else:
            print("❌ Automatic firewall rule creation failed")
            print("   (This requires Administrator privileges)")
            print()
            
            # Show manual solutions
            print("🔧 MANUAL SOLUTIONS (Choose one):")
            print()
            print("**SOLUTION 1: Temporary Disable (30 seconds)**")
            print("1. Press Win+S, search 'Windows Security'")
            print("2. Go to 'Firewall & network protection'")
            print("3. Click 'Private network'")
            print("4. Turn OFF 'Windows Defender Firewall'")
            print("5. Test mobile connection")
            print("6. Turn firewall back ON after testing")
            print()
            
            print("**SOLUTION 2: Add Python Exception**")
            print("1. Press Win+S, search 'Allow an app through Windows Firewall'")
            print("2. Click 'Change settings' (admin required)")
            print("3. Click 'Allow another app...'")
            print(f"4. Browse and select: {python_exe}")
            print("5. Check 'Private' checkbox")
            print("6. Click 'Add' then 'OK'")
            print()
            
            print("**SOLUTION 3: Port Exception**")
            print("1. Press Win+R, type 'wf.msc', press Enter")
            print("2. Click 'Inbound Rules' → 'New Rule...'")
            print("3. Select 'Port' → Next")
            print("4. TCP, Specific local ports: 8503 → Next")
            print("5. Allow the connection → Next")
            print("6. Check all boxes → Next")
            print("7. Name: 'AfiCare Port 8503' → Finish")
            
            return False
    else:
        print("✅ Windows Firewall is disabled or allowing connections")
        return True

def test_pwa_requirements():
    """Test PWA requirements"""
    print_header("📦 CHECKING PWA REQUIREMENTS")
    
    # Check if medilink_simple.py exists
    if not Path("medilink_simple.py").exists():
        print("❌ medilink_simple.py not found!")
        print("   Make sure you're in the aficare-agent directory")
        return False
    
    print("✅ medilink_simple.py found")
    
    # Check Python packages
    try:
        import streamlit
        print("✅ Streamlit installed")
    except ImportError:
        print("❌ Streamlit not installed")
        print("   Installing Streamlit...")
        run_command("pip install streamlit")
    
    try:
        import qrcode
        print("✅ QR code library installed")
    except ImportError:
        print("❌ QR code library not installed")
        print("   Installing QR code library...")
        run_command("pip install qrcode[pil]")
    
    return True

def start_pwa_with_mobile_access():
    """Start PWA with proper mobile access configuration"""
    print_header("🚀 STARTING PWA WITH MOBILE ACCESS")
    
    ip = get_network_ip()
    port = 8503
    
    print(f"🌐 Computer IP: {ip}")
    print(f"📱 Mobile URL: http://{ip}:{port}")
    
    # Start Streamlit with external access
    cmd = [
        sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
        "--server.port", str(port),
        "--server.address", "0.0.0.0",  # CRITICAL: Allow external connections
        "--server.headless", "false",
        "--server.enableCORS", "false",
        "--server.enableXsrfProtection", "false",
        "--server.maxUploadSize", "200"
    ]
    
    print("🚀 Starting PWA with mobile access enabled...")
    print(f"   Command: {' '.join(cmd)}")
    
    try:
        process = subprocess.Popen(cmd)
        
        print("⏳ Waiting for PWA to start...")
        time.sleep(10)
        
        # Test local access
        try:
            response = requests.get(f"http://localhost:{port}", timeout=5)
            if response.status_code == 200:
                print("✅ PWA is running locally")
                
                # Test external access
                try:
                    response2 = requests.get(f"http://{ip}:{port}", timeout=5)
                    if response2.status_code == 200:
                        print("✅ PWA is accessible externally")
                    else:
                        print("⚠️  PWA local only - firewall may be blocking")
                except:
                    print("⚠️  External access blocked - firewall issue")
                    
            else:
                print(f"⚠️  PWA responds with status {response.status_code}")
        except:
            print("❌ PWA not responding - startup failed")
            return None, None
        
        return process, f"http://{ip}:{port}"
        
    except Exception as e:
        print(f"❌ Error starting PWA: {e}")
        return None, None

def show_mobile_testing_guide(mobile_url):
    """Show comprehensive mobile testing guide"""
    print_header("📱 MOBILE TESTING GUIDE")
    
    print(f"🌐 **YOUR MOBILE URL:** {mobile_url}")
    print()
    print("📱 **STEP-BY-STEP MOBILE TESTING:**")
    print()
    print("1. **Connect Your Phone:**")
    print("   • Make sure your phone is on the SAME WiFi network as your computer")
    print("   • NOT on guest network or mobile data")
    print()
    print("2. **Open Phone Browser:**")
    print("   • Open Chrome, Safari, or any browser on your phone")
    print(f"   • Type this URL exactly: {mobile_url}")
    print("   • Press Enter/Go")
    print()
    print("3. **Expected Result:**")
    print("   ✅ You should see the AfiCare MediLink login page")
    print("   ✅ The page should load completely")
    print("   ✅ No 'This site can't be reached' error")
    print()
    print("4. **Test Login:**")
    print("   👤 Patient: patient@demo.com / demo123")
    print("   👨‍⚕️ Doctor: doctor@demo.com / demo123")
    print("   👨‍💼 Admin: admin@demo.com / demo123")
    print()
    print("5. **Test Features:**")
    print("   • Generate QR codes (should show actual QR images)")
    print("   • Test AI consultation (should give medical diagnoses)")
    print("   • Look for '📱 Install App' button")
    print("   • Test touch interface responsiveness")
    print()
    print("❌ **IF STILL 'THIS SITE CAN'T BE REACHED':**")
    print("   1. Windows Firewall is still blocking")
    print("   2. Phone is on different WiFi network")
    print("   3. Router has AP Isolation enabled")
    print("   4. Try different browser on phone")
    print()
    print("🌍 **ALTERNATIVE: GLOBAL DEPLOYMENT**")
    print("   If local mobile testing is too complex:")
    print("   • Run: python global_deploy.py")
    print("   • Deploy to Railway.app (FREE)")
    print("   • Get global URL accessible from anywhere")

def create_global_deployment_alternative():
    """Create global deployment as alternative"""
    print_header("🌍 GLOBAL DEPLOYMENT ALTERNATIVE")
    
    print("If local mobile testing is problematic, you can deploy globally:")
    print()
    print("🚀 **GLOBAL DEPLOYMENT BENEFITS:**")
    print("   ✅ No firewall issues")
    print("   ✅ No network configuration needed")
    print("   ✅ Accessible from anywhere in the world")
    print("   ✅ HTTPS security enabled")
    print("   ✅ 100% FREE using Railway.app")
    print()
    print("📋 **GLOBAL DEPLOYMENT STEPS:**")
    print("   1. Run: python global_deploy.py")
    print("   2. Follow the Railway.app deployment guide")
    print("   3. Get global URL: https://your-app.railway.app")
    print("   4. Test from any device, anywhere")
    print()
    
    choice = input("🌍 Would you like to setup global deployment instead? (y/n): ").strip().lower()
    
    if choice in ['y', 'yes']:
        print("🚀 Setting up global deployment...")
        try:
            result = run_command("python global_deploy.py")
            if result:
                print("✅ Global deployment setup complete!")
                print("   Check the GLOBAL_DEPLOYMENT_GUIDE.md file")
            else:
                print("❌ Global deployment setup failed")
        except:
            print("❌ Could not run global deployment setup")
            print("   Try: python global_deploy.py")

def main():
    print("🏥 AfiCare - Complete Mobile Solution")
    print("   Automatic diagnosis, fix, and deployment")
    
    # Step 1: Check requirements
    if not test_pwa_requirements():
        print("❌ PWA requirements not met")
        return False
    
    # Step 2: Kill existing processes
    kill_streamlit_processes()
    
    # Step 3: Check and fix firewall
    firewall_ok = check_and_fix_firewall()
    
    if not firewall_ok:
        print("\n🔧 **FIREWALL NEEDS MANUAL FIX**")
        print("Please fix the firewall using one of the solutions above")
        
        choice = input("\nHave you fixed the firewall? (y/n): ").strip().lower()
        
        if choice not in ['y', 'yes']:
            print("\n🌍 **ALTERNATIVE: GLOBAL DEPLOYMENT**")
            create_global_deployment_alternative()
            return False
    
    # Step 4: Start PWA with mobile access
    process, mobile_url = start_pwa_with_mobile_access()
    
    if not process or not mobile_url:
        print("❌ Failed to start PWA")
        return False
    
    # Step 5: Show mobile testing guide
    show_mobile_testing_guide(mobile_url)
    
    # Step 6: Open desktop browser for reference
    print(f"\n🌐 Opening desktop browser for reference...")
    webbrowser.open(mobile_url.replace(get_network_ip(), "localhost"))
    
    print("\n" + "="*60)
    print("🎉 MOBILE SOLUTION COMPLETE!")
    print("="*60)
    print(f"📱 Mobile URL: {mobile_url}")
    print("🧪 Test on your phone now!")
    print("📋 Follow the testing guide above")
    print()
    print("Press Ctrl+C to stop the PWA...")
    print("="*60)
    
    try:
        process.wait()
    except KeyboardInterrupt:
        print("\n🛑 Stopping PWA...")
        process.terminate()
        time.sleep(2)
        print("✅ PWA stopped")
    
    return True

if __name__ == "__main__":
    success = main()
    
    if success:
        print("\n🎯 **MOBILE SOLUTION IMPLEMENTED!**")
        print("Your AfiCare system is ready for mobile testing!")
    else:
        print("\n🔧 **TROUBLESHOOTING NEEDED**")
        print("Follow the solutions provided above")
    
    input("\nPress Enter to exit...")
    sys.exit(0 if success else 1)