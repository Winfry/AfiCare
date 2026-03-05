@echo off
echo.
echo ========================================
echo   Starting AfiCare Medical Agent
echo ========================================
echo.

cd /d "%~dp0"
python run_aficare.py

pause
