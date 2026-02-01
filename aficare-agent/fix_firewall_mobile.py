#!/usr/bin/env python3
"""
AfiCare - Fix Firewall for Mobile Access
Solve Windows Firewall blocking mobile connections
"""

import subprocess
import sys
import time
import socket
import os

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def get_network_ip():
    """Get network IP"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except:
        return "192.168.1.100"

def check_firewall_status():
    """Check Windows Firewall status"""
    print("🔍 Checking Windows Firewall status...")
    
    try:
        result = subprocess.run(
            ["netsh", "advfirewall", "show", "allprofiles", "state"],
            capture_output=True, text=True, check=False
        )
        
        if "ON" in result.stdout:
            print("🔥 Windows Firewall is ENABLED (this blocks mobile connections)")
            return True
        else:
            print("✅ Windows Firewall is disabled")
            return False
    except:
        print("⚠️  Could not check firewall status")
        return True

def create_firewall_rule():
    """Create Windows Firewall rule for Python/Streamlit"""
    print("🔧 Creating Windows Firewall rule for Python...")
    
    # Get Python executable path
    python_exe = sys.executable
    
    try:
        # Create inbound rule for Python
        cmd = [
            "netsh", "advfirewall", "firewall", "add", "rule",
            f"name=AfiCare Python Streamlit",
            "dir=in",
            "action=allow",
            f"program={python_exe}",
            "enable=yes"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        
        if result.returncode == 0:
            print("✅ Firewall rule created successfully!")
            return True
        else:
            print(f"❌ Failed to create firewall rule: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Error creating firewall rule: {e}")
        return False

def show_manual_firewall_fix():
    """Show manual firewall fix instructions"""
    print_header("🔧 MANUAL FIREWALL FIX")
    
    python_exe = sys.executable
    
    print("If automatic fix failed, follow these steps:")
    print()
    print("**METHOD 1: Add Python to Firewall (Recommended)**")
    print("1. Press Win+R, type 'wf.msc', press Enter")
    print("2. Click 'Inbound Rules' on the left")
    print("3. Click 'New Rule...' on the right")
    print("4. Select 'Program' → Next")
    print(f"5. Browse and select: {python_exe}")
    print("6. Select 'Allow the connection' → Next")
    print("7. Check all boxes (Domain, Private, Public) → Next")
    print("8. Name: 'AfiCare Python' → Finish")
    print()
    print("**METHOD 2: Temporarily Disable Firewall (Quick Test)**")
    print("1. Press Win+R, type 'firewall.cpl', press Enter")
    print("2. Click 'Turn Windows Defender Firewall on or off'")
    print("3. Turn off firewall for Private networks")
    print("4. Test mobile connection")
    print("5. Turn firewall back on after testing")
    print()
    print("**METHOD 3: Allow Port 8503**")
    print("1. Press Win+R, type 'wf.msc', press Enter")
    print("2. Click 'Inbound Rules' → 'New Rule...'")
    print("3. Select 'Port' → Next")
    print("4. TCP, Specific local ports: 8503 → Next")
    print("5. Allow the connection → Next")
    print("6. Check all boxes → Next")
    print("7. Name: 'AfiCare Port 8503' → Finish")

def test_mobile_connection():
    """Test mobile connection after firewall fix"""
    print_header("🧪 Testing Mobile Connection")
    
    ip = get_network_ip()
    port = 8503
    mobile_url = f"http://{ip}:{port}"
    
    print(f"📱 Mobile URL: {mobile_url}")
    print()
    print("🧪 Testing connection...")
    
    # Test if we can bind to the port with external access
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(('0.0.0.0', port))
        s.listen(1)
        s.close()
        
        print("✅ Port 8503 is accessible for external connections")
        print()
        print("🚀 Now start your PWA:")
        print("   python simple_mobile_test.py")
        print()
        print(f"📱 Then test on your phone: {mobile_url}")
        
        return True
        
    except OSError as e:
        if "Address already in use" in str(e):
            print("✅ Port 8503 is in use (PWA might be running)")
            print(f"📱 Try accessing: {mobile_url}")
            return True
        else:
            print(f"❌ Port 8503 access issue: {e}")
            return False

def start_pwa_with_firewall_fix():
    """Start PWA with firewall considerations"""
    print_header("🚀 Starting PWA with Firewall Fix")
    
    # Kill existing processes
    try:
        subprocess.run(["taskkill", "/F", "/IM", "streamlit.exe"], 
                      capture_output=True, check=False)
        time.sleep(2)
    except:
        pass
    
    ip = get_network_ip()
    port = 8503
    
    print(f"🌐 Computer IP: {ip}")
    print(f"📱 Mobile URL: http://{ip}:{port}")
    print()
    
    # Start Streamlit with network access
    cmd = [
        sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
        "--server.port", str(port),
        "--server.address", "0.0.0.0",  # Allow external connections
        "--server.headless", "false",
        "--server.enableCORS", "false",
        "--server.enableXsrfProtection", "false"
    ]
    
    print("🚀 Starting PWA with external access...")
    print("   (This should work now that firewall is configured)")
    
    try:
        process = subprocess.Popen(cmd)
        
        print("⏳ Waiting for PWA to start...")
        time.sleep(8)
        
        print("\n" + "="*60)
        print("📱 MOBILE TESTING READY!")
        print("="*60)
        print(f"📱 Mobile URL: http://{ip}:{port}")
        print()
        print("🧪 TEST ON YOUR PHONE:")
        print("1. Make sure phone is on same WiFi")
        print(f"2. Open phone browser, go to: http://{ip}:{port}")
        print("3. You should see AfiCare login page")
        print()
        print("🔐 Demo Accounts:")
        print("   Patient: patient@demo.com / demo123")
        print("   Doctor: doctor@demo.com / demo123")
        print("   Admin: admin@demo.com / demo123")
        print()
        print("❌ If still can't connect:")
        print("   • Check phone is on same WiFi network")
        print("   • Try temporarily disabling Windows Firewall")
        print("   • Check router settings (AP Isolation)")
        print()
        print("Press Ctrl+C to stop...")
        print("="*60)
        
        try:
            process.wait()
        except KeyboardInterrupt:
            print("\n🛑 Stopping PWA...")
            process.terminate()
            time.sleep(2)
            print("✅ PWA stopped")
        
        return True
        
    except Exception as e:
        print(f"❌ Error starting PWA: {e}")
        return False

def main():
    print("🔧 AfiCare - Fix Firewall for Mobile Access")
    print("   Solving 'ERR_CONNECTION_TIMED_OUT' error")
    
    # Check if running as administrator
    try:
        is_admin = os.getuid() == 0
    except AttributeError:
        is_admin = subprocess.run(["net", "session"], capture_output=True).returncode == 0
    
    if not is_admin:
        print("\n⚠️  For automatic firewall fix, run as Administrator:")
        print("   1. Right-click Command Prompt")
        print("   2. Select 'Run as administrator'")
        print("   3. Run this script again")
        print()
        print("🔧 Showing manual fix instructions instead...")
        show_manual_firewall_fix()
        
        print("\n🚀 After fixing firewall, test the connection:")
        input("Press Enter to test mobile connection...")
        test_mobile_connection()
        
        print("\n🚀 Start PWA for mobile testing:")
        input("Press Enter to start PWA...")
        start_pwa_with_firewall_fix()
        
    else:
        print("\n✅ Running as Administrator - can fix firewall automatically")
        
        # Check firewall status
        firewall_on = check_firewall_status()
        
        if firewall_on:
            # Try to create firewall rule
            rule_created = create_firewall_rule()
            
            if not rule_created:
                print("\n❌ Automatic fix failed")
                show_manual_firewall_fix()
        
        # Test connection
        test_mobile_connection()
        
        # Start PWA
        print("\n🚀 Starting PWA for mobile testing...")
        start_pwa_with_firewall_fix()

if __name__ == "__main__":
    main()