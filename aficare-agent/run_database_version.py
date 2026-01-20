#!/usr/bin/env python3
"""
Launch AfiCare MediLink Database Version
This version uses SQLite for persistent data storage
"""

import subprocess
import sys
import os
from pathlib import Path

def main():
    """Launch the database version of MediLink"""
    
    print("🏥 Starting AfiCare MediLink (Database Version)...")
    print("💾 This version uses SQLite for persistent data storage")
    print("✅ User accounts and consultations will survive app restarts")
    print("-" * 60)
    
    # Get the directory containing this script
    script_dir = Path(__file__).parent
    
    # Path to the database version
    app_path = script_dir / "medilink_simple.py"
    
    if not app_path.exists():
        print(f"❌ Error: {app_path} not found!")
        return 1
    
    # Change to the script directory
    os.chdir(script_dir)
    
    try:
        # Run streamlit with the database version
        cmd = [sys.executable, "-m", "streamlit", "run", str(app_path), "--server.port=8501"]
        
        print(f"🚀 Running command: {' '.join(cmd)}")
        print("📱 The app will open in your browser automatically")
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