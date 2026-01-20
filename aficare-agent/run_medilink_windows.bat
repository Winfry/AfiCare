@echo off
echo 🏥 AfiCare MediLink - Windows Launcher
echo =====================================
echo.

REM Kill any existing streamlit processes
echo 🔄 Cleaning up existing processes...
taskkill /f /im python.exe /fi "WINDOWTITLE eq *streamlit*" >nul 2>&1

echo 🔍 Trying different ports...
echo.

REM Try port 8090 first
echo 🚀 Attempting port 8090...
streamlit run medilink_simple.py --server.port 8090 --server.address localhost --server.headless true
if %ERRORLEVEL% EQU 0 goto :success

REM Try port 9000
echo 🚀 Attempting port 9000...
streamlit run medilink_simple.py --server.port 9000 --server.address localhost --server.headless true
if %ERRORLEVEL% EQU 0 goto :success

REM Try port 7000
echo 🚀 Attempting port 7000...
streamlit run medilink_simple.py --server.port 7000 --server.address localhost --server.headless true
if %ERRORLEVEL% EQU 0 goto :success

REM Try port 8888
echo 🚀 Attempting port 8888...
streamlit run medilink_simple.py --server.port 8888 --server.address localhost --server.headless true
if %ERRORLEVEL% EQU 0 goto :success

echo ❌ All ports failed. Try running as Administrator.
pause
goto :end

:success
echo ✅ MediLink started successfully!

:end