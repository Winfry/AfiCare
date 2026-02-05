# AfiCare Flutter Setup Script
# Run this in PowerShell as Administrator

Write-Host "=== AfiCare Flutter Setup ===" -ForegroundColor Green

# Check if Flutter zip exists
$flutterZip = "C:\Users\User\Downloads\flutter_windows.zip"
$flutterDir = "C:\flutter"

if (Test-Path $flutterZip) {
    Write-Host "Found Flutter SDK zip file" -ForegroundColor Yellow

    # Extract Flutter
    Write-Host "Extracting Flutter to C:\flutter..." -ForegroundColor Yellow
    if (Test-Path $flutterDir) {
        Write-Host "Removing old Flutter installation..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $flutterDir
    }

    Expand-Archive -Path $flutterZip -DestinationPath "C:\" -Force
    Write-Host "Flutter extracted successfully!" -ForegroundColor Green

    # Add to PATH
    Write-Host "Adding Flutter to PATH..." -ForegroundColor Yellow
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*flutter\bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\flutter\bin", "User")
        Write-Host "Flutter added to PATH" -ForegroundColor Green
    } else {
        Write-Host "Flutter already in PATH" -ForegroundColor Yellow
    }

    # Refresh PATH for current session
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    # Run flutter doctor
    Write-Host "`nRunning flutter doctor..." -ForegroundColor Yellow
    & "C:\flutter\bin\flutter.bat" doctor

    # Navigate to project and get dependencies
    Write-Host "`nSetting up AfiCare Flutter project..." -ForegroundColor Yellow
    Set-Location "C:\Users\User\projects\Personal\AfiCare\aficare_flutter"
    & "C:\flutter\bin\flutter.bat" pub get

    Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
    Write-Host "Run 'flutter run -d chrome' to test in browser" -ForegroundColor Cyan
    Write-Host "Run 'flutter run -d windows' to test on desktop" -ForegroundColor Cyan
    Write-Host "Run 'flutter build apk' to build Android APK" -ForegroundColor Cyan

} else {
    Write-Host "Flutter SDK not found at $flutterZip" -ForegroundColor Red
    Write-Host "Please download from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
}
