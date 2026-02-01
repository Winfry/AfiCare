#!/usr/bin/env python3
"""
AfiCare - Mobile Quick Fix
Alternative approach to mobile testing without firewall issues
"""

import subprocess
import sys
import time
import webbrowser
import socket

def print_header(title):
    print(f"\n{'='*50}")
    print(f"  {title}")
    print(f"{'='*50}")

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

def show_firewall_solutions():
    """Show firewall solutions"""
    print_header("🔧 FIREWALL SOLUTIONS")
    
    ip = get_network_ip()
    
    print("The 'ERR_CONNECTION_TIMED_OUT' error means Windows Firewall")
    print("is blocking connections from your phone to your computer.")
    print()
    print("🚀 **QUICK SOLUTIONS:**")
    print()
    print("**SOLUTION 1: Temporary Firewall Disable (Fastest)**")
    print("1. Press Win+S, search 'Windows Security'")
    print("2. Go to 'Firewall & network protection'")
    print("3. Click 'Private network' (your WiFi)")
    print("4. Turn OFF 'Windows Defender Firewall'")
    print("5. Test mobile connection")
    print("6. Turn firewall back ON after testing")
    print()
    print("**SOLUTION 2: Add Python to Firewall (Permanent)**")
    print("1. Press Win+S, search 'Allow an app through Windows Firewall'")
    print("2. Click 'Change settings' (requires admin)")
    print("3. Click 'Allow another app...'")
    print("4. Browse and select: C:\\Python313\\python.exe")
    print("5. Check 'Private' checkbox")
    print("6. Click 'Add' then 'OK'")
    print()
    print("**SOLUTION 3: Use Global Deployment Instead**")
    print("Skip local mobile testing and deploy globally:")
    print("• Run: python global_deploy.py")
    print("• Deploy to Railway.app (FREE)")
    print("• Get global URL: https://your-app.railway.app")
    print("• Test from any device, anywhere")
    print()
    print(f"📱 **After fixing firewall, your mobile URL will be:**")
    print(f"   http://{ip}:8503")

def start_local_pwa():
    """Start PWA for local testing"""
    print_header("🚀 Starting PWA for Local Testing")
    
    # Kill existing processes
    try:
        subprocess.run(["taskkill", "/F", "/IM", "streamlit.exe"], 
                      capture_output=True, check=False)
        time.sleep(2)
    except:
        pass
    
    port = 8503
    
    # Start Streamlit for local access only (no firewall issues)
    cmd = [
        sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
        "--server.port", str(port),
        "--server.headless", "false"
    ]
    
    print("🚀 Starting PWA for local testing...")
    
    try:
        process = subprocess.Popen(cmd)
        
        print("⏳ Waiting for PWA to start...")
        time.sleep(8)
        
        # Open browser
        local_url = f"http://localhost:{port}"
        print(f"🌐 Opening {local_url}")
        webbrowser.open(local_url)
        
        print("\n" + "="*50)
        print("✅ PWA RUNNING LOCALLY!")
        print("="*50)
        print(f"💻 Desktop URL: {local_url}")
        print()
        print("🧪 **TEST FEATURES ON DESKTOP:**")
        print("• Login with demo accounts")
        print("• Generate QR codes")
        print("• Test AI consultation")
        print("• Verify PWA install button")
        print()
        print("🔐 **Demo Accounts:**")
        print("   Patient: patient@demo.com / demo123")
        print("   Doctor: doctor@demo.com / demo123")
        print("   Admin: admin@demo.com / demo123")
        print()
        print("📱 **For Mobile Testing:**")
        print("   Fix firewall first (see instructions above)")
        print("   Then restart with mobile access enabled")
        print()
        print("🌍 **For Global Access:**")
        print("   Run: python global_deploy.py")
        print("   Deploy to Railway.app for worldwide access")
        print()
        print("Press Ctrl+C to stop...")
        print("="*50)
        
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
    print("🔧 AfiCare - Mobile Quick Fix")
    print("   Solving mobile connection issues")
    
    print("\n❌ **PROBLEM IDENTIFIED:**")
    print("Windows Firewall is blocking mobile connections")
    print("Error: ERR_CONNECTION_TIMED_OUT")
    print()
    
    # Show solutions
    show_firewall_solutions()
    
    print("\n🎯 **CHOOSE YOUR APPROACH:**")
    print("1. Fix firewall and test mobile locally")
    print("2. Test features on desktop first")
    print("3. Skip to global deployment")
    print()
    
    choice = input("Enter choice (1/2/3) or press Enter for option 2: ").strip()
    
    if choice == "1":
        print("\n🔧 Follow the firewall fix instructions above")
        print("Then run: python simple_mobile_test.py")
        
    elif choice == "3":
        print("\n🌍 Setting up global deployment...")
        try:
            subprocess.run([sys.executable, "global_deploy.py"])
        except:
            print("Run: python global_deploy.py")
            
    else:
        print("\n🚀 Starting local PWA for desktop testing...")
        start_local_pwa()

if __name__ == "__main__":
    main()