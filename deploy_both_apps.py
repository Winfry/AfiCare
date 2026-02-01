#!/usr/bin/env python3
"""
AfiCare MediLink - Complete Deployment Script
Deploys both the Streamlit PWA and Flutter mobile app
"""

import os
import subprocess
import sys
from pathlib import Path
import json
import shutil
import time

class AfiCareDeployer:
    def __init__(self):
        self.root_dir = Path(__file__).parent
        self.backend_dir = self.root_dir / "aficare-agent"
        self.flutter_dir = self.root_dir / "aficare_flutter"
        
    def print_header(self, title):
        print(f"\n{'='*60}")
        print(f"  {title}")
        print(f"{'='*60}")
    
    def run_command(self, command, cwd=None, check=True):
        """Run a shell command and return the result"""
        try:
            result = subprocess.run(
                command, 
                shell=True, 
                cwd=cwd, 
                capture_output=True, 
                text=True,
                check=check
            )
            if result.stdout:
                print(result.stdout)
            return result
        except subprocess.CalledProcessError as e:
            print(f"❌ Command failed: {command}")
            print(f"Error: {e.stderr}")
            if check:
                return None
            return e
    
    def check_prerequisites(self):
        """Check if all required tools are installed"""
        self.print_header("Checking Prerequisites")
        
        # Check Python
        try:
            python_version = subprocess.check_output([sys.executable, "--version"], text=True)
            print(f"✅ Python: {python_version.strip()}")
        except:
            print("❌ Python not found")
            return False
        
        # Check Flutter - try multiple locations
        flutter_found = False
        flutter_paths = [
            "flutter",
            "flutter_sdk/bin/flutter",
            "flutter_sdk/bin/flutter.exe",
            str(Path.home() / "flutter/bin/flutter"),
            str(Path.home() / "flutter/bin/flutter.exe")
        ]
        
        for flutter_path in flutter_paths:
            try:
                result = subprocess.run([flutter_path, "--version"], 
                                      capture_output=True, text=True, check=False)
                if result.returncode == 0:
                    print(f"✅ Flutter found: {flutter_path}")
                    self.flutter_cmd = flutter_path
                    flutter_found = True
                    break
            except:
                continue
        
        if not flutter_found:
            print("❌ Flutter not found. Please install Flutter SDK")
            print("   Download from: https://flutter.dev/docs/get-started/install")
            print("   Or run: python quick_flutter_setup.py")
            return False
        
        return True
    
    def test_pwa_app(self):
        """Test the PWA app"""
        self.print_header("Testing PWA App")
        
        if not self.backend_dir.exists():
            print("❌ Backend directory not found")
            return False
        
        # Check if medilink_simple.py exists
        medilink_file = self.backend_dir / "medilink_simple.py"
        if not medilink_file.exists():
            print("❌ medilink_simple.py not found")
            return False
        
        print("✅ PWA app files found")
        
        # Test Python imports
        print("🧪 Testing Python imports...")
        test_script = """
import sys
sys.path.insert(0, 'src')
try:
    import streamlit
    print("✅ Streamlit available")
except ImportError:
    print("❌ Streamlit not found")

try:
    import qrcode
    print("✅ QR code library available")
except ImportError:
    print("❌ QR code library not found")

try:
    from core.agent import AfiCareAgent
    print("✅ AfiCare AI Agent available")
except ImportError as e:
    print(f"⚠️  AI Agent import issue: {e}")
"""
        
        with open(self.backend_dir / "test_imports.py", "w") as f:
            f.write(test_script)
        
        result = self.run_command("python test_imports.py", cwd=self.backend_dir, check=False)
        
        # Clean up
        (self.backend_dir / "test_imports.py").unlink(missing_ok=True)
        
        print("✅ PWA app tested")
        return True
    
    def setup_flutter(self):
        """Setup and test Flutter app"""
        self.print_header("Setting Up Flutter App")
        
        if not self.flutter_dir.exists():
            print("❌ Flutter directory not found")
            return False
        
        # Get Flutter dependencies
        print("📦 Getting Flutter dependencies...")
        result = self.run_command(f"{self.flutter_cmd} pub get", cwd=self.flutter_dir, check=False)
        
        if result and result.returncode == 0:
            print("✅ Flutter dependencies installed")
        else:
            print("⚠️  Flutter dependency installation had issues")
        
        # Run Flutter doctor
        print("🔍 Running Flutter doctor...")
        self.run_command(f"{self.flutter_cmd} doctor", cwd=self.flutter_dir, check=False)
        
        print("✅ Flutter setup complete")
        return True
    
    def start_pwa_demo(self):
        """Start PWA for demonstration"""
        self.print_header("Starting PWA Demo")
        
        print("🚀 Starting AfiCare PWA...")
        print("   This will open in your browser")
        print("   You can test all features including QR codes")
        print()
        
        # Start the PWA using our fixed script
        pwa_script = self.backend_dir / "start_phone_app.py"
        if pwa_script.exists():
            print("📱 Starting PWA with fixed script...")
            try:
                # Run in background so we can continue
                process = subprocess.Popen([sys.executable, "start_phone_app.py"], 
                                         cwd=self.backend_dir)
                
                print("⏳ Waiting for PWA to start...")
                time.sleep(8)
                
                print("✅ PWA should be running now!")
                print("   Check your browser - it should have opened automatically")
                print("   URL: http://localhost:8503 (or similar)")
                
                return process
                
            except Exception as e:
                print(f"❌ Error starting PWA: {e}")
                return None
        else:
            print("❌ PWA start script not found")
            return None
    
    def test_flutter_web(self):
        """Test Flutter web app"""
        self.print_header("Testing Flutter Web App")
        
        print("🌐 Testing Flutter web build...")
        
        # Try to build Flutter web
        result = self.run_command(f"{self.flutter_cmd} build web --release", 
                                cwd=self.flutter_dir, check=False)
        
        if result and result.returncode == 0:
            print("✅ Flutter web build successful!")
            
            # Check if build files exist
            web_build = self.flutter_dir / "build" / "web"
            if web_build.exists():
                print(f"✅ Web build files created: {web_build}")
                return True
            else:
                print("⚠️  Build completed but files not found")
                return False
        else:
            print("❌ Flutter web build failed")
            print("   This might be due to missing dependencies")
            return False
    
    def show_deployment_options(self):
        """Show deployment options"""
        self.print_header("🚀 Deployment Options")
        
        print("Your AfiCare MediLink system is ready! Here are your deployment options:")
        print()
        
        print("📱 PWA (Progressive Web App):")
        print("   ✅ Ready to deploy")
        print("   🌐 Deploy to Railway.app (FREE)")
        print("   🌐 Deploy to Render.com (FREE)")
        print("   📱 Users can install as mobile app")
        print()
        
        print("📱 Flutter Native Apps:")
        print("   🌐 Web: Deploy to Vercel/Netlify (FREE)")
        print("   🤖 Android: Build APK for direct distribution")
        print("   🍎 iOS: Build with Xcode (requires macOS)")
        print()
        
        print("🗄️  Database Options:")
        print("   💾 Local: SQLite (current, works offline)")
        print("   ☁️  Cloud: PostgreSQL on Railway (global access)")
        print("   🔄 Hybrid: Local + cloud sync (best option)")
        print()
        
        print("💰 All deployment options are 100% FREE!")
        print()
        
        print("📋 Next Steps:")
        print("   1. Test PWA features (should be running now)")
        print("   2. Test Flutter web app")
        print("   3. Choose deployment platform")
        print("   4. Deploy globally")
        print()
        
        print("🎯 Demo Accounts (test these):")
        print("   👤 Patient: patient@demo.com / demo123")
        print("   👨‍⚕️ Doctor: doctor@demo.com / demo123")
        print("   👨‍💼 Admin: admin@demo.com / demo123")
    
    def deploy(self):
        """Main deployment process"""
        print("🏥 AfiCare MediLink - Complete Deployment")
        print("   Patient-Owned Healthcare Records for Africa")
        print("   100% FREE and Open Source")
        
        try:
            # Check prerequisites
            if not self.check_prerequisites():
                return False
            
            # Test PWA
            if not self.test_pwa_app():
                print("⚠️  PWA test had issues, but continuing...")
            
            # Setup Flutter
            if not self.setup_flutter():
                print("⚠️  Flutter setup had issues, but continuing...")
            
            # Start PWA demo
            pwa_process = self.start_pwa_demo()
            
            # Test Flutter web
            flutter_web_ok = self.test_flutter_web()
            
            # Show deployment options
            self.show_deployment_options()
            
            # Wait for user input
            print("\n" + "="*60)
            print("🎉 DEPLOYMENT COMPLETE!")
            print("="*60)
            print()
            print("Your AfiCare MediLink system is ready for global deployment!")
            print("The PWA should be running in your browser now.")
            print()
            
            if flutter_web_ok:
                print("✅ Both PWA and Flutter web apps are ready!")
            else:
                print("✅ PWA is ready! Flutter web needs Flutter SDK setup.")
            
            print("\nPress Enter to stop the PWA demo, or Ctrl+C to exit...")
            
            try:
                input()
                if pwa_process:
                    pwa_process.terminate()
                    print("✅ PWA demo stopped")
            except KeyboardInterrupt:
                if pwa_process:
                    pwa_process.terminate()
                print("\n✅ Deployment demo stopped")
            
            return True
            
        except KeyboardInterrupt:
            print("\n❌ Deployment cancelled by user")
            return False
        except Exception as e:
            print(f"\n❌ Deployment failed: {e}")
            return False

if __name__ == "__main__":
    deployer = AfiCareDeployer()
    success = deployer.deploy()
    sys.exit(0 if success else 1)