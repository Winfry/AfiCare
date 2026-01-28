#!/usr/bin/env python3
"""
Simple MediLink Starter - Just finds a port and runs
"""

import socket
import subprocess
import sys
import os

def find_free_port():
    """Find any free port quickly"""
    ports = [8090, 9000, 3000, 5000, 7000, 8888, 9999, 4000, 6000, 8080]
    
    for port in ports:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return port
        except OSError:
            continue
    return None

def main():
    print("🏥 Starting AfiCare MediLink...")
    
    port = find_free_port()
    if not port:
        print("❌ No available ports found!")
        return
    
    print(f"🚀 Starting on port {port}")
    print(f"🌐 Open: http://localhost:{port}")
    print("📱 Demo: patient_demo / demo123")
    
    try:
        os.system(f"streamlit run medilink_simple.py --server.port {port} --server.address localhost")
    except KeyboardInterrupt:
        print("\\n🛑 Stopped")

if __name__ == "__main__":
    main()