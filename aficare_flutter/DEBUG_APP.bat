@echo off
echo.
echo ========================================
echo   Flutter App Debug Mode
echo ========================================
echo.
echo This will run the app and show errors
echo.
echo Instructions:
echo 1. Connect your phone via USB
echo 2. Enable USB debugging on phone
echo 3. Try to login when app opens
echo 4. Watch this console for errors
echo 5. Press Ctrl+C when screen goes blank
echo.
pause

flutter run --verbose

pause
