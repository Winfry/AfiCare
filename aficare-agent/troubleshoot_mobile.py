#!/usr/bin/env python3
"""
AfiCare - Mobile Connection Troubleshooter
Diagnose and fix "This site can't be reached" issues
"""

import subprocess
import sys
import time
import socket
import requests
import os
from pathlib import Path

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def print_step(step, description):
    print(f"\n🔍 STEP {step}: {description}")
    print("-" * 50)

def get_network_info():
    """Get detailed network information"""
    print_step(1, "Getting Network Information")
    
    try:
        # Get local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        
        print(f"✅ Computer IP Address: {local_ip}")
        
        # Get network adapter info
        result = subprocess.run(["ipconfig"], capture_output=True, text=True, check=False)
        
        if "Wireless LAN adapter Wi-Fi" in result.stdout:
            print("✅ WiFi adapter detected")
        else:
            print("⚠️  WiFi adapter not clearly detected")
        
        return local_ip
        
    except Exception as e:
        print(f"❌ Error getting network info: {e}")
        return None

def test_local_connectivity():
    """Test if PWA is running locally"""
    print_step(2, "Testing Local PWA Connectivity")
    
    ports_to_test = [8503, 8502, 8504, 8505]
    
    for port in ports_to_test:
        try:
            response = requests.get(f"http://localhost:{port}", timeout=3)
            if response.status_code == 200:
                if "AfiCare" in response.text or "MediLink" in response.text:
                    print(f"✅ PWA is running on port {port}")
                    return port
                else:
                    print(f"⚠️  Port {port} responds but no AfiCare content")
            else:
                print(f"⚠️  Port {port} responds with status {response.status_code}")
        except:
            print(f"❌ Port {port} not accessible")
    
    print("❌ PWA is not running locally")
    return None

def test_port_binding():
    """Test if we can bind to port with external access"""
    print_step(3, "Testing Port Binding for External Access")
    
    port = 8503
    
    try:
        # Test binding to all interfaces (0.0.0.0)
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(('0.0.0.0', port))
        s.listen(1)
        s.close()
        
        print(f"✅ Port {port} can bind to all interfaces (0.0.0.0)")
        return True
        
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"✅ Port {port} is in use (PWA might be running)")
            return True
        else:
            print(f"❌ Port {port} binding failed: {e}")
            return False

def check_windows_firewall():
    """Check Windows Firewall status"""
    print_step(4, "Checking Windows Firewall")
    
    try:
        # Check firewall status
        result = subprocess.run(
            ["netsh", "advfirewall", "show", "allprofiles", "state"],
            capture_output=True, text=True, check=False
        )
        
        if "ON" in result.stdout:
            print("🔥 Windows Firewall is ENABLED")
            print("   This is likely blocking mobile connections")
            
            # Check if Python has firewall rules
            result2 = subprocess.run(
                ["netsh", "advfirewall", "firewall", "show", "rule", "name=all"],
                capture_output=True, text=True, check=False
            )
            
            python_exe = sys.executable.lower()
            if python_exe in result2.stdout.lower():
                print("✅ Python has some firewall rules")
            else:
                print("❌ Python has no firewall rules")
            
            return True
        else:
            print("✅ Windows Firewall is disabled")
            return False
            
    except Exception as e:
        print(f"⚠️  Could not check firewall: {e}")
        return True

def check_network_connectivity():
    """Check network connectivity between devices"""
    print_step(5, "Testing Network Connectivity")
    
    ip = get_network_info()
    if not ip:
        return False
    
    print(f"🌐 Testing if computer can reach itself at {ip}...")
    
    try:
        # Test if we can reach our own IP
        response = requests.get(f"http://{ip}:8503", timeout=5)
        print("✅ Computer can reach its own IP address")
        return True
    except requests.exceptions.ConnectRefused:
        print("❌ Connection refused - PWA not running with external access")
        return False
    except requests.exceptions.Timeout:
        print("❌ Connection timeout - firewall or network issue")
        return False
    except Exception as e:
        print(f"❌ Network connectivity issue: {e}")
        return False

def diagnose_router_settings():
    """Diagnose potential router issues"""
    print_step(6, "Checking Router/WiFi Settings")
    
    print("🔍 Potential router issues:")
    print("   • AP Isolation enabled (blocks device-to-device communication)")
    print("   • Guest network restrictions")
    print("   • Router firewall blocking internal connections")
    print("   • Different WiFi bands (2.4GHz vs 5GHz)")
    print()
    print("🧪 Router troubleshooting:")
    print("   1. Make sure both devices are on the SAME WiFi network")
    print("   2. Check if phone is on 'Guest' network (switch to main network)")
    print("   3. Try connecting phone to 2.4GHz band if using 5GHz")
    print("   4. Restart router if issues persist")

def provide_solutions(ip, pwa_running, firewall_on):
    """Provide specific solutions based on diagnosis"""
    print_header("🔧 SOLUTIONS BASED ON DIAGNOSIS")
    
    if not pwa_running:
        print("❌ PROBLEM: PWA is not running")
        print("🚀 SOLUTION:")
        print("   1. Start PWA: python simple_mobile_test.py")
        print("   2. Or: python start_phone_app.py")
        print("   3. Make sure it starts with --server.address 0.0.0.0")
        print()
    
    if firewall_on:
        print("❌ PROBLEM: Windows Firewall is blocking connections")
        print("🚀 SOLUTIONS (choose one):")
        print()
        print("   **SOLUTION A: Temporary Firewall Disable (Fastest)**")
        print("   1. Press Win+S, search 'Windows Security'")
        print("   2. Go to 'Firewall & network protection'")
        print("   3. Click 'Private network'")
        print("   4. Turn OFF 'Windows Defender Firewall'")
        print("   5. Test mobile connection")
        print("   6. Turn firewall back ON after testing")
        print()
        print("   **SOLUTION B: Add Python to Firewall (Permanent)**")
        print("   1. Press Win+S, search 'Allow an app through Windows Firewall'")
        print("   2. Click 'Change settings' (requires admin)")
        print("   3. Click 'Allow another app...'")
        print(f"   4. Browse and select: {sys.executable}")
        print("   5. Check 'Private' checkbox")
        print("   6. Click 'Add' then 'OK'")
        print()
        print("   **SOLUTION C: Create Port Rule**")
        print("   1. Press Win+R, type 'wf.msc', press Enter")
        print("   2. Click 'Inbound Rules' → 'New Rule...'")
        print("   3. Select 'Port' → Next")
        print("   4. TCP, Specific local ports: 8503 → Next")
        print("   5. Allow the connection → Next")
        print("   6. Check all boxes → Next")
        print("   7. Name: 'AfiCare Port 8503' → Finish")
        print()
    
    print("🧪 **TESTING STEPS AFTER FIXES:**")
    print(f"   1. Start PWA: python simple_mobile_test.py")
    print(f"   2. On your phone, go to: http://{ip}:8503")
    print("   3. You should see AfiCare login page")
    print()
    print("🔐 **Demo Accounts for Testing:**")
    print("   Patient: patient@demo.com / demo123")
    print("   Doctor: doctor@demo.com / demo123")
    print("   Admin: admin@demo.com / demo123")

def start_pwa_with_external_access():
    """Start PWA with proper external access configuration"""
    print_header("🚀 Starting PWA with External Access")
    
    # Kill existing processes
    try:
        subprocess.run(["taskkill", "/F", "/IM", "streamlit.exe"], 
                      capture_output=True, check=False)
        time.sleep(2)
        print("✅ Stopped existing Streamlit processes")
    except:
        print("ℹ️  No existing processes to stop")
    
    ip = get_network_info()
    port = 8503
    
    if not ip:
        print("❌ Cannot determine IP address")
        return False
    
    # Start Streamlit with external access
    cmd = [
        sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
        "--server.port", str(port),
        "--server.address", "0.0.0.0",  # CRITICAL: Allow external connections
        "--server.headless", "false",
        "--server.enableCORS", "false",
        "--server.enableXsrfProtection", "false"
    ]
    
    print(f"🚀 Starting PWA with external access...")
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
            else:
                print(f"⚠️  PWA responds with status {response.status_code}")
        except:
            print("❌ PWA not responding locally")
        
        print("\n" + "="*60)
        print("📱 MOBILE TESTING READY!")
        print("="*60)
        print(f"💻 Computer IP: {ip}")
        print(f"📱 Mobile URL: http://{ip}:{port}")
        print()
        print("🧪 **TEST ON YOUR PHONE NOW:**")
        print("1. Make sure phone is on same WiFi network")
        print(f"2. Open phone browser, go to: http://{ip}:{port}")
        print("3. You should see AfiCare login page")
        print()
        print("❌ **If still 'This site can't be reached':**")
        print("   • Windows Firewall is still blocking")
        print("   • Phone is on different network")
        print("   • Router has AP Isolation enabled")
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
    print("🔧 AfiCare - Mobile Connection Troubleshooter")
    print("   Diagnosing 'This site can't be reached' issue")
    
    # Run comprehensive diagnosis
    ip = get_network_info()
    pwa_port = test_local_connectivity()
    port_ok = test_port_binding()
    firewall_on = check_windows_firewall()
    network_ok = check_network_connectivity()
    
    # Diagnose router issues
    diagnose_router_settings()
    
    # Provide solutions
    provide_solutions(ip, pwa_port is not None, firewall_on)
    
    print("\n" + "="*60)
    print("🎯 RECOMMENDED ACTION PLAN")
    print("="*60)
    
    if firewall_on:
        print("1. **FIX FIREWALL** (choose fastest method above)")
        print("2. **START PWA** with external access")
        print("3. **TEST MOBILE** connection")
    else:
        print("1. **START PWA** with external access")
        print("2. **TEST MOBILE** connection")
        print("3. **CHECK ROUTER** settings if still failing")
    
    print("\n🚀 **START PWA NOW?**")
    choice = input("Start PWA with external access? (y/n): ").strip().lower()
    
    if choice in ['y', 'yes', '']:
        start_pwa_with_external_access()
    else:
        print("\n🔧 Fix the issues above first, then run:")
        print("   python simple_mobile_test.py")

if __name__ == "__main__":
    main()