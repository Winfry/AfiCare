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
import os
from pathlib import Path

def kill_streamlit_processes():
    """Kill any existing Streamlit processes"""
    killed = 0
    try:
        if os.name == 'nt':  # Windows
            result = os.system('taskkill /f /im python.exe /fi "WINDOWTITLE eq streamlit*" >nul 2>&1')
            if result == 0:
                killed = 1
                print("   🔄 Killed existing Streamlit processes")
        else:  # Unix-like
            result = os.system('pkill -f streamlit')
            if result == 0:
                killed = 1
                print("   🔄 Killed existing Streamlit processes")
    except:
        pass
    
    if killed > 0:
        time.sleep(2)  # Wait for processes to fully terminate
    
    return killed

def find_free_port():
    """Find a free port from a list of preferred ports"""
    
    # Expanded list with more uncommon ports to avoid conflicts
    preferred_ports = [7000, 8888, 9999, 4000, 6000, 5555, 3333, 8765, 9876, 8090, 9000, 5000, 3000, 8080]
    
    for port in preferred_ports:
        try:
            # More thorough port checking
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                s.bind(('localhost', port))
                s.listen(1)
                
                # Additional check - try to bind again immediately
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s2:
                    s2.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    s2.bind(('localhost', port))
                    print(f"   ✓ Port {port} is available")
                    return port
                        
        except OSError as e:
            print(f"   ✗ Port {port} is in use")
            continue
    
    return None

def main():
    print("🏥 AfiCare MediLink Launcher")
    print("=" * 50)
    print()
    
    # Kill existing Streamlit processes first
    print("🔄 Cleaning up existing processes...")
    kill_streamlit_processes()
    
    # Find available port
    print("🔍 Checking available ports...")
    port = find_free_port()
    
    if not port:
        print("\n❌ Could not find an available port!")
        print("💡 All common ports are in use")
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
        # Start Streamlit with explicit configuration
        cmd = [
            sys.executable, "-m", "streamlit", "run", 
            str(app_file),
            "--server.port", str(port),
            "--server.address", "localhost",
            "--server.headless", "true",
            "--browser.gatherUsageStats", "false",
            "--server.enableCORS", "false",
            "--server.enableXsrfProtection", "false"
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