"""
AfiCare - Fix and Run Script
Diagnoses and fixes common issues, then starts the app
"""

import subprocess
import sys
import socket
import os
from pathlib import Path

def print_header(text):
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60 + "\n")

def check_port_available(port):
    """Check if a port is available"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', port))
            return True
    except OSError:
        return False

def find_available_port(start_port=8501, max_attempts=10):
    """Find an available port"""
    for port in range(start_port, start_port + max_attempts):
        if check_port_available(port):
            return port
    return None

def kill_streamlit_processes():
    """Kill any existing Streamlit processes"""
    try:
        if sys.platform == "win32":
            subprocess.run(
                ["taskkill", "/F", "/IM", "streamlit.exe"],
                capture_output=True,
                timeout=5
            )
            subprocess.run(
                ["taskkill", "/F", "/FI", "WINDOWTITLE eq streamlit*"],
                capture_output=True,
                timeout=5
            )
        else:
            subprocess.run(["pkill", "-f", "streamlit"], capture_output=True)
        print("✅ Cleared existing Streamlit processes")
    except Exception as e:
        print(f"⚠️  Could not kill processes: {e}")

def check_json_files():
    """Check if JSON knowledge base files are valid"""
    print_header("🔍 CHECKING KNOWLEDGE BASE FILES")
    
    kb_path = Path("data/knowledge_base/conditions")
    if not kb_path.exists():
        print(f"❌ Knowledge base path not found: {kb_path}")
        return False
    
    issues = []
    for json_file in kb_path.glob("*.json"):
        try:
            import json
            with open(json_file, 'r', encoding='utf-8') as f:
                json.load(f)
            print(f"✅ {json_file.name}")
        except Exception as e:
            issues.append(f"❌ {json_file.name}: {str(e)}")
            print(f"❌ {json_file.name}: {str(e)}")
    
    if issues:
        print(f"\n⚠️  Found {len(issues)} JSON file issues")
        return False
    
    print("\n✅ All JSON files are valid")
    return True

def main():
    print_header("🏥 AfiCare - Diagnostic and Fix Tool")
    
    # Change to aficare-agent directory
    os.chdir(Path(__file__).parent)
    
    # Step 1: Kill existing processes
    print_header("🔧 STEP 1: Clearing Existing Processes")
    kill_streamlit_processes()
    
    # Step 2: Check JSON files
    check_json_files()
    
    # Step 3: Find available port
    print_header("🔧 STEP 2: Finding Available Port")
    port = find_available_port(8501)
    
    if not port:
        print("❌ No available ports found between 8501-8510")
        print("\n💡 Try closing other applications or restart your computer")
        input("\nPress Enter to exit...")
        return
    
    print(f"✅ Found available port: {port}")
    
    # Step 4: Check Python and Streamlit
    print_header("🔧 STEP 3: Checking Dependencies")
    
    try:
        import streamlit
        print(f"✅ Streamlit {streamlit.__version__} installed")
    except ImportError:
        print("❌ Streamlit not installed")
        print("Run: pip install streamlit")
        input("\nPress Enter to exit...")
        return
    
    # Step 5: Start the app
    print_header(f"🚀 STARTING AFICARE ON PORT {port}")
    
    print(f"""
📱 Access URLs:
   Local:    http://localhost:{port}
   Network:  http://192.168.100.5:{port}

🔧 To stop: Press Ctrl+C

""")
    
    # Run Streamlit
    cmd = [
        sys.executable, "-m", "streamlit", "run",
        "src/ui/app.py",
        "--server.port", str(port),
        "--server.address", "0.0.0.0",
        "--server.headless", "false",
        "--server.enableCORS", "false",
        "--server.enableXsrfProtection", "false"
    ]
    
    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\n\n✅ AfiCare stopped successfully")
    except Exception as e:
        print(f"\n❌ Error starting app: {e}")
        input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()
