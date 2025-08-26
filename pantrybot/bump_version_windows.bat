@echo off

if "%~2"=="" (
    echo Usage: bump_version_simple.bat version build
    echo Example: bump_version_simple.bat 1.5.0 27
    pause
    exit /b 1
)

set VERSION_NAME=%1
set BUILD_NUMBER=%2

echo Updating to %VERSION_NAME% build %BUILD_NUMBER%...

powershell -ExecutionPolicy Bypass -Command "(Get-Content pubspec.yaml) -replace '^version: .*', 'version: %VERSION_NAME%+%BUILD_NUMBER%' | Set-Content pubspec.yaml"

echo Running flutter clean...
call flutter clean

echo Running flutter pub get...
call flutter pub get

echo ✅ Version successfully updated to %VERSION_NAME% (%BUILD_NUMBER%)
echo ✅ You can now build manually: flutter build apk --release
pause