#!/usr/bin/env python3
"""
Simple MediLink Starter - Just runs Streamlit with automatic port
"""

import os
import sys

def main():
    print("🏥 Starting AfiCare MediLink...")
    print("🌐 Streamlit will find an available port automatically")
    print("📱 Demo: patient_demo / demo123, dr_demo / demo123")
    print()
    
    # Simple approach - let Streamlit handle everything
    try:
        # Use os.system for simplicity - Streamlit handles port conflicts well
        result = os.system("streamlit run medilink_simple.py --server.headless true")
        
        if result != 0:
            print("❌ Failed to start. Trying alternative approach...")
            # Try with explicit localhost binding
            os.system("streamlit run medilink_simple.py --server.address localhost --server.headless true")
            
    except KeyboardInterrupt:
        print("\n🛑 Stopped by user")
    except Exception as e:
        print(f"❌ Error: {e}")
        print("💡 Make sure you're in the aficare-agent directory")
        print("💡 Make sure Streamlit is installed: pip install streamlit")

if __name__ == "__main__":
    main()