#!/usr/bin/env python3
"""
AfiCare MediLink - Simple Deployment Script
Run this from the aficare-agent directory
"""

import os
import subprocess
import sys
from pathlib import Path

def print_header(title):
    print(f"\n{'='*50}")
    print(f"  {title}")
    print(f"{'='*50}")

def run_command(command, check=True):
    """Run a shell command"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=check)
        if result.stdout:
            print(result.stdout)
        return result
    except subprocess.CalledProcessError as e:
        print(f"❌ Command failed: {command}")
        print(f"Error: {e.stderr}")
        if check:
            return None
        return e

def main():
    print_header("AfiCare MediLink - Quick Deployment")
    
    # Check if we're in the right directory
    if not Path("medilink_simple.py").exists():
        print("❌ Please run this script from the aficare-agent directory")
        print("   cd aficare-agent")
        print("   python deploy_aficare.py")
        sys.exit(1)
    
    print("🏥 AfiCare MediLink - Patient-Owned Healthcare Records")
    print("   100% FREE and Open Source")
    
    # 1. Test the backend
    print_header("Testing Backend")
    print("🧪 Testing AfiCare AI Agent...")
    result = run_command("python test_full_ai_agent.py", check=False)
    if result and result.returncode == 0:
        print("✅ Backend AI tests passed!")
    else:
        print("⚠️  Backend tests had issues, but continuing...")
    
    # 2. Start the Streamlit app
    print_header("Starting Streamlit Backend")
    print("🚀 Starting AfiCare MediLink on port 8502...")
    print("   This will open your browser automatically")
    print("   Use Ctrl+C to stop the server")
    print()
    print("📱 Demo Accounts:")
    print("   Patient: patient@demo.com / demo123")
    print("   Doctor: doctor@demo.com / demo123") 
    print("   Admin: admin@demo.com / demo123")
    print()
    print("🌐 Access URLs:")
    print("   Local: http://localhost:8502")
    print("   Network: http://192.168.1.128:8502 (if available)")
    print()
    
    try:
        # Start Streamlit
        subprocess.run([
            "streamlit", "run", "medilink_simple.py", 
            "--server.port", "8502",
            "--server.headless", "false"
        ], check=True)
    except KeyboardInterrupt:
        print("\n✅ AfiCare MediLink stopped by user")
    except FileNotFoundError:
        print("❌ Streamlit not found. Installing...")
        run_command("pip install streamlit")
        print("✅ Streamlit installed. Please run the script again.")
    except Exception as e:
        print(f"❌ Error starting Streamlit: {e}")
        print("\n🔧 Troubleshooting:")
        print("   1. Install requirements: pip install -r requirements.txt")
        print("   2. Try different port: streamlit run medilink_simple.py --server.port 8503")
        print("   3. Check if port 8502 is already in use")

if __name__ == "__main__":
    main()