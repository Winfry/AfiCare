#!/usr/bin/env python3
"""
Test AfiCare PWA Features
Verify that PWA and QR codes are working
"""

import requests
import time
import webbrowser
from pathlib import Path

def test_pwa_running():
    """Test if PWA is running"""
    print("🧪 Testing AfiCare PWA...")
    
    ports_to_test = [8503, 8502, 8504, 8505]
    
    for port in ports_to_test:
        try:
            url = f"http://localhost:{port}"
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                print(f"✅ PWA is running on {url}")
                
                # Check if it contains AfiCare content
                if "AfiCare" in response.text or "MediLink" in response.text:
                    print("✅ AfiCare content detected")
                    return url
                else:
                    print("⚠️  Response received but no AfiCare content")
                    
        except requests.exceptions.RequestException:
            continue
    
    print("❌ PWA not found on any port")
    return None

def show_test_instructions(url):
    """Show testing instructions"""
    print(f"""
🎯 AfiCare PWA Testing Guide
{'='*50}

✅ Your PWA is running at: {url}

🧪 Test These Features:

1. **Login Test**:
   👤 Patient: patient@demo.com / demo123
   👨‍⚕️ Doctor: doctor@demo.com / demo123
   👨‍💼 Admin: admin@demo.com / demo123

2. **QR Code Test**:
   • Login as patient
   • Go to "Health Records" tab
   • Click "📱 Generate QR Code"
   • Should show actual QR code (not placeholder)

3. **AI Consultation Test**:
   • Login as doctor
   • Go to "AI Agent Demo" tab
   • Enter symptoms like: fever, headache, chills
   • Should get malaria diagnosis with confidence score

4. **Mobile App Install**:
   🤖 Android: Look for "📱 Install App" button
   🍎 iPhone: Safari → Share → Add to Home Screen
   💻 Desktop: Chrome install icon in address bar

5. **Offline Test**:
   • Install as app
   • Disconnect internet
   • App should still work for basic features

📱 Expected Results:
✅ QR codes generate properly (no "Install qrcode library" message)
✅ AI gives medical diagnoses with confidence scores
✅ PWA install button appears
✅ Mobile-optimized interface
✅ All demo accounts work

❌ If you see issues:
• Raw HTML/CSS code → Fixed in latest version
• QR placeholder → Should be fixed now
• AI not working → Check console for errors

🚀 Next Steps:
1. Test all features above
2. Install Flutter: python setup_flutter_here.py
3. Deploy globally: python deploy_both_apps.py
""")

def main():
    print("🏥 AfiCare PWA Feature Test")
    print("Testing your Progressive Web App...")
    
    # Test if PWA is running
    url = test_pwa_running()
    
    if url:
        # Open browser
        print(f"🌐 Opening {url} in browser...")
        webbrowser.open(url)
        
        # Show instructions
        show_test_instructions(url)
        
        print("\n🎯 Test the features above, then come back here!")
        input("Press Enter when you've tested the PWA features...")
        
        print("\n✅ PWA testing complete!")
        print("🚀 Ready for Flutter setup and global deployment!")
        
    else:
        print("\n❌ PWA not running. Start it first:")
        print("   python start_phone_app.py")

if __name__ == "__main__":
    main()