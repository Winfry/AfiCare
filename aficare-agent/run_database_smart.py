#!/usr/bin/env python3
"""
Smart launcher for AfiCare MediLink Database Version
Automatically finds available ports to avoid Windows permission issues
"""

import subprocess
import sys
import os
import socket
from pathlib import Path

def find_available_port(start_port=8503, max_attempts=100):
    """Find an available port starting from start_port"""
    
    for port in range(start_port, start_port + max_attempts):
        try:
            # Try to bind to the port
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return port
        except OSError:
            continue  # Port is in use, try next one
    
    return None

def main():
    """Launch the database version of MediLink with automatic port detection"""
    
    print("🏥 Starting AfiCare MediLink (Database Version)...")
    print("💾 This version uses SQLite for persistent data storage")
    print("✅ User accounts and consultations will survive app restarts")
    print("🔍 Searching for available port...")
    print("-" * 60)
    
    # Find available port
    port = find_available_port(start_port=9000)  # Try higher ports
    
    if port is None:
        print("❌ Error: Could not find an available port!")
        print("💡 Try closing other applications that might be using ports 9000-9100")
        return 1
    
    print(f"✅ Found available port: {port}")
    
    # Get the directory containing this script
    script_dir = Path(__file__).parent
    
    # Path to the database-enhanced version
    app_path = script_dir / "medilink_with_database.py"
    
    if not app_path.exists():
        print(f"❌ Error: {app_path} not found!")
        return 1
    
    # Change to the script directory
    os.chdir(script_dir)
    
    try:
        # Run streamlit with the found port
        cmd = [sys.executable, "-m", "streamlit", "run", str(app_path), f"--server.port={port}"]
        
        print(f"🚀 Running command: {' '.join(cmd)}")
        print(f"📱 The app will open at: http://localhost:{port}")
        print("🔄 Press Ctrl+C to stop the application")
        print("-" * 60)
        
        # Run the command
        result = subprocess.run(cmd, check=True)
        return result.returncode
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running application: {e}")
        return 1
    except KeyboardInterrupt:
        print("\n👋 Application stopped by user")
        return 0
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)