#!/usr/bin/env python3
import subprocess, webbrowser, time
port = 8503
print(f"📱 AfiCare Phone App starting on port {port}...")
print("📱 Install as app: Look for '📱 Install App' button")
print("🔑 Login: patient@demo.com / demo123")
webbrowser.open(f"http://localhost:{port}")
subprocess.run(["streamlit", "run", "medilink_simple.py", "--server.port", str(port), "--server.enableCORS", "false"])