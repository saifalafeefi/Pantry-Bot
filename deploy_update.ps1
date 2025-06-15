param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$ServerUser = "smiley",
    [string]$ServerDomain = "pantrybot.anonstorage.org"
)

# PantryBot Update Deployment Script (PowerShell)
# Usage: .\deploy_update.ps1 -Version "1.4.2"

Write-Host "🚀 Starting deployment for version $Version..." -ForegroundColor Green

try {
    # Update version in pubspec.yaml
    Write-Host "📝 Updating pubspec.yaml version..." -ForegroundColor Yellow
    Set-Location pantrybot
    $buildNumber = [int](Get-Date -UFormat %s)
    $pubspecContent = Get-Content pubspec.yaml -Raw
    $pubspecContent = $pubspecContent -replace "version: .*", "version: $Version+$buildNumber"
    Set-Content pubspec.yaml $pubspecContent

    # Update version in api.py
    Write-Host "📝 Updating api.py version..." -ForegroundColor Yellow
    Set-Location ..
    $apiContent = Get-Content api.py -Raw
    $apiContent = $apiContent -replace 'APP_VERSION = ".*"', "APP_VERSION = `"$Version`""
    Set-Content api.py $apiContent

    # Build the APK
    Write-Host "🔨 Building APK..." -ForegroundColor Yellow
    Set-Location pantrybot
    flutter clean
    flutter pub get
    flutter build apk --release

    # Copy APK to releases folder
    Write-Host "📦 Copying APK to releases folder..." -ForegroundColor Yellow
    Set-Location ..
    Copy-Item "pantrybot\build\app\outputs\flutter-apk\app-release.apk" "releases\pantrybot_v$Version.apk"

    # Deploy to server if requested
    if ($env:DEPLOY_TO_SERVER -eq "1") {
        Write-Host "🚁 Deploying to server $ServerUser@$ServerDomain..." -ForegroundColor Yellow
        
        # Check if files exist before uploading
        Write-Host "🔍 Checking files..." -ForegroundColor Cyan
        if (-not (Test-Path "api.py")) {
            Write-Host "❌ api.py not found in current directory!" -ForegroundColor Red
            Get-ChildItem . | Where-Object {$_.Name -like "*.py"} | ForEach-Object { Write-Host "Found: $($_.Name)" }
            throw "api.py not found!"
        }
        Write-Host "✅ api.py found" -ForegroundColor Green
        
        $apkPath = "releases\pantrybot_v$Version.apk"
        if (-not (Test-Path $apkPath)) {
            Write-Host "❌ APK file not found: $apkPath" -ForegroundColor Red
            Get-ChildItem releases\ | ForEach-Object { Write-Host "Found: $($_.Name)" }
            throw "APK file not found: $apkPath"
        }
        Write-Host "✅ APK file found: $apkPath" -ForegroundColor Green
        
        # Upload api.py to home directory first
        Write-Host "📤 Uploading api.py..." -ForegroundColor Cyan
        $scpTarget = "$ServerUser@$ServerDomain" + ":/home/$ServerUser/"
        & scp api.py $scpTarget
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to upload api.py (exit code: $LASTEXITCODE)"
        }
        
        # Upload APK to home directory
        Write-Host "📤 Uploading APK..." -ForegroundColor Cyan
        & scp "releases\pantrybot_v$Version.apk" $scpTarget
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to upload APK (exit code: $LASTEXITCODE)"
        }
        
        # Verify files were uploaded
        Write-Host "🔍 Verifying upload..." -ForegroundColor Cyan
        $fileCheck = ssh "$ServerUser@$ServerDomain" "ls -la /home/$ServerUser/api.py /home/$ServerUser/pantrybot_v$Version.apk"
        if ($LASTEXITCODE -ne 0) {
            throw "Files not found on server after upload"
        }
        
        # Move files to pantrybot directory
        Write-Host "📁 Moving files to pantrybot directory..." -ForegroundColor Cyan
        ssh "$ServerUser@$ServerDomain" "sudo cp /home/$ServerUser/api.py /home/$ServerUser/pantrybot/"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to move api.py"
        }
        
        ssh "$ServerUser@$ServerDomain" "sudo cp /home/$ServerUser/pantrybot_v$Version.apk /home/$ServerUser/pantrybot/"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to move APK"
        }
        
        # Restart service
        Write-Host "🔄 Restarting service..." -ForegroundColor Cyan
        ssh "$ServerUser@$ServerDomain" "sudo systemctl restart pantrybot-api"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to restart service"
        }
        
        # Wait for service to start
        Write-Host "⏳ Waiting for service to start..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3
        
        # Clean up temporary files in home directory
        Write-Host "🧹 Cleaning up..." -ForegroundColor Cyan
        ssh "$ServerUser@$ServerDomain" "rm -f /home/$ServerUser/api.py /home/$ServerUser/pantrybot_v$Version.apk"
        
        Write-Host "✅ Deployed to server successfully!" -ForegroundColor Green
        
        # Test the deployment
        Write-Host "🧪 Testing deployment..." -ForegroundColor Cyan
        $testResult = ssh "$ServerUser@$ServerDomain" "curl -s http://localhost:5000/api/version"
        if ($testResult -match $Version) {
            Write-Host "✅ Server is serving version $Version!" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Server response: $testResult" -ForegroundColor Yellow
            Write-Host "❌ Server test failed!" -ForegroundColor Red
            throw "Deployment verification failed"
        }
    } else {
        Write-Host "⚠️  Server deployment skipped. Set `$env:DEPLOY_TO_SERVER=1 to deploy automatically." -ForegroundColor Yellow
    }

    Write-Host "✅ Deployment complete!" -ForegroundColor Green
    Write-Host "📱 APK location: releases\pantrybot_v$Version.apk" -ForegroundColor Cyan
    Write-Host "📋 Version: $Version" -ForegroundColor Cyan
    Write-Host "🎉 Ready for OTA updates!" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "🚀 Next Steps:" -ForegroundColor Yellow
    Write-Host "git add . && git commit -m 'Version $Version' && git push" -ForegroundColor White

} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} 