#!/usr/bin/env python3
"""
AfiCare Flutter Setup - Complete Installation
Removes old Flutter, installs fresh for this project
"""

import os
import subprocess
import sys
import shutil
import requests
import zipfile
from pathlib import Path
import tempfile

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def run_command(command, cwd=None, check=True, shell=True):
    """Run a command and return result"""
    try:
        result = subprocess.run(
            command, 
            shell=shell, 
            cwd=cwd, 
            capture_output=True, 
            text=True, 
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        print(f"❌ Command failed: {command}")
        print(f"Error: {e.stderr}")
        return None

def remove_old_flutter():
    """Remove old Flutter installations"""
    print_header("Removing Old Flutter Installations")
    
    # Common Flutter installation paths
    flutter_paths = [
        Path.home() / "flutter",
        Path("C:/flutter"),
        Path("C:/tools/flutter"),
        Path("C:/src/flutter"),
        Path.home() / "AppData/Local/flutter",
        Path.home() / "Documents/flutter"
    ]
    
    removed_any = False
    
    for flutter_path in flutter_paths:
        if flutter_path.exists():
            print(f"🗑️  Removing old Flutter at: {flutter_path}")
            try:
                shutil.rmtree(flutter_path)
                print(f"✅ Removed: {flutter_path}")
                removed_any = True
            except Exception as e:
                print(f"⚠️  Could not remove {flutter_path}: {e}")
    
    if not removed_any:
        print("ℹ️  No old Flutter installations found")
    
    # Remove from PATH (Windows)
    print("🔧 Cleaning PATH environment variable...")
    try:
        # This will require manual PATH cleanup, but we'll show instructions
        print("⚠️  Please manually remove Flutter from your PATH:")
        print("   1. Press Win+R, type 'sysdm.cpl', press Enter")
        print("   2. Click 'Environment Variables'")
        print("   3. Remove any Flutter paths from PATH")
        print("   4. Click OK to save")
    except:
        pass

def download_flutter():
    """Download Flutter SDK"""
    print_header("Downloading Flutter SDK")
    
    # Create flutter directory in this project
    project_root = Path.cwd()
    flutter_dir = project_root / "flutter_sdk"
    
    if flutter_dir.exists():
        print(f"🗑️  Removing existing flutter_sdk directory...")
        shutil.rmtree(flutter_dir)
    
    flutter_dir.mkdir(exist_ok=True)
    
    # Download Flutter for Windows
    flutter_url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.9-stable.zip"
    
    print(f"📥 Downloading Flutter SDK...")
    print(f"   URL: {flutter_url}")
    
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.zip') as tmp_file:
            print("   Downloading... (this may take a few minutes)")
            
            response = requests.get(flutter_url, stream=True)
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
                zip_ref.extractall(flutter_dir)
            
            print(f"✅ Flutter extracted to: {flutter_dir}")
            
            # Clean up
            os.unlink(tmp_file.name)
            
            return flutter_dir / "flutter"
            
    except Exception as e:
        print(f"❌ Failed to download Flutter: {e}")
        return None

def setup_flutter_path(flutter_path):
    """Setup Flutter in PATH for this session"""
    print_header("Setting Up Flutter PATH")
    
    flutter_bin = flutter_path / "bin"
    
    if not flutter_bin.exists():
        print(f"❌ Flutter bin directory not found: {flutter_bin}")
        return False
    
    # Add to current session PATH
    current_path = os.environ.get('PATH', '')
    new_path = f"{flutter_bin};{current_path}"
    os.environ['PATH'] = new_path
    
    print(f"✅ Added Flutter to PATH: {flutter_bin}")
    
    # Create batch file for permanent PATH setup
    batch_content = f"""@echo off
echo Adding Flutter to PATH for AfiCare project...
set PATH={flutter_bin};%PATH%
echo Flutter PATH added for this session
echo.
echo To make permanent:
echo 1. Press Win+R, type 'sysdm.cpl', press Enter
echo 2. Click 'Environment Variables'
echo 3. Add to PATH: {flutter_bin}
echo.
pause
"""
    
    with open("setup_flutter_path.bat", "w") as f:
        f.write(batch_content)
    
    print("📝 Created setup_flutter_path.bat for permanent PATH setup")
    
    return True

def test_flutter_installation(flutter_path):
    """Test Flutter installation"""
    print_header("Testing Flutter Installation")
    
    flutter_bin = flutter_path / "bin" / "flutter.exe"
    
    if not flutter_bin.exists():
        print(f"❌ Flutter executable not found: {flutter_bin}")
        return False
    
    # Test Flutter version
    print("🧪 Testing Flutter version...")
    result = run_command(f'"{flutter_bin}" --version', check=False)
    
    if result and result.returncode == 0:
        print("✅ Flutter version check passed:")
        print(result.stdout)
    else:
        print("❌ Flutter version check failed")
        return False
    
    # Run Flutter doctor
    print("🏥 Running Flutter doctor...")
    result = run_command(f'"{flutter_bin}" doctor', check=False)
    
    if result:
        print("📋 Flutter doctor results:")
        print(result.stdout)
        if result.stderr:
            print("⚠️  Warnings/Errors:")
            print(result.stderr)
    
    return True

def setup_aficare_flutter():
    """Setup AfiCare Flutter project"""
    print_header("Setting Up AfiCare Flutter Project")
    
    flutter_project_dir = Path("aficare_flutter")
    
    if not flutter_project_dir.exists():
        print(f"❌ AfiCare Flutter project not found: {flutter_project_dir}")
        return False
    
    print(f"📱 Found AfiCare Flutter project: {flutter_project_dir}")
    
    # Get Flutter dependencies
    print("📦 Installing Flutter dependencies...")
    flutter_bin = Path("flutter_sdk/flutter/bin/flutter.exe")
    
    if flutter_bin.exists():
        result = run_command(f'"{flutter_bin}" pub get', cwd=flutter_project_dir, check=False)
        
        if result and result.returncode == 0:
            print("✅ Flutter dependencies installed successfully")
            print(result.stdout)
        else:
            print("❌ Failed to install Flutter dependencies")
            if result:
                print(result.stderr)
            return False
    else:
        print(f"❌ Flutter binary not found: {flutter_bin}")
        return False
    
    return True

def create_flutter_scripts():
    """Create convenient Flutter scripts"""
    print_header("Creating Flutter Scripts")
    
    flutter_bin = Path("flutter_sdk/flutter/bin/flutter.exe")
    
    # Script to run Flutter web
    web_script = f"""@echo off
echo Starting AfiCare Flutter Web App...
cd aficare_flutter
"{flutter_bin.absolute()}" run -d chrome --web-port 3000
pause
"""
    
    with open("run_flutter_web.bat", "w") as f:
        f.write(web_script)
    
    # Script to build Flutter web
    build_script = f"""@echo off
echo Building AfiCare Flutter Web App...
cd aficare_flutter
"{flutter_bin.absolute()}" build web --release
echo.
echo Build complete! Files are in aficare_flutter/build/web/
pause
"""
    
    with open("build_flutter_web.bat", "w") as f:
        f.write(build_script)
    
    # Script to build Android APK
    android_script = f"""@echo off
echo Building AfiCare Android APK...
cd aficare_flutter
"{flutter_bin.absolute()}" build apk --release
echo.
echo APK built! File is in aficare_flutter/build/app/outputs/flutter-apk/
pause
"""
    
    with open("build_android_apk.bat", "w") as f:
        f.write(android_script)
    
    print("✅ Created Flutter scripts:")
    print("   📱 run_flutter_web.bat - Run Flutter web app")
    print("   🏗️  build_flutter_web.bat - Build web app for deployment")
    print("   📱 build_android_apk.bat - Build Android APK")

def main():
    print("🚀 AfiCare Flutter Setup - Complete Installation")
    print("   This will remove old Flutter and install fresh for this project")
    print("   Patient-Owned Healthcare Records for Africa")
    
    try:
        # Step 1: Remove old Flutter
        remove_old_flutter()
        
        # Step 2: Download Flutter
        flutter_path = download_flutter()
        if not flutter_path:
            print("❌ Failed to download Flutter")
            return False
        
        # Step 3: Setup PATH
        if not setup_flutter_path(flutter_path):
            print("❌ Failed to setup Flutter PATH")
            return False
        
        # Step 4: Test installation
        if not test_flutter_installation(flutter_path):
            print("❌ Flutter installation test failed")
            return False
        
        # Step 5: Setup AfiCare Flutter project
        if not setup_aficare_flutter():
            print("❌ Failed to setup AfiCare Flutter project")
            return False
        
        # Step 6: Create convenience scripts
        create_flutter_scripts()
        
        # Success!
        print_header("🎉 Flutter Setup Complete!")
        print("✅ Flutter SDK installed locally for this project")
        print("✅ AfiCare Flutter project configured")
        print("✅ Dependencies installed")
        print("✅ Convenience scripts created")
        print()
        print("🚀 Next steps:")
        print("   1. Double-click 'run_flutter_web.bat' to test Flutter web app")
        print("   2. Or run: python deploy_both_apps.py")
        print("   3. Flutter is now ready for AfiCare development!")
        print()
        print("📱 Flutter commands available:")
        print(f"   flutter_sdk/flutter/bin/flutter.exe --version")
        print(f"   flutter_sdk/flutter/bin/flutter.exe doctor")
        print()
        print("🎯 Your AfiCare mobile apps are ready to deploy!")
        
        return True
        
    except KeyboardInterrupt:
        print("\n❌ Setup cancelled by user")
        return False
    except Exception as e:
        print(f"\n❌ Setup failed: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)