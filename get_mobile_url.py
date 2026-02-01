#!/usr/bin/env python3
"""
Get Mobile URL for AfiCare PWA
Quick script to get the URL for testing on your phone
"""

import socket
import subprocess
import sys
import requests
import time

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
        return None

def test_pwa_running():
    """Test if PWA is running"""
    ports_to_test = [8503, 8502, 8504, 8505]
    
    for port in ports_to_test:
        try:
            url = f"http://localhost:{port}"
            response = requests.get(url, timeout=3)
            
            if response.status_code == 200:
                if "AfiCare" in response.text or "MediLink" in response.text:
                    return port
        except:
            continue
    
    return None

def main():
    print("📱 AfiCare MediLink - Mobile URL Generator")
    print("=" * 50)
    
    # Get network IP
    ip = get_network_ip()
    if not ip:
        print("❌ Cannot determine your network IP address")
        print("Make sure you're connected to WiFi")
        return
    
    print(f"💻 Your computer's IP: {ip}")
    
    # Test if PWA is running
    port = test_pwa_running()
    
    if port:
        mobile_url = f"http://{ip}:{port}"
        
        print(f"✅ PWA is running on port {port}")
        print()
        print("📱 **MOBILE URL FOR YOUR PHONE:**")
        print(f"   {mobile_url}")
        print()
        print("📋 **HOW TO USE:**")
        print("1. Make sure your phone is on the same WiFi network")
        print("2. Open your phone's web browser")
        print(f"3. Type this URL: {mobile_url}")
        print("4. You should see the AfiCare login page")
        print()
        print("🔐 **DEMO ACCOUNTS:**")
        print("   👤 Patient: patient@demo.com / demo123")
        print("   👨‍⚕️ Doctor: doctor@demo.com / demo123")
        print("   👨‍💼 Admin: admin@demo.com / demo123")
        print()
        print("📱 **WHAT TO TEST:**")
        print("   ✅ Login works on mobile")
        print("   ✅ QR codes generate properly")
        print("   ✅ AI consultation works")
        print("   ✅ PWA install button appears")
        print("   ✅ Touch interface is responsive")
        
    else:
        print("❌ PWA is not running")
        print()
        print("🚀 **START PWA FIRST:**")
        print("   python start_phone_app.py")
        print("   or")
        print("   python mobile_testing_guide.py")
        print()
        print("Then run this script again to get the mobile URL")
    
    print("\n" + "=" * 50)
    print("🌍 **FOR GLOBAL ACCESS (Internet from anywhere):**")
    print("   Run: python global_deployment_complete.py")
    print("   This will set up FREE global deployment!")

if __name__ == "__main__":
    main()
    input("\nPress Enter to exit...")