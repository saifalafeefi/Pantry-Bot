import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInitialization = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitialization = DarwinInitializationSettings();
    
    const initializationSettings = InitializationSettings(
      android: androidInitialization,
      iOS: iosInitialization,
    );

    await _notifications.initialize(initializationSettings);
    
    // Request permissions
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pantrybot_expiry',
      'Expiry Notifications',
      channelDescription: 'Notifications for expiring pantry items',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, notificationDetails);
  }

  static Future<void> checkExpiringItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 0;
      final baseUrl = 'https://pantrybot.anonstorage.org:8443';
      
      // Get notification preferences
      final daysAhead = prefs.getInt('notification_days_ahead') ?? 3;
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      
      if (!notificationsEnabled || userId == 0) return;

      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final response = await httpClient.get(
        Uri.parse('$baseUrl/pantry/expiring?user_id=$userId&days=$daysAhead'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> expiringItems = jsonDecode(response.body);
        
        for (int i = 0; i < expiringItems.length && i < 3; i++) {
          final item = expiringItems[i];
          final itemName = item['name'];
          final itemType = item['type'];
          final daysUntilExpiry = item['days_until_expiry'];
          
          String message;
          String title;
          if (daysUntilExpiry < 0) {
            message = '$itemName expired ${(-daysUntilExpiry)} day(s) ago!';
            title = '🚨 Expired Item';
          } else if (daysUntilExpiry == 0) {
            message = '$itemName expires today!';
            title = '⚠️ Expires Today';
          } else if (daysUntilExpiry == 1) {
            message = '$itemName expires tomorrow!';
            title = '📅 Expires Tomorrow';
          } else {
            message = '$itemName expires in $daysUntilExpiry days';
            title = '🔔 Expiring Soon';
          }

          await showNotification(
            id: 1000 + i,
            title: title,
            body: message,
          );
        }
        
        // Show summary if there are many expiring items
        if (expiringItems.length > 3) {
          await showNotification(
            id: 999,
            title: '📦 Multiple Items Expiring',
            body: 'You have ${expiringItems.length} items expiring soon. Check your pantry!',
          );
        }
      }
    } catch (e) {
      print('Error checking expiring items: $e');
    }
  }

  static Future<void> testNotification() async {
    await showNotification(
      id: 999,
      title: '🧪 Test Notification',
      body: 'PantryBot notifications are working!',
    );
  }
} 