# 🔄 PantryBot OTA (Over-The-Air) Updates

This document explains how to use the automatic update system for PantryBot, which allows you to push app updates to users without manually distributing APK files.

## 🚀 How It Works

The OTA update system consists of three main components:

1. **Backend API** - Serves version information and APK files
2. **Flutter App** - Checks for updates and downloads/installs them
3. **Deployment Scripts** - Automates the build and deployment process

### Update Flow

1. App checks server for newer version on startup (once per day)
2. If update available, shows dialog to user
3. User can choose to update now or later
4. App downloads APK from server
5. App installs new version automatically
6. User sees updated app immediately

## 📋 Setup Instructions

### 1. Server Configuration

The server needs to host APK files and provide version information:

**API Endpoints Added:**
- `GET /version` - Returns current app version
- `GET /apk` - Downloads the latest APK file

**File Structure:**
```
/home/pi/Pantry-Bot/
├── api.py (updated with version endpoints)
├── releases/
│   ├── pantrybot_v1.4.1.apk
│   ├── pantrybot_v1.4.2.apk
│   └── ...
└── deploy_update.sh
```

### 2. Flutter App Changes

**Dependencies Added:**
- `package_info_plus` - Get current app version
- `dio` - Download APK files
- `url_launcher` - Launch APK installer
- `path_provider` - File system access
- `permission_handler` - Installation permissions

**Permissions Added (Android):**
- `REQUEST_INSTALL_PACKAGES` - Install APKs
- `WRITE_EXTERNAL_STORAGE` - Download files
- `READ_EXTERNAL_STORAGE` - Access downloads

**Features:**
- Automatic update check on app start
- Manual update check button (update icon in app bar)
- Progress dialogs during download
- Error handling and user feedback

### 3. Update Server IP Address

⚠️ **Important:** Update the server IP in the UpdateService:

```dart
// In lib/services/update_service.dart, line 11:
static const String baseUrl = 'http://YOUR_SERVER_IP:8080';
```

Replace `YOUR_SERVER_IP` with your Raspberry Pi's actual IP address.

## 🛠️ Deployment Process

### Option 1: PowerShell Script (Windows)

```powershell
# Deploy new version
.\deploy_update.ps1 -Version "1.4.2"

# Deploy and upload to server automatically
$env:DEPLOY_TO_SERVER=1
.\deploy_update.ps1 -Version "1.4.2" -ServerUser "pi" -ServerIP "192.168.1.100"
```

### Option 2: Bash Script (Linux/Mac)

```bash
# Deploy new version
./deploy_update.sh 1.4.2

# Deploy and upload to server automatically
DEPLOY_TO_SERVER=1 ./deploy_update.sh 1.4.2 pi 192.168.1.100
```

### Option 3: Manual Process

1. **Update versions:**
   ```bash
   # Update pubspec.yaml
   version: 1.4.2+1234567890

   # Update api.py
   APP_VERSION = "1.4.2"
   ```

2. **Build APK:**
   ```bash
   cd pantrybot
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

3. **Copy to releases:**
   ```bash
   cp pantrybot/build/app/outputs/flutter-apk/app-release.apk releases/pantrybot_v1.4.2.apk
   ```

4. **Deploy to server:**
   ```bash
   scp releases/pantrybot_v1.4.2.apk pi@192.168.1.100:/home/pi/Pantry-Bot/releases/
   scp api.py pi@192.168.1.100:/home/pi/Pantry-Bot/
   ssh pi@192.168.1.100 "sudo systemctl restart pantrybot-api"
   ```

## 📱 User Experience

### Automatic Updates
- App checks for updates once per day
- Non-intrusive notification when update available
- Users can choose to update now or later

### Manual Updates
- Update button in app bar (update icon)
- Shows "You are on the latest version" if no updates
- Progress indicators during download

### Installation Process
1. App requests installation permissions
2. Downloads APK to device storage
3. Launches system installer
4. User confirms installation
5. New version launches automatically

## 🔧 Troubleshooting

### Common Issues

**Update Check Fails:**
- Check server IP address in UpdateService
- Ensure server is running and accessible
- Check firewall settings on server

**Download Fails:**
- Verify APK file exists in releases folder
- Check file permissions on server
- Ensure enough storage space on device

**Installation Fails:**
- Enable "Install from Unknown Sources" in Android settings
- Grant installation permissions when prompted
- Check if APK file is corrupted

**App Won't Install:**
- Uninstall old version first (if needed)
- Check Android version compatibility
- Verify APK signature matches

### Server-Side Checks

```bash
# Check if API is running
curl http://localhost:8080/version

# Check if APK file exists
ls -la /home/pi/Pantry-Bot/releases/

# Check service status
sudo systemctl status pantrybot-api

# View logs
sudo journalctl -u pantrybot-api -f
```

### Client-Side Checks

```dart
// Enable debug mode in UpdateService
print('Current version: $currentVersion');
print('Server version: $serverVersion');
print('Update available: ${_isNewerVersion(serverVersion, currentVersion)}');
```

## 🔒 Security Considerations

1. **HTTPS Recommended:** Use HTTPS for production deployments
2. **APK Signing:** Ensure APKs are properly signed
3. **Permissions:** Only request necessary permissions
4. **File Validation:** Consider adding APK checksum verification
5. **Network Security:** Secure your server endpoints

## 📈 Version Management

### Version Format
- Use semantic versioning: `MAJOR.MINOR.PATCH`
- Build numbers are automatically generated
- Example: `1.4.2+1234567890`

### Release Notes
Consider adding a release notes endpoint:
```python
@app.route('/release-notes/<version>')
def get_release_notes(version):
    return jsonify({
        'version': version,
        'notes': 'Bug fixes and improvements'
    })
```

## 🎯 Best Practices

1. **Test Updates:** Always test on a few devices first
2. **Gradual Rollout:** Consider staged rollouts for major updates
3. **Backup Strategy:** Keep previous versions available
4. **User Communication:** Inform users about update benefits
5. **Monitoring:** Track update success rates

## 📊 Monitoring Updates

Track update metrics:
- Update check frequency
- Download success rates
- Installation completion rates
- User adoption of new versions

## 🔄 Rollback Strategy

If an update causes issues:

1. **Quick Fix:** Deploy hotfix version
2. **Rollback:** Change server version to previous stable
3. **Communication:** Notify users about issues

```python
# Temporarily rollback in api.py
APP_VERSION = "1.4.1"  # Previous stable version
```

## 📞 Support

For issues with OTA updates:
1. Check logs on both client and server
2. Verify network connectivity
3. Test with manual APK installation
4. Review permissions and settings

---

**Ready to deploy updates instantly!** 🚀

No more manual APK distribution - just run the deployment script and all users get the update automatically. 