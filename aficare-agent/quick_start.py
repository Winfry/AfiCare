#!/usr/bin/env python3
"""
Quick Start MediLink - Simple launcher that just works
"""

import os
import sys

def main():
    print("🏥 AfiCare MediLink - Quick Start")
    print("=" * 40)
    
    # Try different ports in order
    ports = [8090, 9000, 7000, 8888, 4000, 5000]
    
    for port in ports:
        print(f"\n🚀 Trying port {port}...")
        
        cmd = f'streamlit run medilink_simple.py --server.port {port} --server.address localhost --server.headless true'
        
        try:
            os.system(cmd)
            break  # If we get here, it worked
        except KeyboardInterrupt:
            print("\n🛑 Stopped by user")
            break
        except:
            print(f"❌ Port {port} failed, trying next...")
            continue
    
    print("\n✅ MediLink session ended")

if __name__ == "__main__":
    main()