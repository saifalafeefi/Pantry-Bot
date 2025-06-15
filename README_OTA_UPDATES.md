# 🔄 PantryBot OTA (Over-The-Air) Updates

simply use this format: .\deploy_update.ps1 VERSION_NUMBER

example: .\deploy_update.ps1 1.5.0

## 📈 Version Management

### Version Format
- Use semantic versioning: `MAJOR.MINOR.PATCH`
- Build numbers are automatically generated
- Example: `1.4.2+1234567890`

## How It Works

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

### Client-Side Checks

```dart
// Enable debug mode in UpdateService
print('Current version: $currentVersion');
print('Server version: $serverVersion');
print('Update available: ${_isNewerVersion(serverVersion, currentVersion)}');
```