@echo off
echo ========================================
echo   AfiCare Phone App - STARTING NOW!
echo ========================================
echo.
echo Killing existing processes...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq *streamlit*" >nul 2>&1
taskkill /F /IM streamlit.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo Starting AfiCare Phone App on port 8503...
echo.
echo 📱 PHONE APP FEATURES:
echo   ✅ PWA - Install as native app
echo   ✅ QR Code generation  
echo   ✅ Offline mode
echo   ✅ Touch-optimized interface
echo.
echo 📱 TO INSTALL ON PHONE:
echo   • Android: Tap "📱 Install App" button
echo   • iPhone: Safari → Share → Add to Home Screen
echo.
echo 🔑 Demo Accounts:
echo   Patient: patient@demo.com / demo123
echo   Doctor: doctor@demo.com / demo123
echo   Admin: admin@demo.com / demo123
echo.
echo Opening browser...
start http://localhost:8503
echo.
echo Press Ctrl+C to stop the server
echo.

streamlit run medilink_simple.py --server.port 8503 --server.enableCORS false --server.enableXsrfProtection false

pause