#!/usr/bin/env python3
"""
Launch script for AfiCare MediLink Professional (Fixed Version)
Beautiful, modern medical application with cost-free deployment
"""

import subprocess
import sys
import random
from pathlib import Path

def find_available_port(start_port=9000, max_attempts=50):
    """Find an available port starting from start_port"""
    import socket
    
    for i in range(max_attempts):
        port = start_port + i
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return port
        except OSError:
            continue
    
    # If no port found in range, use random high port
    return random.randint(10000, 65000)

def main():
    """Launch the professional MediLink application"""
    
    print("🏥 Starting AfiCare MediLink Professional (Fixed Version)...")
    print("✨ Beautiful Design • Advanced Features • Cost-Free Forever")
    print("💾 Enhanced database with audit trails and data export")
    print("-" * 60)
    
    # Find available port
    port = find_available_port()
    print(f"🎯 Using port: {port}")
    
    # Get the directory of this script
    script_dir = Path(__file__).parent
    app_file = script_dir / "medilink_professional_fixed.py"
    
    # Build the command
    python_executable = sys.executable
    command = [
        python_executable, "-m", "streamlit", "run", 
        str(app_file), 
        f"--server.port={port}"
    ]
    
    print(f"🚀 Running command: {' '.join(command)}")
    print(f"📱 The app will open at: http://localhost:{port}")
    print("🎨 Professional medical theme with beautiful visuals")
    print("🔄 Press Ctrl+C to stop the application")
    print("-" * 60)
    
    try:
        # Run the Streamlit app
        subprocess.run(command, check=True)
    except KeyboardInterrupt:
        print("\n👋 Application stopped by user")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running application: {e}")
        print("💡 Try running manually: streamlit run medilink_professional_fixed.py")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

if __name__ == "__main__":
    main()