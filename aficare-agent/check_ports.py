#!/usr/bin/env python3
"""
Port Checker - Check which ports are available for MediLink
"""

import socket

def check_port(port):
    """Check if a port is available"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('localhost', port))
            return True
    except OSError:
        return False

def main():
    print("🔍 AfiCare MediLink - Port Availability Checker")
    print("=" * 50)
    
    ports_to_check = [8080, 8090, 9000, 3000, 5000, 7000, 8888, 9999, 4000, 6000, 8501, 8502, 8503]
    
    available_ports = []
    used_ports = []
    
    for port in ports_to_check:
        if check_port(port):
            available_ports.append(port)
            print(f"✅ Port {port} - AVAILABLE")
        else:
            used_ports.append(port)
            print(f"❌ Port {port} - IN USE")
    
    print("\n" + "=" * 50)
    print(f"📊 Summary:")
    print(f"   Available ports: {len(available_ports)}")
    print(f"   Used ports: {len(used_ports)}")
    
    if available_ports:
        print(f"\n🎯 Recommended port to use: {available_ports[0]}")
        print(f"\n🚀 To start MediLink on port {available_ports[0]}:")
        print(f"   streamlit run medilink_simple.py --server.port {available_ports[0]}")
    else:
        print("\n⚠️  No ports available! Try:")
        print("   1. Close other applications using these ports")
        print("   2. Run as Administrator")
        print("   3. Check Windows Firewall settings")
    
    print("\n" + "=" * 50)
    input("Press Enter to exit...")

if __name__ == "__main__":
    main()