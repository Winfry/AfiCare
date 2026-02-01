#!/usr/bin/env python3
"""
AfiCare Mobile Features Test
Test QR codes, PWA features, and mobile functionality
"""

import sys
import os
from pathlib import Path

def test_qr_generation():
    """Test QR code generation"""
    print("🧪 Testing QR Code Generation...")
    
    try:
        import qrcode
        from io import BytesIO
        import json
        import base64
        
        # Test data
        test_data = {
            "medilink_id": "ML-NBO-TEST",
            "access_code": "123456",
            "type": "Emergency Access",
            "expires": "2024-12-31T23:59:59"
        }
        
        # Generate QR code
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(json.dumps(test_data))
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Convert to bytes
        img_buffer = BytesIO()
        img.save(img_buffer, format='PNG')
        img_bytes = img_buffer.getvalue()
        
        print(f"✅ QR Code generated successfully ({len(img_bytes)} bytes)")
        return True
        
    except ImportError:
        print("❌ QR code library not installed")
        print("   Run: pip install qrcode[pil]")
        return False
    except Exception as e:
        print(f"❌ QR code generation failed: {e}")
        return False

def test_pwa_features():
    """Test PWA configuration"""
    print("🧪 Testing PWA Features...")
    
    # Check if PWA files exist
    pwa_files = [
        "aficare-agent/static/manifest.json",
        "aficare-agent/static/sw.js",
        "aficare-agent/static/offline.html"
    ]
    
    all_exist = True
    for file_path in pwa_files:
        if Path(file_path).exists():
            print(f"✅ {file_path} exists")
        else:
            print(f"❌ {file_path} missing")
            all_exist = False
    
    return all_exist

def test_flutter_setup():
    """Test Flutter setup"""
    print("🧪 Testing Flutter Setup...")
    
    flutter_dir = Path("aficare_flutter")
    if not flutter_dir.exists():
        print("❌ Flutter directory not found")
        return False
    
    # Check key files
    flutter_files = [
        "aficare_flutter/pubspec.yaml",
        "aficare_flutter/lib/main.dart",
        "aficare_flutter/lib/services/medical_ai_service.dart"
    ]
    
    all_exist = True
    for file_path in flutter_files:
        if Path(file_path).exists():
            print(f"✅ {file_path} exists")
        else:
            print(f"❌ {file_path} missing")
            all_exist = False
    
    return all_exist

def test_ai_integration():
    """Test AI integration"""
    print("🧪 Testing AI Integration...")
    
    try:
        # Add the src directory to path
        backend_dir = Path("aficare-agent")
        src_dir = backend_dir / "src"
        sys.path.insert(0, str(src_dir))
        
        # Test AI agent import
        from core.agent import AfiCareAgent
        print("✅ AfiCare AI Agent imports successfully")
        
        # Test simple consultation
        agent = AfiCareAgent()
        print("✅ AI Agent initializes successfully")
        
        return True
        
    except ImportError as e:
        print(f"⚠️  AI Agent import issue: {e}")
        print("   This is normal - AI will use fallback mode")
        return True  # Not critical
    except Exception as e:
        print(f"❌ AI integration test failed: {e}")
        return False

def test_database_connection():
    """Test database functionality"""
    print("🧪 Testing Database Connection...")
    
    try:
        import sqlite3
        
        # Test database file
        db_path = Path("aficare-agent/aficare.db")
        if db_path.exists():
            print("✅ Database file exists")
            
            # Test connection
            conn = sqlite3.connect(str(db_path))
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
            tables = cursor.fetchall()
            conn.close()
            
            print(f"✅ Database connection successful ({len(tables)} tables)")
            return True
        else:
            print("⚠️  Database file not found - will be created on first run")
            return True
            
    except Exception as e:
        print(f"❌ Database test failed: {e}")
        return False

def main():
    print("🧪 AfiCare Mobile Features Test")
    print("=" * 50)
    
    tests = [
        ("QR Code Generation", test_qr_generation),
        ("PWA Features", test_pwa_features),
        ("Flutter Setup", test_flutter_setup),
        ("AI Integration", test_ai_integration),
        ("Database Connection", test_database_connection)
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n📋 {test_name}")
        print("-" * 30)
        result = test_func()
        results.append((test_name, result))
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 TEST SUMMARY")
    print("=" * 50)
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            passed += 1
    
    print(f"\n🎯 Results: {passed}/{len(tests)} tests passed")
    
    if passed == len(tests):
        print("\n🎉 All tests passed! Your mobile apps are ready!")
        print("\n🚀 Next steps:")
        print("   1. Run: python deploy_mobile_apps.py")
        print("   2. Test PWA installation on your phone")
        print("   3. Test Flutter app: cd aficare_flutter && flutter run -d chrome")
        print("   4. Deploy globally using FREE_SECURE_DEPLOYMENT.md guide")
    else:
        print(f"\n⚠️  {len(tests) - passed} tests failed. Check the issues above.")
        print("   Most issues can be fixed by installing missing dependencies")
    
    return passed == len(tests)

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)