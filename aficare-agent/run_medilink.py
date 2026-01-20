#!/usr/bin/env python3
"""
Robust MediLink Launcher - Uses random port assignment to avoid conflicts
"""

import subprocess
import sys
import webbrowser
import time
import threading

def main():
    print("🏥 AfiCare MediLink - Robust Launcher")
    print("=" * 45)
    print()
    
    print("🚀 Starting MediLink with automatic port selection...")
    print("🌐 Streamlit will automatically find an available port")
    print()
    print("📱 Demo Accounts:")
    print("   Patient: username=patient_demo, password=demo123")
    print("   Doctor:  username=dr_demo, password=demo123")
    print("   Admin:   username=admin_demo, password=demo123")
    print()
    print("⏹️  Press Ctrl+C to stop the server")
    print("=" * 45)
    
    try:
        # Let Streamlit automatically find a port (it's very good at this)
        cmd = [
            sys.executable, "-m", "streamlit", "run", 
            "medilink_simple.py",
            "--server.headless", "true",
            "--browser.gatherUsageStats", "false",
            "--server.enableCORS", "false",
            "--server.enableXsrfProtection", "false"
        ]
        
        # Start Streamlit and let it handle port selection
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        # Monitor output to find the port
        port_found = False
        for line in iter(process.stdout.readline, ''):
            print(line.strip())
            
            # Look for the URL in Streamlit's output
            if "Local URL:" in line and "localhost:" in line:
                try:
                    url = line.split("Local URL:")[1].strip()
                    print(f"\n🎉 MediLink is running at: {url}")
                    
                    # Open browser after a short delay
                    def open_browser():
                        time.sleep(2)
                        webbrowser.open(url)
                    
                    browser_thread = threading.Thread(target=open_browser)
                    browser_thread.daemon = True
                    browser_thread.start()
                    
                    port_found = True
                except:
                    pass
            
            # Check if process ended
            if process.poll() is not None:
                break
        
        if not port_found:
            print("❌ Could not start MediLink")
        
        # Wait for process to complete
        process.wait()
        
    except KeyboardInterrupt:
        print("\n🛑 MediLink stopped by user")
        if 'process' in locals():
            process.terminate()
    except Exception as e:
        print(f"\n❌ Error starting MediLink: {e}")
        print("💡 Make sure you're in the aficare-agent directory")
        print("💡 Make sure Streamlit is installed: pip install streamlit")
    
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()