#!/usr/bin/env python3
"""
AfiCare - Fix Issues and Start
Solves port conflicts and starts the app properly
"""

import subprocess
import sys
import time
import webbrowser
from pathlib import Path

def kill_streamlit_processes():
    """Kill any existing Streamlit processes"""
    print("🔧 Checking for existing Streamlit processes...")
    
    try:
        # Windows
        result = subprocess.run(
            ["taskkill", "/F", "/IM", "streamlit.exe"], 
            capture_output=True, text=True, check=False
        )
        if result.returncode == 0:
            print("✅ Killed existing Streamlit processes")
        else:
            print("ℹ️  No existing Streamlit processes found")
    except FileNotFoundError:
        # Unix/Linux/Mac
        try:
            subprocess.run(["pkill", "-f", "streamlit"], check=False)
            print("✅ Killed existing Streamlit processes")
        except:
            print("ℹ️  No existing Streamlit processes found")

def find_free_port():
    """Find a free port to use"""
    import socket
    
    ports_to_try = [8503, 8504, 8505, 8506, 8507]
    
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

def test_requirements():
    """Test if requirements are installed"""
    print("📦 Checking requirements...")
    
    try:
        import streamlit
        print("✅ Streamlit installed")
    except ImportError:
        print("❌ Streamlit not found. Installing...")
        subprocess.run([sys.executable, "-m", "pip", "install", "streamlit"])
    
    try:
        import qrcode
        print("✅ QR code library installed")
    except ImportError:
        print("❌ QR code library not found. Installing...")
        subprocess.run([sys.executable, "-m", "pip", "install", "qrcode[pil]"])

def start_streamlit(port):
    """Start Streamlit on specified port"""
    print(f"🚀 Starting AfiCare MediLink on port {port}...")
    
    try:
        # Start Streamlit
        process = subprocess.Popen([
            sys.executable, "-m", "streamlit", "run", "medilink_simple.py",
            "--server.port", str(port),
            "--server.headless", "false",
            "--server.enableCORS", "false",
            "--server.enableXsrfProtection", "false"
        ])
        
        # Wait a moment for startup
        time.sleep(3)
        
        # Open browser
        url = f"http://localhost:{port}"
        print(f"🌐 Opening {url}")
        webbrowser.open(url)
        
        print("\n🎉 AfiCare MediLink is running!")
        print(f"   URL: {url}")
        print("   📱 PWA features enabled - you can install this as an app!")
        print("\n📱 Demo Accounts:")
        print("   Patient: patient@demo.com / demo123")
        print("   Doctor: doctor@demo.com / demo123")
        print("   Admin: admin@demo.com / demo123")
        print("\n📱 To install as mobile app:")
        print("   • Android: Look for '📱 Install App' button")
        print("   • iPhone: Safari → Share → Add to Home Screen")
        print("   • Desktop: Chrome install icon in address bar")
        print("\nPress Ctrl+C to stop the server")
        
        # Wait for user to stop
        try:
            process.wait()
        except KeyboardInterrupt:
            print("\n🛑 Stopping AfiCare MediLink...")
            process.terminate()
            print("✅ Server stopped")
        
        return True
        
    except Exception as e:
        print(f"❌ Error starting Streamlit: {e}")
        return False

def main():
    print("🔧 AfiCare MediLink - Fix and Start")
    print("=" * 50)
    
    # Check if we're in the right directory
    if not Path("medilink_simple.py").exists():
        print("❌ Please run this from the aficare-agent directory")
        print("   cd aficare-agent")
        print("   python fix_and_start.py")
        sys.exit(1)
    
    # Kill existing processes
    kill_streamlit_processes()
    
    # Wait a moment
    time.sleep(2)
    
    # Test requirements
    test_requirements()
    
    # Find free port
    port = find_free_port()
    
    # Start Streamlit
    success = start_streamlit(port)
    
    if not success:
        print("\n🔧 Troubleshooting:")
        print("   1. Try running: pip install -r requirements.txt")
        print("   2. Check if Python is properly installed")
        print("   3. Try restarting your terminal")

if __name__ == "__main__":
    main()