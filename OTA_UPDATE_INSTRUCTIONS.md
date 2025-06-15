# PantryBot OTA Update System

This document explains how to use the Over-The-Air (OTA) update system for PantryBot Flutter app.

## Overview

The OTA system allows users to automatically receive app updates without manual APK distribution. Updates are served from your Raspberry Pi server.

## System Architecture

- **Flutter App** checks for updates on startup
- **Raspberry Pi** serves version info and APK files via HTTPS
- **Apache** proxies requests to Flask API
- **Users** get automatic update notifications

## Complete Update Workflow

### 1. Development & GitHub Push

```bash
# Make your code changes
git add .
git commit -m "Add new feature"
git push
```

### 2. Build & Deploy New Version

```powershell
# Update version and deploy to Pi in one command
$env:DEPLOY_TO_SERVER=1; .\deploy_update.ps1 -Version "1.4.3"
```

**This script automatically:**
- Updates `pubspec.yaml` version number
- Builds Flutter APK release
- Copies APK to Pi at `/home/smiley/pantrybot/`
- Updates `api.py` version number on Pi
- Restarts Flask API service

### 3. Pi Server State

After deployment, your Pi has:

**Flask API** (port 5000):
- `/api/version` → returns `{"version": "1.4.3"}`
- `/api/apk` → serves the APK file

**Apache HTTPS Proxy**:
- `https://pantrybot.anonstorage.org:8443/api/version`
- `https://pantrybot.anonstorage.org:8443/api/apk`

**APK Storage**:
- File stored at `/home/smiley/pantrybot/pantrybot_v1.4.3.apk`

### 4. User Update Process

When user opens the app:

1. **App checks** server version via HTTPS API
2. **Compares** server version vs installed version
3. **If newer version exists:**
   - Shows update dialog to user
   - Downloads APK from server
   - Prompts user to install update
4. **User taps install** → Android installs new version

## Quick Commands

### Deploy New Version
```powershell
$env:DEPLOY_TO_SERVER=1; .\deploy_update.ps1 -Version "1.4.3"
```

### Test OTA System
```powershell
python test_ota.py
```

### Check Server Status
```bash
ssh smiley@pantrybot.anonstorage.org "sudo systemctl status pantrybot-api"
```

### Manual APK Copy (if needed)
```bash
scp releases/pantrybot_v1.4.3.apk smiley@pantrybot.anonstorage.org:/home/smiley/pantrybot/
```

## Server Configuration

### Apache Proxy Setup
The following configuration routes `/api/*` requests to Flask:

```apache
# OTA Update API Proxy
ProxyPreserveHost On
ProxyRequests Off

# Proxy /api/* requests to Flask app on localhost:5000
ProxyPass /api/ http://localhost:5000/api/
ProxyPassReverse /api/ http://localhost:5000/api/

# Also proxy direct /version endpoint
ProxyPass /version http://localhost:5000/version
ProxyPassReverse /version http://localhost:5000/version
```

### Flask API Endpoints
```python
APP_VERSION = "1.4.3"

@app.route('/api/version')
def api_version():
    return jsonify({"version": APP_VERSION})

@app.route('/api/apk')
def api_apk():
    apk_path = f"/home/smiley/pantrybot/pantrybot_v{APP_VERSION}.apk"
    return send_file(apk_path, as_attachment=True)
```

## Troubleshooting

### Test Endpoints
```bash
# Test version endpoint
curl -k https://pantrybot.anonstorage.org:8443/api/version

# Test APK endpoint (should return binary data)
curl -k https://pantrybot.anonstorage.org:8443/api/apk --head
```

### Common Issues

**404 Error on /api/version:**
- Check if Flask service is running: `sudo systemctl status pantrybot-api`
- Restart service: `sudo systemctl restart pantrybot-api`

**APK Download Fails:**
- Ensure APK file exists on Pi: `ls -la /home/smiley/pantrybot/*.apk`
- Check file permissions: `sudo chmod 644 /home/smiley/pantrybot/*.apk`

**Apache Proxy Issues:**
- Check Apache status: `sudo systemctl status apache2`
- Verify proxy modules: `sudo a2enmod proxy proxy_http`

## Benefits

✅ **No manual APK distribution**  
✅ **Users always get latest version**  
✅ **One-command deployment**  
✅ **Automatic update notifications**  
✅ **Private server control**  

## Security Notes

- Uses HTTPS with self-signed certificate
- APK served from private Pi server
- No GitHub tokens in mobile app
- Direct server control over updates

---

**Your Pi acts as a private app store - users automatically get updates from your server!** 