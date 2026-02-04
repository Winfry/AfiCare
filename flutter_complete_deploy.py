#!/usr/bin/env python3
"""
AfiCare Flutter - Complete Setup and FREE Deployment
Step-by-step Flutter completion and no-cost deployment
"""

import os
import subprocess
import sys
import time
import json
import shutil
import requests
import zipfile
import tempfile
from pathlib import Path

class FlutterCompleteDeployer:
    def __init__(self):
        self.root_dir = Path(__file__).parent
        self.flutter_dir = self.root_dir / "aficare_flutter"
        self.backend_dir = self.root_dir / "aficare-agent"
        self.flutter_sdk_dir = self.root_dir / "flutter_sdk"
        
    def print_header(self, title):
        print(f"\n{'='*70}")
        print(f"  {title}")
        print(f"{'='*70}")
    
    def print_step(self, step, description):
        print(f"\n🔹 STEP {step}: {description}")
        print("-" * 60)
    
    def run_command(self, command, cwd=None, check=True, show_output=True):
        """Run a shell command"""
        try:
            if show_output:
                print(f"   Running: {command}")
            
            result = subprocess.run(
                command, 
                shell=True, 
                cwd=cwd, 
                capture_output=not show_output,
                text=True,
                check=check
            )
            
            if not show_output and result.stdout:
                print(result.stdout)
            
            return result
        except subprocess.CalledProcessError as e:
            print(f"❌ Command failed: {command}")
            if e.stderr:
                print(f"Error: {e.stderr}")
            return None
    
    def install_flutter_sdk(self):
        """Install Flutter SDK locally"""
        self.print_step(1, "Installing Flutter SDK")
        
        if self.flutter_sdk_dir.exists():
            print("✅ Flutter SDK already exists")
            flutter_exe = self.flutter_sdk_dir / "bin" / "flutter.exe"
            if flutter_exe.exists():
                return str(flutter_exe)
        
        print("📥 Downloading Flutter SDK...")
        
        # Try Git clone first (fastest)
        result = self.run_command(
            "git clone https://github.com/flutter/flutter.git -b stable flutter_sdk",
            show_output=False,
            check=False
        )
        
        if not result or result.returncode != 0:
            print("📥 Git clone failed, downloading ZIP...")
            
            try:
                url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.9-stable.zip"
                
                print("⏳ Downloading Flutter SDK (this may take a few minutes