"""
AfiCare Dev App Starter
Simple script to start the development app with proper error handling
"""

import subprocess
import sys
import os
from pathlib import Path

def main():
    print("🏥 Starting AfiCare Development App...\n")
    
    # Change to script directory
    os.chdir(Path(__file__).parent)
    
    # Kill any existing Streamlit processes
    try:
        if sys.platform == "win32":
            subprocess.run(
                ["taskkill", "/F", "/FI", "WINDOWTITLE eq streamlit*"],
                capture_output=True,
                timeout=3
            )
    except:
        pass
    
    # Start on a different port to avoid conflicts
    port = 8505
    
    print(f"📱 Starting on port {port}...")
    print(f"🌐 Local URL: http://localhost:{port}")
    print(f"📱 Network URL: http://192.168.100.5:{port}\n")
    print("Press Ctrl+C to stop\n")
    
    cmd = [
        sys.executable, "-m", "streamlit", "run",
        "src/ui/app.py",
        "--server.port", str(port),
        "--server.address", "0.0.0.0",
        "--server.headless", "false"
    ]
    
    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\n✅ App stopped")

if __name__ == "__main__":
    main()
