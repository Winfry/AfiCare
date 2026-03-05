"""
AfiCare Issue Diagnostic Tool
Checks all components and identifies problems
"""

import sys
import os
import json
from pathlib import Path

def print_section(title):
    print("\n" + "="*60)
    print(f"  {title}")
    print("="*60)

def check_python_version():
    print_section("🐍 PYTHON VERSION")
    print(f"Python: {sys.version}")
    if sys.version_info >= (3, 8):
        print("✅ Python version OK")
        return True
    else:
        print("❌ Python 3.8+ required")
        return False

def check_dependencies():
    print_section("📦 DEPENDENCIES")
    
    required = {
        'streamlit': 'Streamlit',
        'asyncio': 'Asyncio',
        'pathlib': 'Pathlib'
    }
    
    all_ok = True
    for module, name in required.items():
        try:
            __import__(module)
            print(f"✅ {name}")
        except ImportError:
            print(f"❌ {name} - NOT INSTALLED")
            all_ok = False
    
    # Optional dependencies
    optional = {
        'llama_cpp': 'llama-cpp-python (LLM support)',
    }
    
    print("\nOptional:")
    for module, name in optional.items():
        try:
            __import__(module)
            print(f"✅ {name}")
        except ImportError:
            print(f"⚠️  {name} - Not installed (optional)")
    
    return all_ok

def check_json_files():
    print_section("📄 JSON KNOWLEDGE BASE FILES")
    
    kb_path = Path("data/knowledge_base/conditions")
    
    if not kb_path.exists():
        print(f"❌ Knowledge base directory not found: {kb_path}")
        return False
    
    json_files = list(kb_path.glob("*.json"))
    
    if not json_files:
        print(f"⚠️  No JSON files found in {kb_path}")
        return False
    
    issues = []
    for json_file in json_files:
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Check if file has content
            if not data:
                issues.append(f"❌ {json_file.name} - Empty file")
            else:
                print(f"✅ {json_file.name}")
        except json.JSONDecodeError as e:
            issues.append(f"❌ {json_file.name} - Invalid JSON: {e}")
        except Exception as e:
            issues.append(f"❌ {json_file.name} - Error: {e}")
    
    if issues:
        print("\nIssues found:")
        for issue in issues:
            print(issue)
        return False
    
    print(f"\n✅ All {len(json_files)} JSON files are valid")
    return True

def check_config_files():
    print_section("⚙️  CONFIGURATION FILES")
    
    config_files = [
        "config/default.yaml",
        "config/clinic_config.yaml",
        "config/languages.yaml"
    ]
    
    all_ok = True
    for config_file in config_files:
        path = Path(config_file)
        if path.exists():
            print(f"✅ {config_file}")
        else:
            print(f"❌ {config_file} - NOT FOUND")
            all_ok = False
    
    return all_ok

def check_database_files():
    print_section("💾 DATABASE FILES")
    
    db_files = [
        "aficare.db",
        "aficare_enhanced.db",
        "aficare_medilink.db"
    ]
    
    for db_file in db_files:
        path = Path(db_file)
        if path.exists():
            size = path.stat().st_size / 1024  # KB
            print(f"✅ {db_file} ({size:.1f} KB)")
        else:
            print(f"⚠️  {db_file} - Will be created on first run")
    
    return True

def check_source_structure():
    print_section("📁 SOURCE CODE STRUCTURE")
    
    required_dirs = [
        "src/core",
        "src/llm",
        "src/rules",
        "src/memory",
        "src/ui",
        "src/utils"
    ]
    
    all_ok = True
    for dir_path in required_dirs:
        path = Path(dir_path)
        if path.exists() and path.is_dir():
            print(f"✅ {dir_path}/")
        else:
            print(f"❌ {dir_path}/ - NOT FOUND")
            all_ok = False
    
    return all_ok

def check_main_app():
    print_section("🎯 MAIN APPLICATION FILE")
    
    app_file = Path("src/ui/app.py")
    
    if not app_file.exists():
        print(f"❌ {app_file} - NOT FOUND")
        return False
    
    print(f"✅ {app_file} exists")
    
    # Try to import it
    try:
        sys.path.insert(0, str(Path("src").absolute()))
        from ui import app
        print("✅ App imports successfully")
        return True
    except Exception as e:
        print(f"❌ Import error: {e}")
        return False

def check_ports():
    print_section("🔌 PORT AVAILABILITY")
    
    import socket
    
    ports_to_check = [8501, 8502, 8503, 8504, 8505]
    available_ports = []
    
    for port in ports_to_check:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('', port))
                print(f"✅ Port {port} - Available")
                available_ports.append(port)
        except OSError:
            print(f"❌ Port {port} - In use or blocked")
    
    if available_ports:
        print(f"\n✅ {len(available_ports)} ports available")
        return True
    else:
        print("\n❌ No ports available!")
        return False

def main():
    print("""
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║          🏥 AfiCare Diagnostic Tool                     ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
""")
    
    # Change to script directory
    os.chdir(Path(__file__).parent)
    
    results = {
        "Python Version": check_python_version(),
        "Dependencies": check_dependencies(),
        "JSON Files": check_json_files(),
        "Config Files": check_config_files(),
        "Database Files": check_database_files(),
        "Source Structure": check_source_structure(),
        "Main App": check_main_app(),
        "Port Availability": check_ports()
    }
    
    # Summary
    print_section("📊 DIAGNOSTIC SUMMARY")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for check, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {check}")
    
    print(f"\n{'='*60}")
    print(f"  Result: {passed}/{total} checks passed")
    print(f"{'='*60}")
    
    if passed == total:
        print("\n🎉 All checks passed! Your app should run fine.")
        print("\n💡 To start the app, run:")
        print("   python start_dev_app.py")
    else:
        print("\n⚠️  Some issues found. Please fix them before running the app.")
    
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()
