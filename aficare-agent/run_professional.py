#!/usr/bin/env python3
"""
Professional launcher for AfiCare MediLink Professional Version
Beautiful, modern medical application with cost-free deployment
"""

import subprocess
import sys
import os
import random
from pathlib import Path

def main():
    """Launch the professional version of MediLink"""
    
    print("🏥 Starting AfiCare MediLink Professional...")
    print("✨ Beautiful Design • Advanced Features • Cost-Free Forever")
    print("💾 Enhanced database with audit trails and data export")
    print("-" * 60)
    
    # Use a random high port to avoid conflicts
    port = random.randint(9000, 9999)
    print(f"🎯 Using port: {port}")
    
    # Get the directory containing this script
    script_dir = Path(__file__).parent
    
    # Path to the professional version
    app_path = script_dir / "medilink_professional.py"
    
    if not app_path.exists():
        print(f"❌ Error: {app_path} not found!")
        return 1
    
    # Change to the script directory
    os.chdir(script_dir)
    
    try:
        # Run streamlit with the random port
        cmd = [sys.executable, "-m", "streamlit", "run", str(app_path), f"--server.port={port}"]
        
        print(f"🚀 Running command: {' '.join(cmd)}")
        print(f"📱 The app will open at: http://localhost:{port}")
        print("🎨 Professional medical theme with beautiful visuals")
        print("🔄 Press Ctrl+C to stop the application")
        print("-" * 60)
        
        # Run the command
        result = subprocess.run(cmd, check=True)
        return result.returncode
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running application: {e}")
        print(f"💡 If port {port} is blocked, try running the script again for a different port")
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