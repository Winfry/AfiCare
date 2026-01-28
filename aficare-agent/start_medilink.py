#!/usr/bin/env python3
"""
AfiCare MediLink Starter
- Finds an available port
- Enables PWA static file serving
- Launches the Streamlit app
"""

import socket
import subprocess
import sys
import os

# Get the directory of this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

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

def print_banner():
    """Print startup banner"""
    print("""
    ╔═══════════════════════════════════════════════════╗
    ║                                                   ║
    ║     █████╗ ███████╗██╗ ██████╗ █████╗ ██████╗    ║
    ║    ██╔══██╗██╔════╝██║██╔════╝██╔══██╗██╔══██╗   ║
    ║    ███████║█████╗  ██║██║     ███████║██████╔╝   ║
    ║    ██╔══██║██╔══╝  ██║██║     ██╔══██║██╔══██╗   ║
    ║    ██║  ██║██║     ██║╚██████╗██║  ██║██║  ██║   ║
    ║    ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ║
    ║                                                   ║
    ║           M E D I L I N K                        ║
    ║     Patient-Owned Healthcare Records             ║
    ║                                                   ║
    ╚═══════════════════════════════════════════════════╝
    """)

def main():
    print_banner()
    print("Starting AfiCare MediLink...")

    port = find_free_port()
    if not port:
        print("ERROR: No available ports found!")
        return

    print(f"Port: {port}")
    print(f"URL: http://localhost:{port}")
    print("")
    print("Demo Accounts:")
    print("  Patient: patient_demo / demo123")
    print("  Doctor:  dr_demo / demo123")
    print("  Admin:   admin_demo / demo123")
    print("")
    print("PWA: Install as app on your phone or desktop!")
    print("")
    print("Press Ctrl+C to stop the server")
    print("-" * 50)

    # Change to script directory
    os.chdir(SCRIPT_DIR)

    # Run streamlit with static file serving enabled
    cmd = [
        sys.executable, "-m", "streamlit", "run",
        "medilink_simple.py",
        f"--server.port={port}",
        "--server.address=localhost",
        "--server.enableStaticServing=true",
        "--browser.gatherUsageStats=false",
        "--theme.primaryColor=#2E7D32",
        "--theme.backgroundColor=#FFFFFF",
        "--theme.secondaryBackgroundColor=#E8F5E9"
    ]

    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\nStopped AfiCare MediLink")

if __name__ == "__main__":
    main()