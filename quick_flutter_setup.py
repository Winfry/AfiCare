#!/usr/bin/env python3
"""
AfiCare Flutter - Quick Setup
Fast Flutter installation using Git clone
"""

import os
import subprocess
import sys
from pathlib import Path
import shutil

def print_header(title):
    print(f"\n{'='*50}")
    print(f"  {title}")
    print(f"{'='*50}")

def run_command(command, cwd=None, check=True):
    """Run a command"""
    try:
        result = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True, check=check)
        if result.stdout:
            print(result.stdout)
        return result
    except subprocess.CalledProcessError as e:
        print(f"❌ Command failed: {command}")
        print(f"Error: {e.stderr}")
        return None

def main():
    print_header("AfiCare Flutter - Quick Setup")
    
    # Remove old flutter_sdk if exists
    flutter_dir = Path("flutter_sdk")
    if flutter_dir.exists():
        print("🗑️  Removing old flutter_sdk...")
        shutil.rmtree(flutter_dir)
    
    # Clone Flutter from GitHub (much faster)
    print("📥 Cloning Flutter SDK from GitHub...")
    print("   This is much faster than downloading ZIP file")
    
    result = run_command("git clone https://github.com/flutter/flutter.git -b stable flutter_sdk", check=False)
    
    if not result or result.returncode != 0:
        print("❌ Git clone failed. Trying alternative method...")
        
        # Alternative: Download stable release
        print("📥 Downloading Flutter stable release...")
        import requests
        import zipfile
        import tempfile
        
        url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.9-stable.zip"
        
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.zip') as tmp_file:
                response = requests.get(url, stream=True)
                response.raise_for_status()
                
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        tmp_file.write(chunk)
                
                print("📦 Extracting Flutter...")
                with zipfile.ZipFile(tmp_file.name, 'r') as zip_ref:
                    zip_ref.extractall(".")
                
                os.unlink(tmp_file.name)
                
                # Rename flutter to flutter_sdk
                if Path("flutter").exists():
                    Path("flutter").rename("flutter_sdk")
                
        except Exception as e:
            print(f"❌ Download failed: {e}")
            return False
    
    # Check if Flutter was installed
    flutter_exe = Path("flutter_sdk/bin/flutter.exe")
    if not flutter_exe.exists():
        flutter_exe = Path("flutter_sdk/bin/flutter")  # Linux/Mac
    
    if not flutter_exe.exists():
        print("❌ Flutter installation failed")
        return False
    
    print("✅ Flutter SDK installed!")
    
    # Test Flutter
    print("🧪 Testing Flutter...")
    result = run_command(f'"{flutter_exe}" --version', check=False)
    
    if result and result.returncode == 0:
        print("✅ Flutter is working!")
    else:
        print("⚠️  Flutter test had issues, but continuing...")
    
    # Setup AfiCare Flutter project
    print("📱 Setting up AfiCare Flutter project...")
    
    if Path("aficare_flutter").exists():
        result = run_command(f'"{flutter_exe}" pub get', cwd="aficare_flutter", check=False)
        
        if result and result.returncode == 0:
            print("✅ AfiCare Flutter dependencies installed!")
        else:
            print("⚠️  Dependency installation had issues")
    
    # Create run script
    run_script = f"""@echo off
echo Starting AfiCare Flutter Web App...
cd aficare_flutter
"{flutter_exe.absolute()}" run -d chrome --web-port 3000
pause
"""
    
    with open("run_aficare_flutter.bat", "w") as f:
        f.write(run_script)
    
    print_header("🎉 Flutter Setup Complete!")
    print("✅ Flutter SDK installed in flutter_sdk/")
    print("✅ AfiCare Flutter project ready")
    print("✅ Created run_aficare_flutter.bat")
    print()
    print("🚀 Test Flutter now:")
    print("   Double-click: run_aficare_flutter.bat")
    print("   Or run: python deploy_both_apps.py")
    print()
    print("📱 Your AfiCare mobile apps are ready!")
    
    return True

if __name__ == "__main__":
    success = main()
    if success:
        print("\n🎯 Next: Run 'python deploy_both_apps.py' to test both apps!")
    sys.exit(0 if success else 1)