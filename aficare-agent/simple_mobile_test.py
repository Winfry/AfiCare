#!/usr/bin/env python3
"""
AfiCare - Simple Mobile Test
Get mobile URL and start PWA for phone testing
"""

import subprocess
import sys
import time
import socket
import requests

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

def start_pwa_for_mobile():
    """Start PWA with mobile access"""
    print("Starting AfiCare PWA for mobile testing...")
    
    # Kill existing processes
    try:
        subprocess.run(["taskkill", "/F", "/IM", "streamlit.exe"], 
                      capture_output=True, check=False)
        time.sleep(2)
    except:
        pass
    
    # Get network IP
    ip = get_network_ip()
    port = 8503
    
    # Start Streamlit with network access
    cmd = [
        sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
        "--server.port", str(port),
        "--server.address", "0.0.0.0",  # Allow external connections
        "--server.headless", "false",
        "--server.enableCORS", "false",
        "--server.enableXsrfProtection", "false"
    ]
    
    print(f"Starting PWA on port {port}...")
    process = subprocess.Popen(cmd)
    
    # Wait for startup
    time.sleep(8)
    
    # Show URLs
    local_url = f"http://localhost:{port}"
    mobile_url = f"http://{ip}:{port}"
    
    print("\n" + "="*60)
    print("MOBILE TESTING READY!")
    print("="*60)
    print(f"Computer IP: {ip}")
    print(f"Desktop URL: {local_url}")
    print(f"MOBILE URL: {mobile_url}")
    print()
    print("HOW TO TEST ON YOUR PHONE:")
    print("1. Make sure phone is on same WiFi as computer")
    print(f"2. Open phone browser and go to: {mobile_url}")
    print("3. You should see AfiCare login page")
    print()
    print("DEMO ACCOUNTS:")
    print("Patient: patient@demo.com / demo123")
    print("Doctor: doctor@demo.com / demo123")
    print("Admin: admin@demo.com / demo123")
    print()
    print("TEST ON PHONE:")
    print("- Login works")
    print("- QR codes generate")
    print("- AI consultation works")
    print("- PWA install button appears")
    print("- Touch interface responsive")
    print()
    print("Press Ctrl+C to stop...")
    print("="*60)
    
    try:
        process.wait()
    except KeyboardInterrupt:
        print("\nStopping PWA...")
        process.terminate()
        time.sleep(2)
        print("PWA stopped")

if __name__ == "__main__":
    start_pwa_for_mobile()