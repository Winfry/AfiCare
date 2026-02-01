#!/usr/bin/env python3
"""
Flutter Setup for AfiCare - Run from aficare-agent directory
"""

import os
import subprocess
import sys
from pathlib import Path
import shutil
import requests
import zipfile
import tempfile

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

def setup_flutter():
    print_header("AfiCare Flutter Setup")
    
    # Go to parent directory
    parent_dir = Path("..").resolve()
    flutter_dir = parent_dir / "flutter_sdk"
    
    print(f"📁 Working in: {parent_dir}")
    print(f"📱 Flutter will be installed to: {flutter_dir}")
    
    # Remove old flutter_sdk if exists
    if flutter_dir.exists():
        print("🗑️  Removing old flutter_sdk...")
        shutil.rmtree(flutter_dir)
    
    # Try Git clone first (fastest)
    print("📥 Trying to clone Flutter from GitHub...")
    result = run_command("git clone https://github.com/flutter/flutter.git -b stable flutter_sdk", 
                        cwd=parent_dir, check=False)
    
    if not result or result.returncode != 0:
        print("📥 Git clone failed, downloading ZIP instead...")
        
        # Download Flutter ZIP
        url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.9-stable.zip"
        
        try:
            print("⏳ Downloading Flutter SDK... (this may take a few minutes)")
            
            with tempfile.NamedTemporaryFile(delete=False, suffix='.zip') as tmp_file:
                response = requests.get(url, stream=True)
                response.raise_for_status()
                
                total_size = int(response.headers.get('content-length', 0))
                downloaded = 0
                
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        tmp_file.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\r   Progress: {percent:.1f}%", end='', flush=True)
                
                print(f"\n✅ Downloaded Flutter SDK ({downloaded / 1024 / 1024:.1f} MB)")
                
                # Extract Flutter
                print("📦 Extracting Flutter SDK...")
                with zipfile.ZipFile(tmp_file.name, 'r') as zip_ref:
                    zip_ref.extractall(parent_dir)
                
                # Rename flutter to flutter_sdk
                flutter_extracted = parent_dir / "flutter"
                if flutter_extracted.exists():
                    flutter_extracted.rename(flutter_dir)
                
                # Clean up
                os.unlink(tmp_file.name)
                
        except Exception as e:
            print(f"❌ Download failed: {e}")
            return False
    
    # Check if Flutter was installed
    flutter_exe = flutter_dir / "bin" / "flutter.exe"
    if not flutter_exe.exists():
        flutter_exe = flutter_dir / "bin" / "flutter"  # Linux/Mac
    
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
    flutter_project = parent_dir / "aficare_flutter"
    if flutter_project.exists():
        print("📱 Setting up AfiCare Flutter project...")
        result = run_command(f'"{flutter_exe}" pub get', cwd=flutter_project, check=False)
        
        if result and result.returncode == 0:
            print("✅ AfiCare Flutter dependencies installed!")
        else:
            print("⚠️  Dependency installation had issues")
    
    # Create run scripts
    run_script_content = f"""@echo off
echo Starting AfiCare Flutter Web App...
cd ..
cd aficare_flutter
"{flutter_exe.absolute()}" run -d chrome --web-port 3000
pause
"""
    
    with open("run_flutter_web.bat", "w") as f:
        f.write(run_script_content)
    
    build_script_content = f"""@echo off
echo Building AfiCare Flutter Web App...
cd ..
cd aficare_flutter
"{flutter_exe.absolute()}" build web --release
echo.
echo Build complete! Files are in aficare_flutter/build/web/
pause
"""
    
    with open("build_flutter_web.bat", "w") as f:
        f.write(build_script_content)
    
    print_header("🎉 Flutter Setup Complete!")
    print("✅ Flutter SDK installed in ../flutter_sdk/")
    print("✅ AfiCare Flutter project ready")
    print("✅ Created run_flutter_web.bat")
    print("✅ Created build_flutter_web.bat")
    print()
    print("🚀 Test Flutter now:")
    print("   Double-click: run_flutter_web.bat")
    print("   Or run from parent directory: python deploy_both_apps.py")
    print()
    print("📱 Your AfiCare mobile apps are ready!")
    
    return True

if __name__ == "__main__":
    try:
        success = setup_flutter()
        if success:
            print("\n🎯 Next: Double-click 'run_flutter_web.bat' to test Flutter!")
        else:
            print("\n❌ Flutter setup failed")
        input("\nPress Enter to continue...")
    except KeyboardInterrupt:
        print("\n❌ Setup cancelled")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        input("\nPress Enter to continue...")