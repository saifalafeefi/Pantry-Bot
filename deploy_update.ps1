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
        
        # Upload api.py to server
        scp api.py "$ServerUser@$ServerDomain":/tmp/
        
        # Move api.py and restart service
        ssh "$ServerUser@$ServerDomain" "sudo cp /tmp/api.py /home/$ServerUser/pantrybot/ && sudo systemctl restart pantrybot-api"
        
        Write-Host "✅ Deployed to server successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Server deployment skipped. Set `$env:DEPLOY_TO_SERVER=1 to deploy automatically." -ForegroundColor Yellow
    }

    Write-Host "✅ Deployment complete!" -ForegroundColor Green
    Write-Host "📱 APK location: releases\pantrybot_v$Version.apk" -ForegroundColor Cyan
    Write-Host "🔗 Update URL: https://$ServerDomain`:8443/apk" -ForegroundColor Cyan
    Write-Host "📋 Version: $Version" -ForegroundColor Cyan
    Write-Host "🎉 Ready for OTA updates!" -ForegroundColor Green

} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} 