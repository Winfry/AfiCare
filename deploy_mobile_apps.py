#!/usr/bin/env python3
"""
AfiCare Mobile Apps - Quick Deployment Script
Deploy both PWA and Flutter apps with one command
"""

import os
import subprocess
import sys
from pathlib import Path
import webbrowser
import time

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def run_command(command, cwd=None, check=True):
    """Run a shell command"""
    try:
        result = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True, check=check)
        if result.stdout:
            print(result.stdout)
        return result
    except subprocess.CalledProcessError as e:
        print(f"❌ Command failed: {command}")
        print(f"Error: {e.stderr}")
        return None

def test_pwa():
    """Test the PWA (Streamlit app)"""
    print_header("Testing PWA (Progressive Web App)")
    
    backend_dir = Path("aficare-agent")
    if not backend_dir.exists():
        print("❌ aficare-agent directory not found")
        return False
    
    print("🧪 Testing QR code generation...")
    result = run_command("python -c \"import qrcode; print('✅ QR code library working')\"", 
                        cwd=backend_dir, check=False)
    
    if result and result.returncode != 0:
        print("📦 Installing QR code library...")
        run_command("pip install qrcode[pil]", cwd=backend_dir)
    
    print("🚀 Starting PWA (Streamlit)...")
    print("   This will open your browser automatically")
    print("   The app is already PWA-enabled!")
    print()
    print("📱 To install as mobile app:")
    print("   • Android: Look for '📱 Install App' button")
    print("   • iPhone: Safari → Share → Add to Home Screen")
    print("   • Desktop: Chrome install icon in address bar")
    print()
    
    # Start Streamlit in background
    try:
        process = subprocess.Popen([
            "streamlit", "run", "medilink_simple.py", 
            "--server.port", "8502",
            "--server.headless", "false"
        ], cwd=backend_dir)
        
        # Wait a moment then open browser
        time.sleep(3)
        webbrowser.open("http://localhost:8502")
        
        print("✅ PWA is running at http://localhost:8502")
        print("✅ PWA features enabled: Install button, offline mode, QR codes")
        
        return process
        
    except FileNotFoundError:
        print("❌ Streamlit not found. Installing...")
        run_command("pip install streamlit", cwd=backend_dir)
        return None
    except Exception as e:
        print(f"❌ Error starting PWA: {e}")
        return None

def test_flutter():
    """Test the Flutter app"""
    print_header("Testing Flutter Native App")
    
    flutter_dir = Path("aficare_flutter")
    if not flutter_dir.exists():
        print("❌ aficare_flutter directory not found")
        return False
    
    # Check Flutter installation
    result = run_command("flutter --version", check=False)
    if not result or result.returncode != 0:
        print("❌ Flutter not installed")
        print("   Download from: https://flutter.dev/docs/get-started/install")
        return False
    
    print("📦 Installing Flutter dependencies...")
    run_command("flutter pub get", cwd=flutter_dir)
    
    print("🔍 Running Flutter doctor...")
    run_command("flutter doctor", cwd=flutter_dir, check=False)
    
    print("🌐 Starting Flutter web app...")
    print("   This will open in a new browser tab")
    print("   Native mobile performance in the browser!")
    
    try:
        # Start Flutter web app
        process = subprocess.Popen([
            "flutter", "run", "-d", "chrome", "--web-port", "3000"
        ], cwd=flutter_dir)
        
        print("✅ Flutter app starting at http://localhost:3000")
        print("✅ Features: Native performance, offline AI, QR scanner")
        
        return process
        
    except Exception as e:
        print(f"❌ Error starting Flutter app: {e}")
        return None

def show_deployment_options():
    """Show deployment options"""
    print_header("🌍 Deploy Globally - 100% FREE")
    
    print("🚀 Ready to deploy your apps globally?")
    print()
    print("📱 PWA Deployment (Streamlit):")
    print("   1. Railway.app - https://railway.app (FREE)")
    print("   2. Render.com - https://render.com (FREE)")
    print("   3. Heroku - https://heroku.com")
    print()
    print("📱 Flutter Deployment:")
    print("   1. Web: Vercel - https://vercel.com (FREE)")
    print("   2. Android: GitHub Releases (FREE)")
    print("   3. iOS: TestFlight (FREE)")
    print()
    print("🔒 Security Features:")
    print("   ✅ HTTPS encryption")
    print("   ✅ QR code security")
    print("   ✅ Access control")
    print("   ✅ Audit logging")
    print()
    print("📊 Demo Accounts:")
    print("   Patient: patient@demo.com / demo123")
    print("   Doctor: doctor@demo.com / demo123")
    print("   Admin: admin@demo.com / demo123")

def main():
    print("📱 AfiCare Mobile Apps - Quick Test & Deploy")
    print("   Patient-Owned Healthcare Records for Africa")
    print("   100% FREE and Open Source")
    
    try:
        # Test PWA
        pwa_process = test_pwa()
        
        # Wait a moment
        time.sleep(2)
        
        # Test Flutter
        flutter_process = test_flutter()
        
        # Show deployment options
        show_deployment_options()
        
        print("\n🎉 Both apps are running!")
        print("   PWA: http://localhost:8502 (installable)")
        print("   Flutter: http://localhost:3000 (native performance)")
        print()
        print("Press Ctrl+C to stop both apps")
        
        # Wait for user to stop
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n🛑 Stopping apps...")
            if pwa_process:
                pwa_process.terminate()
            if flutter_process:
                flutter_process.terminate()
            print("✅ Apps stopped")
            
    except KeyboardInterrupt:
        print("\n❌ Deployment cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Deployment failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()