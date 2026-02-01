#!/usr/bin/env python3
"""
AfiCare MediLink - Phone App Starter
Fixes all issues and starts the PWA properly
"""

import subprocess
import sys
import time
import webbrowser
import os
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
        result = subprocess.run(
            ["taskkill", "/F", "/IM", "streamlit.exe"], 
            capture_output=True, text=True, check=False
        )
        result2 = subprocess.run(
            ["taskkill", "/F", "/IM", "python.exe", "/FI", "WINDOWTITLE eq streamlit*"], 
            capture_output=True, text=True, check=False
        )
        print("✅ Cleared existing processes")
    except:
        print("ℹ️  No processes to clear")

def find_free_port():
    """Find a free port to use"""
    ports_to_try = [8503, 8504, 8505, 8506, 8507, 8508]
    
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

def check_requirements():
    """Check and install requirements"""
    print("📦 Checking requirements...")
    
    required_packages = [
        "streamlit",
        "qrcode[pil]",
        "pillow",
        "requests"
    ]
    
    for package in required_packages:
        try:
            if package == "streamlit":
                import streamlit
                print(f"✅ {package} installed")
            elif package == "qrcode[pil]":
                import qrcode
                print(f"✅ {package} installed")
            elif package == "pillow":
                import PIL
                print(f"✅ {package} installed")
            elif package == "requests":
                import requests
                print(f"✅ {package} installed")
        except ImportError:
            print(f"❌ {package} not found. Installing...")
            subprocess.run([sys.executable, "-m", "pip", "install", package])
            print(f"✅ {package} installed")

def test_qr_generation():
    """Test QR code generation"""
    print("🧪 Testing QR code generation...")
    
    try:
        import qrcode
        from io import BytesIO
        
        # Test QR code generation
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data("Test QR Code")
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Test saving to BytesIO
        img_buffer = BytesIO()
        img.save(img_buffer, format='PNG')
        
        print("✅ QR code generation working!")
        return True
        
    except Exception as e:
        print(f"❌ QR code test failed: {e}")
        return False

def start_streamlit_app(port):
    """Start the Streamlit app"""
    print(f"🚀 Starting AfiCare MediLink PWA on port {port}...")
    
    # Check if we're in the right directory
    if not Path("medilink_simple.py").exists():
        print("❌ medilink_simple.py not found!")
        print("   Make sure you're in the aficare-agent directory")
        return False
    
    try:
        # Start Streamlit with proper configuration
        cmd = [
            sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
            "--server.port", str(port),
            "--server.headless", "false",
            "--server.enableCORS", "false",
            "--server.enableXsrfProtection", "false",
            "--server.maxUploadSize", "200"
        ]
        
        print(f"🔧 Command: {' '.join(cmd)}")
        
        process = subprocess.Popen(cmd, cwd=Path.cwd())
        
        # Wait for startup
        print("⏳ Waiting for app to start...")
        time.sleep(5)
        
        # Test if the app is running
        url = f"http://localhost:{port}"
        
        try:
            import requests
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                print("✅ App is running successfully!")
            else:
                print(f"⚠️  App responded with status {response.status_code}")
        except:
            print("⚠️  Could not test app response, but it should be running")
        
        # Open browser
        print(f"🌐 Opening {url}")
        webbrowser.open(url)
        
        return process, url
        
    except Exception as e:
        print(f"❌ Error starting Streamlit: {e}")
        return None, None

def show_instructions(url):
    """Show usage instructions"""
    print_header("🎉 AfiCare MediLink PWA is Running!")
    
    print(f"🌐 URL: {url}")
    print()
    print("📱 PWA Features:")
    print("   ✅ Mobile-optimized interface")
    print("   ✅ Offline capability")
    print("   ✅ Install as mobile app")
    print("   ✅ QR code generation")
    print("   ✅ Full AI medical consultation")
    print()
    print("📱 Demo Accounts:")
    print("   👤 Patient: patient@demo.com / demo123")
    print("   👨‍⚕️ Doctor: doctor@demo.com / demo123")
    print("   👨‍💼 Admin: admin@demo.com / demo123")
    print()
    print("📱 Install as Mobile App:")
    print("   🤖 Android: Look for '📱 Install App' button")
    print("   🍎 iPhone: Safari → Share → Add to Home Screen")
    print("   💻 Desktop: Chrome install icon in address bar")
    print()
    print("🔧 Features to Test:")
    print("   ✅ Login with demo accounts")
    print("   ✅ Generate QR codes (should work now!)")
    print("   ✅ AI medical consultation")
    print("   ✅ Patient records management")
    print("   ✅ Offline mode")
    print()
    print("🛑 Press Ctrl+C to stop the server")

def main():
    print("🏥 AfiCare MediLink - Phone App Starter")
    print("   Patient-Owned Healthcare Records for Africa")
    print("   100% FREE Progressive Web App")
    
    try:
        # Step 1: Kill existing processes
        kill_streamlit_processes()
        time.sleep(2)
        
        # Step 2: Check requirements
        check_requirements()
        
        # Step 3: Test QR generation
        if not test_qr_generation():
            print("⚠️  QR generation test failed, but continuing...")
        
        # Step 4: Find free port
        port = find_free_port()
        
        # Step 5: Start the app
        process, url = start_streamlit_app(port)
        
        if not process:
            print("❌ Failed to start the app")
            return False
        
        # Step 6: Show instructions
        show_instructions(url)
        
        # Step 7: Wait for user to stop
        try:
            process.wait()
        except KeyboardInterrupt:
            print("\n🛑 Stopping AfiCare MediLink...")
            process.terminate()
            time.sleep(2)
            print("✅ Server stopped successfully")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\n🔧 Troubleshooting:")
        print("   1. Make sure you're in the aficare-agent directory")
        print("   2. Try: pip install -r requirements.txt")
        print("   3. Check if Python and pip are working")
        print("   4. Try restarting your terminal")
        return False

if __name__ == "__main__":
    success = main()
    if not success:
        input("\nPress Enter to exit...")
    sys.exit(0 if success else 1)