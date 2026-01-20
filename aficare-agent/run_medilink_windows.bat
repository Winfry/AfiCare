@echo off
echo Starting AfiCare MediLink System...
echo.
echo Trying different ports to avoid Windows permission issues...
echo.

REM Try port 8080 first (commonly available)
echo Attempting to start on port 8080...
streamlit run medilink_simple.py --server.port 8080 --server.address localhost
if %ERRORLEVEL% NEQ 0 (
    echo Port 8080 failed, trying 8090...
    streamlit run medilink_simple.py --server.port 8090 --server.address localhost
    if %ERRORLEVEL% NEQ 0 (
        echo Port 8090 failed, trying 9000...
        streamlit run medilink_simple.py --server.port 9000 --server.address localhost
        if %ERRORLEVEL% NEQ 0 (
            echo Port 9000 failed, trying 3000...
            streamlit run medilink_simple.py --server.port 3000 --server.address localhost
            if %ERRORLEVEL% NEQ 0 (
                echo All ports failed. Please run as administrator or check firewall settings.
                pause
            )
        )
    )
)