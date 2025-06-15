import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UpdateService {
  static const String baseUrl = 'https://pantrybot.anonstorage.org:8443';
  static const String versionEndpoint = '/version';
  static const String apkDownloadUrl = 'https://github.com/yourusername/Pantry-Bot/releases/latest/download/pantrybot.apk'; // You'll update this
  
  final Dio _dio = Dio();

  UpdateService() {
    // Configure Dio to accept self-signed certificates
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };
  }

  Future<bool> checkForUpdates() async {
    try {
      // Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      
      // Get server version
      Response response = await _dio.get('$baseUrl$versionEndpoint');
      String serverVersion = response.data['version'];
      
      // Compare versions
      return _isNewerVersion(serverVersion, currentVersion);
    } catch (e) {
      print('Error checking for updates: $e');
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
      // Request permissions
      await _requestPermissions();
      
      // Show download dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Downloading Update'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Downloading new version...'),
              ],
            ),
          );
        },
      );

      // Get downloads directory
      Directory? downloadsDir = await getExternalStorageDirectory();
      String apkPath = '${downloadsDir!.path}/pantrybot_update.apk';

      // Download APK
      await _dio.download(
        apkDownloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      // Close download dialog
      Navigator.of(context).pop();

      // Install APK
      await _installApk(apkPath);
      
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorDialog(context, 'Failed to download update: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.requestInstallPackages.request();
      await Permission.storage.request();
    }
  }

  Future<void> _installApk(String apkPath) async {
    if (Platform.isAndroid) {
      final Uri uri = Uri.file(apkPath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
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
} 