"""
🏥 AfiCare - One-Click Starter
Complete diagnostic, fix, and launch script
"""

import subprocess
import sys
import os
import socket
import json
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_header(text, color=Colors.BLUE):
    print(f"\n{color}{Colors.BOLD}{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}{Colors.END}\n")

def print_success(text):
    print(f"{Colors.GREEN}✅ {text}{Colors.END}")

def print_error(text):
    print(f"{Colors.RED}❌ {text}{Colors.END}")

def print_warning(text):
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.END}")

def print_info(text):
    print(f"{Colors.BLUE}ℹ️  {text}{Colors.END}")

def check_port(port):
    """Check if port is available"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', port))
            return True
    except OSError:
        return False

def find_available_port(start=8501, end=8510):
    """Find first available port in range"""
    for port in range(start, end + 1):
        if check_port(port):
            return port
    return None

def kill_streamlit():
    """Kill existing Streamlit processes"""
    try:
        if sys.platform == "win32":
            subprocess.run(
                ["taskkill", "/F", "/FI", "WINDOWTITLE eq streamlit*"],
                capture_output=True,
                timeout=3
            )
        else:
            subprocess.run(["pkill", "-f", "streamlit"], capture_output=True)
        return True
    except:
        return False

def check_json_files():
    """Validate JSON knowledge base files"""
    kb_path = Path("data/knowledge_base/conditions")
    
    if not kb_path.exists():
        return False, []
    
    issues = []
    valid_count = 0
    
    for json_file in kb_path.glob("*.json"):
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            if data:
                valid_count += 1
            else:
                issues.append(f"{json_file.name} is empty")
        except Exception as e:
            issues.append(f"{json_file.name}: {str(e)}")
    
    return valid_count > 0, issues

def check_dependencies():
    """Check if required packages are installed"""
    required = ['streamlit']
    missing = []
    
    for package in required:
        try:
            __import__(package)
        except ImportError:
            missing.append(package)
    
    return len(missing) == 0, missing

def main():
    # ASCII Art Header
    print(f"""
{Colors.GREEN}{Colors.BOLD}
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║          🏥 AfiCare Medical Agent                       ║
║          One-Click Diagnostic & Launcher                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
{Colors.END}
""")
    
    # Change to script directory
    os.chdir(Path(__file__).parent)
    
    # Step 1: Check Dependencies
    print_header("📦 CHECKING DEPENDENCIES")
    deps_ok, missing = check_dependencies()
    
    if deps_ok:
        print_success("All required packages installed")
    else:
        print_error(f"Missing packages: {', '.join(missing)}")
        print_info("Install with: pip install " + " ".join(missing))
        input("\nPress Enter to exit...")
        return
    
    # Step 2: Check JSON Files
    print_header("📄 VALIDATING KNOWLEDGE BASE")
    json_ok, json_issues = check_json_files()
    
    if json_ok:
        print_success("Knowledge base files validated")
        if json_issues:
            print_warning(f"{len(json_issues)} files have issues (will be skipped)")
    else:
        print_warning("Some knowledge base files have issues")
        print_info("App will still work with available files")
    
    # Step 3: Kill Existing Processes
    print_header("🔧 CLEARING EXISTING PROCESSES")
    if kill_streamlit():
        print_success("Cleared existing Streamlit processes")
    else:
        print_info("No existing processes found")
    
    # Step 4: Find Available Port
    print_header("🔌 FINDING AVAILABLE PORT")
    port = find_available_port()
    
    if not port:
        print_error("No available ports found (8501-8510)")
        print_info("Try closing other applications or restart your computer")
        input("\nPress Enter to exit...")
        return
    
    print_success(f"Found available port: {port}")
    
    # Step 5: Get Network IP
    try:
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
    except:
        local_ip = "localhost"
    
    # Step 6: Display Access Info
    print_header("🚀 STARTING AFICARE", Colors.GREEN)
    
    print(f"""
{Colors.BOLD}📱 Access URLs:{Colors.END}
   
   {Colors.GREEN}Local:{Colors.END}    http://localhost:{port}
   {Colors.BLUE}Network:{Colors.END}  http://{local_ip}:{port}
   
{Colors.BOLD}👤 Demo Accounts:{Colors.END}
   
   Patient:  patient@demo.com / demo123
   Doctor:   doctor@demo.com / demo123
   Admin:    admin@demo.com / demo123

{Colors.BOLD}🔧 Features:{Colors.END}
   
   ✅ Patient consultations
   ✅ AI-powered triage
   ✅ Condition matching
   ✅ Treatment recommendations
   ✅ Medical knowledge base
   
{Colors.YELLOW}⚠️  Note: LLM features disabled (optional){Colors.END}
   App uses rule-based engine for diagnoses
   
{Colors.BOLD}🛑 To stop: Press Ctrl+C{Colors.END}

""")
    
    input("Press Enter to start the app...")
    
    # Step 7: Start Streamlit
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
        print_info("Starting Streamlit server...")
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print(f"\n\n{Colors.GREEN}✅ AfiCare stopped successfully{Colors.END}")
    except Exception as e:
        print_error(f"Error starting app: {e}")
        input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()
