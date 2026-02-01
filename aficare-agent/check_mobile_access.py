#!/usr/bin/env python3
"""
AfiCare - Check Mobile Access
Quick check if your phone can access the PWA
"""

import socket
import subprocess
import sys
import requests
import time

def get_network_info():
    """Get network information"""
    print("🌐 Network Information:")
    
    try:
        # Get local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        
        print(f"   💻 Computer IP: {local_ip}")
        
        # Get computer name
        import platform
        computer_name = platform.node()
        print(f"   🖥️  Computer Name: {computer_name}")
        
        return local_ip
        
    except Exception as e:
        print(f"   ❌ Error getting network info: {e}")
        return None

def check_port_accessibility(ip, port=8503):
    """Check if port is accessible from network"""
    print(f"\n🔍 Checking port {port} accessibility...")
    
    try:
        # Try to bind to all interfaces
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(('0.0.0.0', port))
        s.listen(1)
        s.close()
        
        print(f"   ✅ Port {port} is available for network access")
        return True
        
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"   ✅ Port {port} is in use (probably by Streamlit)")
            return True
        else:
            print(f"   ❌ Port {port} access issue: {e}")
            return False

def check_firewall_tips():
    """Show firewall configuration tips"""
    print("\n🔥 Firewall Configuration:")
    print("   If your phone can't connect, try these:")
    print()
    print("   **Windows Firewall:**")
    print("   1. Windows Security → Firewall & network protection")
    print("   2. Allow an app through firewall")
    print("   3. Add Python.exe and allow Private networks")
    print()
    print("   **Quick Test:**")
    print("   • Temporarily disable Windows Firewall")
    print("   • Test mobile connection")
    print("   • Re-enable firewall and add Python exception")
    print()
    print("   **Router Settings:**")
    print("   • Make sure AP Isolation is disabled")
    print("   • Check if guest network blocks device communication")

def show_mobile_connection_guide(ip, port=8503):
    """Show how to connect from mobile"""
    url = f"http://{ip}:{port}"
    
    print(f"\n📱 Mobile Connection Guide:")
    print(f"   🌐 URL for your phone: {url}")
    print()
    print("   **Step-by-step:**")
    print("   1. Make sure your phone is on the same WiFi network")
    print("   2. Open your phone's web browser")
    print(f"   3. Type this URL: {url}")
    print("   4. You should see the AfiCare login page")
    print()
    print("   **Demo Accounts to Test:**")
    print("   👤 Patient: patient@demo.com / demo123")
    print("   👨‍⚕️ Doctor: doctor@demo.com / demo123")
    print("   👨‍💼 Admin: admin@demo.com / demo123")
    print()
    print("   **What to Test:**")
    print("   ✅ Login works on mobile")
    print("   ✅ QR codes generate properly")
    print("   ✅ AI consultation works")
    print("   ✅ PWA install button appears")
    print("   ✅ Touch interface is responsive")

def test_pwa_running(ip, port=8503):
    """Test if PWA is currently running"""
    print(f"\n🧪 Testing PWA Status...")
    
    urls_to_test = [
        f"http://localhost:{port}",
        f"http://{ip}:{port}"
    ]
    
    for url in urls_to_test:
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                if "AfiCare" in response.text or "MediLink" in response.text:
                    print(f"   ✅ PWA running at: {url}")
                    return url
                else:
                    print(f"   ⚠️  Response from {url} but no AfiCare content")
            else:
                print(f"   ❌ {url} responded with status {response.status_code}")
        except requests.exceptions.RequestException:
            print(f"   ❌ Cannot connect to {url}")
    
    print("   ❌ PWA not running. Start it first:")
    print("      python start_phone_app.py")
    return None

def main():
    print("📱 AfiCare - Mobile Access Checker")
    print("   Checking if your phone can access the PWA")
    
    # Get network info
    ip = get_network_info()
    if not ip:
        print("❌ Cannot determine network configuration")
        return
    
    # Check port accessibility
    port_ok = check_port_accessibility(ip)
    
    # Test if PWA is running
    pwa_url = test_pwa_running(ip)
    
    if pwa_url:
        print("\n✅ PWA is running and accessible!")
        show_mobile_connection_guide(ip)
        
        print("\n" + "="*50)
        print("🎯 **READY FOR MOBILE TESTING!**")
        print("="*50)
        print(f"📱 Phone URL: http://{ip}:8503")
        print("📝 Follow the steps above to test on your phone")
        print("📊 Watch terminal logs while testing")
        
    else:
        print("\n❌ PWA not running")
        print("🚀 Start PWA first:")
        print("   python start_phone_app.py")
        print("   or")
        print("   python mobile_testing_guide.py")
    
    # Show firewall tips
    check_firewall_tips()
    
    print("\n🔧 **TROUBLESHOOTING TIPS:**")
    print("• Make sure phone and computer are on same WiFi")
    print("• Check Windows Firewall settings")
    print("• Try different mobile browsers")
    print("• Restart router if connection fails")

if __name__ == "__main__":
    main()
    input("\nPress Enter to exit...")