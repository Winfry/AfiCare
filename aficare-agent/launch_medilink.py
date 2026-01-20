#!/usr/bin/env python3
"""
MediLink Launcher - Automatically finds available port and starts the app
Works around Windows port permission issues
"""

import socket
import subprocess
import sys
import webbrowser
import time
from pathlib import Path

def find_free_port(preferred_ports=None):
    """Find a free port from a list of preferred ports"""
    
    if preferred_ports is None:
        preferred_ports = [8080, 8090, 9000, 3000, 5000, 7000, 8888, 9999, 4000, 6000]
    
    for port in preferred_ports:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                print(f"   ✓ Port {port} is available")
                return port
        except OSError:
            print(f"   ✗ Port {port} is in use")
            continue
    
    return None

def main():
    print("🏥 AfiCare MediLink Launcher")
    print("=" * 50)
    print()
    
    # Find available port
    print("🔍 Checking available ports...")
    port = find_free_port()
    
    if not port:
        print("\n❌ Could not find an available port!")
        print("💡 All common ports (8080, 8090, 9000, 3000, 5000, 7000, 8888, 9999, 4000, 6000) are in use")
        print("💡 Try closing other applications or running as administrator")
        input("Press Enter to exit...")
        return
    
    print(f"\n✅ Selected port: {port}")
    print()
    
    # Check if medilink_simple.py exists
    app_file = Path("medilink_simple.py")
    if not app_file.exists():
        print("❌ medilink_simple.py not found!")
        print("💡 Make sure you're running this from the aficare-agent directory")
        input("Press Enter to exit...")
        return
    
    print(f"🚀 Starting MediLink on port {port}...")
    print(f"🌐 Your app will be available at: http://localhost:{port}")
    print()
    print("📱 Demo Accounts:")
    print("   Patient: username=patient_demo, password=demo123")
    print("   Doctor:  username=dr_demo, password=demo123")
    print("   Admin:   username=admin_demo, password=demo123")
    print()
    print("⏹️  Press Ctrl+C to stop the server")
    print("=" * 50)
    
    try:
        # Start Streamlit
        cmd = [
            sys.executable, "-m", "streamlit", "run", 
            str(app_file),
            "--server.port", str(port),
            "--server.address", "localhost",
            "--server.headless", "true",
            "--browser.gatherUsageStats", "false"
        ]
        
        # Open browser after a short delay
        def open_browser():
            time.sleep(3)
            webbrowser.open(f"http://localhost:{port}")
        
        import threading
        browser_thread = threading.Thread(target=open_browser)
        browser_thread.daemon = True
        browser_thread.start()
        
        # Run Streamlit
        subprocess.run(cmd)
        
    except KeyboardInterrupt:
        print("\n🛑 MediLink stopped by user")
    except Exception as e:
        print(f"\n❌ Error starting MediLink: {e}")
        print("💡 Make sure Streamlit is installed: pip install streamlit")
    
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()