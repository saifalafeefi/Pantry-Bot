import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UpdateService {
  static const String githubApiUrl = 'https://api.github.com/repos/saifalafeefi/Pantry-Bot/releases/latest';
  static const String apkDownloadUrl = 'https://github.com/saifalafeefi/Pantry-Bot/releases/latest/download/pantrybot.apk';
  
  final Dio _dio = Dio();

  UpdateService() {
    // Configure Dio to accept self-signed certificates
    _dio.options.connectTimeout = Duration(seconds: 10);
    _dio.options.receiveTimeout = Duration(seconds: 10);
    
    // Accept self-signed certificates for your Pi server
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host == 'pantrybot.anonstorage.org'; // Only accept for your server
      };
      return client;
    };
  }

  Future<bool> checkForUpdates() async {
    try {
      // Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      
      print('🔍 Checking for updates...');
      print('📱 Current app version: $currentVersion');
      
      // For private repos, we'll use a simple version check against your Pi
      // This is easier than dealing with GitHub tokens in the app
      Response response = await _dio.get(
        'https://pantrybot.anonstorage.org:8443/api/version',
        options: Options(
          validateStatus: (status) => status! < 500,
        ),
      );
      
      print('🌐 Server response status: ${response.statusCode}');
      print('📦 Server response data: ${response.data}');
      
      String latestVersion;
      if (response.statusCode == 200 && response.data is Map) {
        latestVersion = response.data['version'];
      } else {
        // Fallback: assume current version is latest if can't check
        print('❌ Could not check for updates, assuming current version is latest');
        return false;
      }
      
      print('🆕 Server version: $latestVersion');
      print('📊 Comparing versions: $currentVersion vs $latestVersion');
      
      // Compare versions
      bool hasUpdate = _isNewerVersion(latestVersion, currentVersion);
      print('🎯 Update available: $hasUpdate');
      
      return hasUpdate;
    } catch (e) {
      print('💥 Error checking for updates: $e');
      print('🔍 Error type: ${e.runtimeType}');
      return false;
    }
  }

  bool _isNewerVersion(String serverVersion, String currentVersion) {
    List<int> serverParts = serverVersion.split('.').map(int.parse).toList();
    List<int> currentParts = currentVersion.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      if (serverParts[i] > currentParts[i]) return true;
      if (serverParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<void> showUpdateDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: const Text('A new version of PantryBot is available. Would you like to update now?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                Navigator.of(context).pop();
                downloadAndInstallUpdate(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> downloadAndInstallUpdate(BuildContext context) async {
    try {
      print('🚀 Starting update process...');
      
      // Request permissions
      print('🔐 Requesting permissions...');
      await _requestPermissions();
      print('✅ Permissions granted');
      
      // Show download dialog with progress and live debug logs
      ValueNotifier<String> progressText = ValueNotifier('Preparing download...');
      ValueNotifier<List<String>> debugLogs = ValueNotifier(['🚀 Starting update process...']);
      
      void addLog(String message) {
        print(message); // Still print to console
        debugLogs.value = [...debugLogs.value, message];
      }
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Downloading Update'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: progressText,
                    builder: (context, text, child) {
                      return Text(text, style: TextStyle(fontWeight: FontWeight.bold));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Debug Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Container()),
                      ElevatedButton.icon(
                        onPressed: () {
                          String allLogs = debugLogs.value.join('\n');
                          Clipboard.setData(ClipboardData(text: allLogs));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logs copied to clipboard!')),
                          );
                        },
                        icon: Icon(Icons.copy, size: 16),
                        label: Text('Copy Logs'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.black87,
                      ),
                      child: ValueListenableBuilder<List<String>>(
                        valueListenable: debugLogs,
                        builder: (context, logs, child) {
                          return ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              return Text(
                                logs[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: Colors.green,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Get downloads directory - use public Downloads folder for OnePlus compatibility
      progressText.value = 'Setting up download location...';
      addLog('🔐 Permissions granted');
      Directory? downloadsDir;
      String apkPath;
      
      try {
        // Try to use public Downloads directory (better for OnePlus/newer Android)
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          addLog('📁 Public Downloads not found, using app directory');
          // Fallback to app-specific directory
          downloadsDir = await getExternalStorageDirectory();
        } else {
          addLog('📁 Using public Downloads directory');
        }
        apkPath = '${downloadsDir!.path}/pantrybot_update.apk';
      } catch (e) {
        addLog('❌ Download directory error: $e');
        // Last resort fallback
        downloadsDir = await getExternalStorageDirectory();
        apkPath = '${downloadsDir!.path}/pantrybot_update.apk';
      }
      
      addLog('📁 Download path: $apkPath');
      
      // Ensure directory exists
      await Directory(downloadsDir.path).create(recursive: true);
      addLog('✅ Download directory ready');

      // Download APK from your server (easier for private repos)
      progressText.value = 'Connecting to server...';
      addLog('📥 Starting download from: https://pantrybot.anonstorage.org:8443/api/apk');
      
      await _dio.download(
        'https://pantrybot.anonstorage.org:8443/api/apk',
        apkPath,
        options: Options(
          receiveTimeout: Duration(minutes: 5), // 5 minute timeout
          sendTimeout: Duration(seconds: 30),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = (received / total * 100);
            progressText.value = 'Downloading... ${progress.toStringAsFixed(0)}%';
            if (progress % 10 == 0) { // Log every 10%
              addLog('📊 Download progress: ${progress.toStringAsFixed(0)}% ($received/$total bytes)');
            }
          } else {
            progressText.value = 'Downloading... ${(received / 1024 / 1024).toStringAsFixed(1)} MB';
            addLog('📊 Downloaded: $received bytes');
          }
        },
      );
      
      progressText.value = 'Download complete! Preparing installation...';
      addLog('✅ Download completed successfully');

      // Install APK
      addLog('🔧 Starting APK installation...');
      await _installApk(apkPath, addLog);
      addLog('✅ Install process initiated');
      
      // Close download dialog after install attempt
      Navigator.of(context).pop();
      
    } catch (e) {
      print('💥 Update failed with error: $e');
      print('🔍 Error details: ${e.toString()}');
      Navigator.of(context).pop();
      _showErrorDialog(context, 'Update failed: ${e.toString()}');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.requestInstallPackages.request();
      await Permission.storage.request();
    }
  }

  Future<void> _installApk(String apkPath, Function(String) addLog) async {
    if (Platform.isAndroid) {
      addLog('🔧 Installing APK from: $apkPath');
      
      // Check if file exists
      File apkFile = File(apkPath);
      if (!await apkFile.exists()) {
        addLog('❌ APK file not found at $apkPath');
        throw Exception('APK file not found at $apkPath');
      }
      
      addLog('📁 APK file size: ${await apkFile.length()} bytes');
      
      try {
        // Method 1: Try native Android method channel (bypasses OnePlus intent restrictions)
        addLog('🔄 Trying native Android install method (OnePlus bypass)...');
        
        const platform = MethodChannel('com.example.pantrybot/installer');
        try {
          final result = await platform.invokeMethod('installApk', {'apkPath': apkPath});
          addLog('🚀 Native install result: $result');
          
          if (result == true) {
            addLog('✅ APK installer launched via native method');
            addLog('⏳ Waiting for system install dialog...');
            return; // Success!
          }
        } catch (e) {
          addLog('❌ Native method failed: $e');
        }
        
        // Method 2: Try simple file URI (sometimes works on OnePlus)
        addLog('🔄 Trying simple file URI approach...');
        String fileUri = 'file://$apkPath';
        
        bool launched = await Future.any([
          launchUrl(Uri.parse(fileUri), mode: LaunchMode.externalApplication),
          Future.delayed(Duration(seconds: 5), () => false),
        ]);
        
        addLog('🚀 File URI result: $launched');
        
        if (!launched) {
          // Method 3: Try content URI with FileProvider
          addLog('🔄 Trying FileProvider content URI...');
          String fileName = apkPath.split('/').last;
          String contentUri = 'content://com.example.pantrybot.fileprovider/external_files/$fileName';
          
          launched = await Future.any([
            launchUrl(Uri.parse(contentUri), mode: LaunchMode.externalApplication),
            Future.delayed(Duration(seconds: 8), () => false),
          ]);
          
          addLog('🚀 Content URI result: $launched');
        }
        
        if (!launched) {
          // Method 4: Try opening Downloads folder directly
          addLog('🔄 Trying to open Downloads folder...');
          String downloadsUri = 'content://com.android.externalstorage.documents/document/primary%3ADownload';
          
          launched = await Future.any([
            launchUrl(Uri.parse(downloadsUri), mode: LaunchMode.externalApplication),
            Future.delayed(Duration(seconds: 5), () => false),
          ]);
          
          addLog('🚀 Downloads folder result: $launched');
          
          if (launched) {
            addLog('📁 Downloads folder opened - look for pantrybot_update.apk');
            addLog('👆 Tap the APK file to install');
          }
        }
        
        if (launched) {
          addLog('✅ Install process initiated');
          addLog('⏳ OnePlus may take a moment to show install dialog...');
          
          // Give OnePlus time to process
          await Future.delayed(Duration(seconds: 3));
          
          addLog('💡 If install dialog doesn\'t appear:');
          addLog('   1. Go to Downloads folder manually');
          addLog('   2. Find pantrybot_update.apk');
          addLog('   3. Tap to install');
          addLog('   4. Enable "Install unknown apps" if prompted');
        } else {
          // All methods failed - provide manual instructions
          addLog('🔄 All automatic methods failed');
          addLog('📱 Manual Install Required:');
          addLog('   1. Open File Manager or Downloads app');
          addLog('   2. Navigate to Downloads folder');
          addLog('   3. Find pantrybot_update.apk (${(await apkFile.length() / 1024 / 1024).toStringAsFixed(1)} MB)');
          addLog('   4. Tap the APK file');
          addLog('   5. If blocked: Settings > Security > Install unknown apps');
          addLog('   6. Enable for File Manager');
          addLog('   7. Try installing APK again');
          
          // Don't throw error - just show instructions
          addLog('✅ APK ready for manual install in Downloads folder');
        }
        
      } catch (e) {
        addLog('❌ Install error: $e');
        addLog('🔍 Error type: ${e.runtimeType}');
        
        // Always provide manual fallback for OnePlus
        addLog('🔧 OnePlus Manual Install:');
        addLog('   • APK location: $apkPath');
        addLog('   • File size: ${(await apkFile.length() / 1024 / 1024).toStringAsFixed(1)} MB');
        addLog('   • Open Downloads folder and tap the APK');
        addLog('   • Enable "Install unknown apps" if needed');
        
        // Don't throw - let user install manually
        addLog('✅ APK downloaded successfully - install manually');
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> checkForUpdatesOnStart(BuildContext context) async {
    // Check if we should check for updates (not more than once per day)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastCheckDate = prefs.getString('lastUpdateCheck');
    String today = DateTime.now().toIso8601String().split('T')[0];
    
    if (lastCheckDate == today) {
      return; // Already checked today
    }

    bool hasUpdate = await checkForUpdates();
    if (hasUpdate) {
      await showUpdateDialog(context);
    }
    
    // Save last check date
    await prefs.setString('lastUpdateCheck', today);
  }

  // Force update check (ignores daily limit)
  Future<void> forceUpdateCheck(BuildContext context) async {
    bool hasUpdate = await checkForUpdates();
    if (hasUpdate) {
      await showUpdateDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version')),
      );
    }
  }
} 