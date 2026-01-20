# PowerShell script to run MediLink with Windows port workaround
Write-Host "🏥 Starting AfiCare MediLink System..." -ForegroundColor Green
Write-Host ""
Write-Host "Trying different ports to avoid Windows permission issues..." -ForegroundColor Yellow
Write-Host ""

$ports = @(8080, 8090, 9000, 3000, 5000, 7000)

foreach ($port in $ports) {
    Write-Host "Attempting to start on port $port..." -ForegroundColor Cyan
    
    try {
        # Test if port is available
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
        $listener.Start()
        $listener.Stop()
        
        Write-Host "✅ Port $port is available! Starting MediLink..." -ForegroundColor Green
        Write-Host ""
        Write-Host "🌐 Your MediLink app will open at: http://localhost:$port" -ForegroundColor Magenta
        Write-Host ""
        
        # Start Streamlit
        streamlit run medilink_simple.py --server.port $port --server.address localhost
        break
    }
    catch {
        Write-Host "❌ Port $port is not available, trying next..." -ForegroundColor Red
        continue
    }
}

Write-Host ""
Write-Host "If all ports failed, try running PowerShell as Administrator" -ForegroundColor Yellow
Read-Host "Press Enter to exit"