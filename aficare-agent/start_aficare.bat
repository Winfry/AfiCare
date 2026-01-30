@echo off
echo ========================================
echo   AfiCare MediLink - Quick Start
echo ========================================
echo.
echo Starting AfiCare MediLink...
echo This will open your browser automatically
echo.
echo Demo Accounts:
echo   Patient: patient@demo.com / demo123
echo   Doctor: doctor@demo.com / demo123
echo   Admin: admin@demo.com / demo123
echo.
echo Press Ctrl+C to stop the server
echo.

REM Try to start Streamlit
streamlit run medilink_simple.py --server.port 8502

REM If that fails, try installing requirements
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Installing requirements...
    pip install -r requirements.txt
    echo.
    echo Trying again...
    streamlit run medilink_simple.py --server.port 8502
)

pause