import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'screens/login_screen.dart';
import 'screens/pantry_items_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/urgency_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Removed updraft_config.dart - not needed for current implementation

// API base URL
const String baseUrl = 'https://pantrybot.anonstorage.org:8443';

// Global notification plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Request Android 13+ notification permission
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }
  
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS handles this differently
  }
  
  static Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'pantrybot_test',
          'PantryBot Test',
          channelDescription: 'Test notifications from PantryBot',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await flutterLocalNotificationsPlugin.show(
      0,
      '🤖 PantryBot Test',
      'Notifications are working! You\'ll get alerts for important grocery items.',
      platformChannelSpecifics,
    );
  }
  
  static Future<void> showGroceryReminder(String itemName, String urgencyLevel) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'pantrybot_grocery',
          'Grocery Reminders',
          channelDescription: 'Reminders for important grocery items',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // Unique ID
      '🛒 Grocery Reminder',
      '$itemName ($urgencyLevel priority) - Don\'t forget to buy this!',
      platformChannelSpecifics,
    );
  }
}

const Map<String, List<String>> categoryMetrics = {
  'Dairy': ['Litre', 'ml', 'Piece', 'Pack'],
  'Meats': ['Gram', 'Kg', 'Piece', 'Pack'],
  'Vegetables': ['Gram', 'Kg', 'Piece', 'Bunch', 'Pack'],
  'Fruits': ['Gram', 'Kg', 'Piece', 'Bunch', 'Pack'],
  'Grains': ['Gram', 'Kg', 'Pack', 'Bag'],
  'Sweets': ['Piece', 'Pack', 'Gram'],
  'Oils': ['Litre', 'ml', 'Bottle'],
  'Drinks': ['Litre', 'ml', 'Bottle', 'Can'],
  'Medicine': ['Piece', 'Pack', 'ml'],
  'Cleaning': ['Piece', 'Pack', 'Litre', 'ml'],
  'Electronics': ['Piece', 'Pack'],
  'Other': ['Piece', 'Pack'],
};

enum SortOption {
  newest,
  oldest,
  nameAZ,
  nameZA,
  categoryAZ,
  categoryZA,
  unchecked,
  aToZ,
  zToA,
  category,
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  await NotificationService.initialize();
  
  // Android: Pi server OTA, iOS: Updraft distribution
  print('OTA update capability enabled - Android: Pi server, iOS: Updraft');
  
  print('PantryBot starting up - version 1.6.2 build 28');
  
  // Load saved login state from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final isAdmin = prefs.getBool('isAdmin') ?? false;
  final userId = prefs.getInt('userId') ?? 0;
  final username = prefs.getString('username') ?? '';
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(MyApp(
    isLoggedIn: isLoggedIn, 
    isAdmin: isAdmin,
    userId: userId,
    username: username,
    isDarkMode: isDarkMode,
  ));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool isAdmin;
  final int userId;
  final String username;
  final bool isDarkMode;

  const MyApp({
    Key? key, 
    required this.isLoggedIn, 
    required this.isAdmin,
    this.userId = 0,
    this.username = '',
    this.isDarkMode = false,
  }) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
  
  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    // Theme persistence removed for iOS compatibility
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PantryBot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.blue.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey.shade900,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey.shade800,
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.isLoggedIn 
          ? MainMenuScreen(
              isAdmin: widget.isAdmin,
              userId: widget.userId,
              username: widget.username,
            ) 
          : LoginScreen(),
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  final bool isAdmin;
  final int userId;  
  final String username;

  const MainMenuScreen({
    Key? key,
    required this.isAdmin,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  _MainMenuScreenState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    // Check for updates and notifications after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid) {
        _checkForUpdatesAutomatically();
      }
      _checkNotificationPermission();
    });
  }
  
  // Platform-specific update initialization
  Future<void> _checkForUpdatesAutomatically() async {
    try {
      if (Platform.isAndroid) {
        // Android: Pi server-based OTA with manual check via update button
        print('Android Pi-based OTA updates ready for manual check');
      } else if (Platform.isIOS) {
        // iOS: Updraft SDK handles automatic update checks and notifications
        print('iOS Updraft SDK handling automatic update checks...');
      }
    } catch (e) {
      print('Error during update initialization: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Clear saved login state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('isAdmin');
    await prefs.remove('userId');
    await prefs.remove('username');
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen())
    );
  }

  Future<void> _manualUpdateCheck() async {
    if (Platform.isAndroid) {
      // Check server for latest version
      try {
        final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
        final ioClient = IOClient(client);
        
        final response = await ioClient.get(
          Uri.parse('$baseUrl/api/apk/latest/info'),
        ).timeout(Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final serverVersion = data['version'] as String? ?? '1.5.0';
          final serverBuild = (data['build'] as num?)?.toInt() ?? 1;
          
          // Get current app version dynamically from package info
          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = packageInfo.version;
          final currentBuild = int.parse(packageInfo.buildNumber);
          
          // Compare versions
          if (_isNewerVersion(serverVersion, serverBuild, currentVersion, currentBuild)) {
            _showUpdateDialog('$serverVersion (Build $serverBuild)', 'Available now');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ You have the latest version (v$currentVersion+$currentBuild)'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw Exception('Server returned ${response.statusCode}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Could not check for updates: ${e.toString()}'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // iOS
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🍎 iOS updates are handled through Updraft distribution'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  bool _isNewerVersion(String serverVersion, int serverBuild, String currentVersion, int currentBuild) {
    // Compare version strings (1.5.0 vs 1.5.1)
    final serverParts = serverVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      if (serverParts[i] > currentParts[i]) return true;
      if (serverParts[i] < currentParts[i]) return false;
    }
    
    // If version is same, compare build numbers
    return serverBuild > currentBuild;
  }
  
  Future<void> _showUpdateDialog(String version, String uploadDate) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Available!'),
          content: Text('New version $version is available.\nUploaded: ${uploadDate.split('T')[0]}\n\nWould you like to download and install it now?'),
          actions: [
            TextButton(
              child: Text('Later'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Update Now'),
              onPressed: () {
                Navigator.of(context).pop();
                _showUpdateConsole();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showUpdateConsole() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateConsoleScreen(),
      ),
    );
  }

  Future<void> _checkNotificationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user has already made a decision
      final notificationsEnabled = prefs.getBool('notifications_enabled');
      final dontShowAgain = prefs.getBool('notifications_dont_show_again') ?? false;
      
      // If user already pressed Enable or Don't Show Again, never show popup
      if (dontShowAgain || notificationsEnabled == true) {
        return;
      }
      
      // Show popup only if user hasn't seen it before or chose "remind me later"
      _showNotificationPermissionDialog();
      
    } catch (e) {
      print('Error checking notification permission: $e');
    }
  }

  Future<void> _showNotificationPermissionDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications, color: Colors.blue),
              SizedBox(width: 8),
              Text('Enable Notifications'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Get notified about your grocery list items and pantry updates!'),
              SizedBox(height: 16),
              Text('• Frequent item reminders', style: TextStyle(fontSize: 14)),
              Text('• Priority item alerts', style: TextStyle(fontSize: 14)),
              Text('• Pantry expiration warnings', style: TextStyle(fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Remind Me Later'),
              onPressed: () async {
                Navigator.of(context).pop();
                // Don't save any preference - will show again next time
              },
            ),
            TextButton(
              child: Text('Don\'t Show Again'),
              onPressed: () async {
                Navigator.of(context).pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notifications_dont_show_again', true);
                await prefs.setBool('notifications_enabled', false);
              },
            ),
            ElevatedButton(
              child: Text('Enable'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _requestNotificationPermission();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // For Android, always mark as handled when user presses Enable
      // The openAppSettings() will redirect to system settings
      await prefs.setBool('notifications_enabled', true);
      await prefs.setBool('notifications_dont_show_again', true);
      
      // Always redirect to app settings for notification permission
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening settings to enable notifications...'),
          backgroundColor: Colors.blue,
        ),
      );
      
      // Open app settings directly
      await openAppSettings();
      
    } catch (e) {
      print('Error requesting notification permission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to open settings'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSettingsRedirectDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Open Settings'),
          content: Text('To enable notifications, please go to your device Settings > Apps > PantryBot > Permissions > Notifications.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog() async {
    // Get current app version dynamically
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuild = packageInfo.buildNumber;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.kitchen, color: Colors.blue),
              SizedBox(width: 10),
              Text('About PantryBot'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version: $currentVersion', 
                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Build: $currentBuild'),
              SizedBox(height: 16),
              Text('Smart Kitchen Assistant'),
              SizedBox(height: 8),
              Text('Manage your pantry, grocery lists, and recipes with ease!'),
              SizedBox(height: 16),
              Text('App developed by Saif Alafeefi.',
                   style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Check for Updates'),
              onPressed: () {
                Navigator.of(context).pop();
                _manualUpdateCheck();
              },
            ),
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PantryBot'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
            tooltip: 'About',
          ),
          IconButton(
            icon: Icon(Icons.system_update),
            onPressed: _manualUpdateCheck,
            tooltip: 'Check for Updates',
          ),
          if (widget.isAdmin)
            IconButton(
              icon: Icon(Icons.admin_panel_settings),
              onPressed: () {
                                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.kitchen,
                size: 100,
                color: Colors.blue,
              ),
              SizedBox(height: 20),
              Text(
                'Welcome to PantryBot',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.blue.shade300 
                      : Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Hello, ${widget.username}!',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.shade300 
                      : Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 40),
              
              // Grocery List Button
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantryList(
                          isAdmin: widget.isAdmin,
                          userId: widget.userId,
                          username: widget.username,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart, size: 32),
                      SizedBox(width: 15),
                      Text(
                        'Grocery List',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Pantry Items Button
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantryItemsScreen(
                          userId: widget.userId,
                          isAdmin: widget.isAdmin,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory, size: 32),
                      SizedBox(width: 15),
                      Text(
                        'Pantry Items',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Recipes Button
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipesScreen(
                          userId: widget.userId,
                          isAdmin: widget.isAdmin,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 32),
                      SizedBox(width: 15),
                      Text(
                        'Recipes',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Priority Manager Button
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UrgencyScreen(
                          userId: widget.userId,
                          username: widget.username,
                          isAdmin: widget.isAdmin,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.priority_high, size: 32),
                      SizedBox(width: 15),
                      Text(
                        'Priority Manager',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Settings Button
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, size: 32),
                      SizedBox(width: 15),
                      Text(
                        'Settings',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PantryList extends StatefulWidget {
  final bool isAdmin;
  final int userId;
  final String username;
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  const PantryList({
    Key? key,
    required this.isAdmin,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  _PantryListState createState() => _PantryListState();
}

enum ItemCategory {
  Vegetables,
  Fruits,
  Dairy,
  Meats,
  Grains,
  Sweets,
  Oils,
  Electronics,
  Drinks,
  Medicine,
  Cleaning,
  Other,
}

enum FilterOption { all, checked, unchecked, category }

final categoryColors = {
  ItemCategory.Vegetables: Color(0xFFE8F5E9),  // Light green
  ItemCategory.Fruits: Color(0xFFC8E6C9),      // Slightly darker green
  ItemCategory.Dairy: Color(0xFFE3F2FD),       // Light blue
  ItemCategory.Meats: Color(0xFFFFEBEE),       // Light red
  ItemCategory.Grains: Color(0xFFEFEBE9),      // Light brown
  ItemCategory.Sweets: Color(0xFFFCE4EC),      // Pink
  ItemCategory.Oils: Color(0xFFFFFDE7),        // Light yellow
};

class _PantryListState extends State<PantryList> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _originalItems = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  SortOption _currentSort = SortOption.newest;

  // Getter for items to replace direct access
  List<Map<String, dynamic>> get items => _items;
  // Setter for items
  set items(List<Map<String, dynamic>> value) {
    setState(() {
      _items = value;
    });
  }

  // Make sure this URL uses http://
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  // Add this HTTP client that bypasses certificate verification with optimizations
  final client = HttpClient()
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true)
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 15);

  Timer? _refreshTimer;

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    fetchItems();
    
    // Set up timer to refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      fetchItems();
    });
  }

  // Add dispose method to clean up the timer
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchItems() async {
    setState(() => _isLoading = true);
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true)
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);
    final http = IOClient(ioc);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/grocery/items?user_id=${widget.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final items = jsonDecode(response.body);
        setState(() {
          _items = List<Map<String, dynamic>>.from(items);
          _isLoading = false;
        });
        _sortItems();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> addItem(String name, int quantity, String category, [String? metric, String? amountPerItem]) async {
    
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final requestData = {
        'name': name,
        'quantity': quantity,
        'category': category,
        'user_id': widget.userId,
        'metric': metric,
        'amount_per_item': amountPerItem,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/grocery/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _items.insert(0, Map<String, dynamic>.from(data['item']));
          });
          _controller.clear();
          _sortItems();
        }
      }
    } catch (e) {
      print('Error adding item: $e');
    }
  }

  Future<void> toggleItem(int id, bool checked) async {
    HapticFeedback.selectionClick();
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);
    try {
      final item = items.firstWhere((item) => item['id'] == id);
      final response = await http.put(
        Uri.parse('$baseUrl/grocery/items/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'checked': checked ? 1 : 0,
          'name': item['name'],
          'quantity': item['quantity'],
          'category': item['category'],
          'user_id': widget.userId,
          'metric': item['metric'],
          'amount_per_item': item['amount_per_item'],
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          item['checked'] = checked ? 1 : 0;
        });
        fetchItems();
        // Pantry sync logic
        if (checked) {
          // Add to pantry
          await _addToPantryFromGrocery(item);
        } else {
          // Remove from pantry
          await _removeFromPantryByName(item['name']);
        }
      }
    } catch (e) {
      print('Error toggling item: $e');
    }
  }

  Future<void> _addToPantryFromGrocery(Map<String, dynamic> groceryItem) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);
    try {
      final pantryItem = {
        'name': groceryItem['name'],
        'type': groceryItem['category'],
        'quantity': groceryItem['quantity'],
        'expiry_date': '', // Will be set by user later
        'user_id': widget.userId,
        'metric': groceryItem['metric'],
        'amount_per_item': groceryItem['amount_per_item'],
      };
      await http.post(
        Uri.parse('$baseUrl/pantry/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(pantryItem),
      );
    } catch (e) {
      print('Error adding to pantry: $e');
    }
  }

  Future<void> _removeFromPantryByName(String name) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);
    try {
      // Fetch all pantry items for this user
      final response = await http.get(Uri.parse('$baseUrl/pantry/items?user_id=${widget.userId}'));
      if (response.statusCode == 200) {
        final pantryItems = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        for (final item in pantryItems) {
          if (item['name'] == name) {
            await http.delete(Uri.parse('$baseUrl/pantry/items/${item['id']}'));
          }
        }
      }
    } catch (e) {
      print('Error removing from pantry: $e');
    }
  }

  Future<void> deleteItem(int id) async {
    
    final ioClient = IOClient(client);
    await ioClient.delete(Uri.parse('$baseUrl/grocery/items/$id'));
    fetchItems();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      // Filtering is now handled in _getFilteredItems(), so just trigger rebuild
    });
  }

  void _showAddItemDialog(String itemName, {String? defaultCategory}) {
    HapticFeedback.mediumImpact();
    String selectedCategory = defaultCategory ?? 'Vegetables';
    int quantity = 1;
    String? selectedMetric;
    String? amountPerItem;

    // Helper to fetch metric suggestion
    Future<void> fetchMetricSuggestion(String name, String category) async {
      if (name.isEmpty) return;
      try {
        final ioc = HttpClient()
          ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
        final http = IOClient(ioc);
        final response = await http.get(Uri.parse('$baseUrl/grocery/suggestions?query=${Uri.encodeComponent(name)}&user_id=${widget.userId}'));
        if (response.statusCode == 200) {
          final suggestions = jsonDecode(response.body);
          if (suggestions is List && suggestions.isNotEmpty) {
            final match = suggestions.firstWhere(
              (s) => s['name'].toString().toLowerCase() == name.toLowerCase() && s['category'] == category,
              orElse: () => null,
            );
            if (match != null && match['metric'] != null) {
              selectedMetric = match['metric'];
            }
          }
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Item: $itemName'),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Quantity: '),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) setState(() => quantity--);
                        },
                      ),
                      Text('$quantity'),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Amount per item',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    onChanged: (val) => amountPerItem = val,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categoryMetrics.keys
                        .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedCategory = newValue;
                          selectedMetric = null;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedMetric,
                    decoration: InputDecoration(
                      labelText: 'Metric',
                      border: OutlineInputBorder(),
                    ),
                    items: (categoryMetrics[selectedCategory] ?? ['Piece'])
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMetric = value;
                      });
                    },
                    isExpanded: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Add'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    addItem(itemName, quantity, selectedCategory, selectedMetric, amountPerItem);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sortItems() {
    setState(() {
      switch (_currentSort) {
        case SortOption.unchecked:
          _items.sort((a, b) => (a['checked'] as int).compareTo(b['checked'] as int));
          break;
        case SortOption.aToZ:
          _items.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          break;
        case SortOption.zToA:
          _items.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
          break;
        case SortOption.newest:
          _items.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
          break;
        case SortOption.oldest:
          _items.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
          break;
        case SortOption.nameAZ:
          _items.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          break;
        case SortOption.nameZA:
          _items.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
          break;
        case SortOption.categoryAZ:
          _items.sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));
          break;
        case SortOption.categoryZA:
          _items.sort((a, b) => (b['category'] as String).compareTo(a['category'] as String));
          break;
        case SortOption.category:
          _showCategoryFilterDialog();
          break;
      }
    });
  }

  void _showEditDialog(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    
    String name = item['name'];
    int quantity = item['quantity'];
    String category = item['category'];
    String? metric = item['metric'];
    String? amountPerItem = item['amount_per_item'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(labelText: 'Name'),
                    controller: TextEditingController(text: name),
                    onChanged: (value) => name = value,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Quantity: '),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) setState(() => quantity--);
                        },
                      ),
                      Text('$quantity'),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Amount per item',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: amountPerItem ?? ''),
                    keyboardType: TextInputType.text,
                    onChanged: (val) => amountPerItem = val,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categoryMetrics.keys
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() {
                        category = value;
                        metric = null;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: metric,
                    decoration: InputDecoration(
                      labelText: 'Metric',
                      border: OutlineInputBorder(),
                    ),
                    items: (categoryMetrics[category] ?? ['Piece'])
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        metric = value;
                      });
                    },
                    isExpanded: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Save'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    updateItem(item['id'], name, quantity, category, metric, amountPerItem);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> updateItem(int id, String name, int quantity, String category, [String? metric, String? amountPerItem]) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/grocery/items/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'quantity': quantity,
          'category': category,
          'checked': items.firstWhere((item) => item['id'] == id)['checked'],
          'metric': metric,
          'amount_per_item': amountPerItem,
        }),
      );
      if (response.statusCode == 200) {
        fetchItems();
      }
    } catch (e) {
      print('Error updating item: $e');
    }
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('All Categories'),
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                      _currentSort = SortOption.newest;  // Reset to default sort
                    });
                    Navigator.of(context).pop();
                  },
                ),
                Divider(),
                ...[
                  'Vegetables', 'Fruits', 'Dairy', 'Meats', 
                  'Grains', 'Sweets', 'Oils', 'Electronics', 
                  'Drinks', 'Medicine', 'Cleaning', 'Other'
                ].map((category) => ListTile(
                  title: Text(category),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _currentSort = SortOption.newest;  // Reset to default sort
                    });
                    Navigator.of(context).pop();
                  },
                )).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    var allItems = items.map((item) => item as Map<String, dynamic>).toList();
    
    // Apply search filter first
    if (_searchController.text.isNotEmpty) {
      allItems = allItems.where((item) => 
        item['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase())
      ).toList();
    }
    
    // If a category is selected, split and reorder the items
    if (_selectedCategory != null) {
      var categoryItems = allItems.where((item) => 
        item['category'] == _selectedCategory).toList();
      var otherItems = allItems.where((item) => 
        item['category'] != _selectedCategory).toList();
      
      // Sort each group separately
      _applySorting(categoryItems);
      _applySorting(otherItems);
      
      // Combine with selected category items at the top
      return [...categoryItems, ...otherItems];
    }
    
    // If no category selected, just sort all items
    _applySorting(allItems);
    return allItems;
  }

  void _applySorting(List<Map<String, dynamic>> items) {
    switch (_currentSort) {
      case SortOption.unchecked:
        items.sort((a, b) => (a['checked'] as int).compareTo(b['checked'] as int));
        break;
      case SortOption.aToZ:
        items.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
      case SortOption.zToA:
        items.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
        break;
      case SortOption.newest:
        items.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
        break;
      case SortOption.oldest:
        items.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
        break;
      case SortOption.nameAZ:
        items.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
      case SortOption.nameZA:
        items.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
        break;
      case SortOption.categoryAZ:
        items.sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));
        break;
      case SortOption.categoryZA:
        items.sort((a, b) => (b['category'] as String).compareTo(a['category'] as String));
        break;
      case SortOption.category:
        items.sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));
        break;
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/grocery/suggestions?query=${Uri.encodeComponent(query)}&user_id=${widget.userId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  Widget _buildAddItemField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Add new item',
                  ),
                  onChanged: (value) {
                    // Debounce the API calls
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                      _fetchSuggestions(value);
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    HapticFeedback.mediumImpact();
                    _showAddItemDialog(_controller.text);
                  }
                },
              ),
            ],
          ),
          // Show suggestions below the input field
          if (_suggestions.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _suggestions.map((suggestion) => ListTile(
                  title: Text(suggestion['name']),
                  subtitle: Text(suggestion['category']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Used ${suggestion['use_count']} times'),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _showDeleteSuggestionConfirmation(suggestion),
                        tooltip: 'Delete suggestion',
                      ),
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _controller.text = suggestion['name'];
                    _showAddItemDialog(
                      suggestion['name'],
                      defaultCategory: suggestion['category'],
                    );
                    setState(() => _suggestions = []);
                  },
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showUrgencyDialog(Map<String, dynamic> item) {
    int currentUrgency = item['urgency_level'] as int? ?? 3;
    bool notificationEnabled = item['notification_enabled'] != 0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Adjust Priority: ${item['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current Priority: Level $currentUrgency'),
                  SizedBox(height: 20),
                  Text('Priority Level'),
                  Slider(
                    value: currentUrgency.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: switch(currentUrgency) {
                      1 => 'Low',
                      2 => 'Medium',
                      3 => 'High',
                      4 => 'Critical',
                      5 => 'Emergency',
                      _ => 'Unknown',
                    },
                    onChanged: (value) {
                      setState(() {
                        currentUrgency = value.round();
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        switch(currentUrgency) {
                          5 => Icons.warning,
                          4 => Icons.priority_high,
                          3 => Icons.local_fire_department,
                          2 => Icons.list_alt,
                          1 => Icons.note,
                          _ => Icons.help,
                        },
                        color: switch(currentUrgency) {
                          5 => Colors.red[900],
                          4 => Colors.red[700],
                          3 => Colors.orange[700],
                          2 => Colors.blue[600],
                          1 => Colors.grey[600],
                          _ => Colors.grey[600],
                        },
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          switch(currentUrgency) {
                            5 => 'Emergency - Overdue, critical need',
                            4 => 'Critical - Overdue, high importance',
                            3 => 'High - Due for purchase',
                            2 => 'Medium - Approaching purchase time',
                            1 => 'Low - Recently purchased',
                            _ => 'Unknown priority level',
                          },
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  CheckboxListTile(
                    title: Text('Enable notifications'),
                    subtitle: Text('Get reminders for this item'),
                    value: notificationEnabled,
                    onChanged: (value) {
                      setState(() {
                        notificationEnabled = value ?? true;
                      });
                    },
                    dense: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateItemUrgency(item, currentUrgency, notificationEnabled);
                    Navigator.pop(context);
                  },
                  child: Text('Update Priority'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateItemUrgency(Map<String, dynamic> item, int urgencyLevel, bool notificationEnabled) async {
    try {
      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      final response = await ioClient.put(
        Uri.parse('$baseUrl/urgency/items/${item['name']}/${item['category']}/${item['user_id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'urgency_level': urgencyLevel,
          'notification_enabled': notificationEnabled,
        }),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Priority updated for ${item['name']}'),
            backgroundColor: Colors.green,
          ),
        );
        fetchItems(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update priority'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error updating priority: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Item'),
          content: Text('Are you sure you want to delete "${item['name']}"?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      deleteItem(item['id']);
    }
  }

  Future<void> _showDeleteSuggestionConfirmation(Map<String, dynamic> suggestion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Suggestion'),
          content: Text('Are you sure you want to delete "${suggestion['name']}" (${suggestion['category']}) from your suggestion history?\n\nThis will remove it from autocomplete suggestions.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      await _deleteSuggestion(suggestion);
    }
  }

  Future<void> _deleteSuggestion(Map<String, dynamic> suggestion) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/grocery/suggestions/${Uri.encodeComponent(suggestion['name'])}/${Uri.encodeComponent(suggestion['category'])}/${widget.userId}'),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suggestion deleted successfully')),
        );
        // Refresh suggestions for current query
        if (_controller.text.isNotEmpty) {
          _fetchSuggestions(_controller.text);
        } else {
          setState(() => _suggestions = []);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete suggestion')),
        );
      }
    } catch (e) {
      print('Error deleting suggestion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting suggestion')),
      );
    }
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.notifications, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Notification Settings'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Get notified about important grocery items and reminders!'),
                  SizedBox(height: 20),
                  FutureBuilder<bool>(
                    future: NotificationService.areNotificationsEnabled(),
                    builder: (context, snapshot) {
                      final isEnabled = snapshot.data ?? false;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isEnabled ? Icons.check_circle : Icons.error,
                                color: isEnabled ? Colors.green : Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                isEnabled ? 'Notifications Enabled' : 'Notifications Disabled',
                                style: TextStyle(
                                  color: isEnabled ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await NotificationService.showTestNotification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Test notification sent!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Failed to send notification: Enable notifications in Settings first'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Send Test Notification'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      // Send sample grocery reminder
                      try {
                        await NotificationService.showGroceryReminder('Milk', 'High');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Sample grocery reminder sent!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Failed to send reminder: Enable notifications in Settings first'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Test Grocery Reminder'),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text('Open System Settings'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGestureHelp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.touch_app, color: Colors.blue),
              SizedBox(width: 8),
              Text('Quick Actions Guide'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGestureHelpItem(
                  Icons.swipe_right,
                  'Swipe Right',
                  'Check/uncheck items instantly',
                  Colors.green,
                ),
                SizedBox(height: 12),
                _buildGestureHelpItem(
                  Icons.swipe_left,
                  'Swipe Left',
                  'Delete items (with confirmation)',
                  Colors.red,
                ),
                SizedBox(height: 12),
                _buildGestureHelpItem(
                  Icons.touch_app,
                  'Long Press',
                  'Quick edit item details',
                  Colors.orange,
                ),
                SizedBox(height: 12),
                _buildGestureHelpItem(
                  Icons.touch_app,
                  'Double Tap',
                  'Toggle check/uncheck',
                  Colors.blue,
                ),
                SizedBox(height: 12),
                _buildGestureHelpItem(
                  Icons.refresh,
                  'Pull Down',
                  'Refresh the list',
                  Colors.purple,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Got it!'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGestureHelpItem(IconData icon, String gesture, String description, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gesture,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updatePantryExpiry(int id, DateTime expiry) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);
    try {
      await http.put(
        Uri.parse('$baseUrl/pantry/items/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'expiry_date': '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}',}),
      );
      fetchItems();
    } catch (e) {
      print('Error updating pantry expiry: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.white),
            SizedBox(width: 8),
            Text('Grocery List', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showGestureHelp,
            tooltip: 'Quick Actions Guide',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showNotificationSettings,
            tooltip: 'Notification Settings',
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.filter_list),
            onSelected: (SortOption result) {
              setState(() {
                if (result == SortOption.category) {
                  _showCategoryFilterDialog();
                } else {
                  _currentSort = result;
                  _sortItems();
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.unchecked,
                child: Text('Unchecked'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.aToZ,
                child: Text('A to Z'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.zToA,
                child: Text('Z to A'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.oldest,
                child: Text('Oldest'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.newest,
                child: Text('Newest'),
              ),
              const PopupMenuDivider(),  // Add a divider
              const PopupMenuItem<SortOption>(
                value: SortOption.category,
                child: Text('Filter by Category'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => fetchItems(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAddItemField(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search items',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      // Just trigger a rebuild - filtering is now handled in _getFilteredItems()
                    });
                  },
                ),
                AnimatedOpacity(
                  opacity: _searchController.text.isEmpty ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(
                      _searchController.text.isEmpty ? 20.0 : 0.0, 
                      0.0, 
                      0.0
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _searchController.text.isEmpty ? null : _clearSearch,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchItems,
              child: ListView.builder(
                itemCount: _getFilteredItems().length,
                itemBuilder: (context, index) {
                  final item = _getFilteredItems()[index];
                  final category = item['category'] as String? ?? 'Vegetables';
                  final urgencyLevel = item['urgency_level'] as int? ?? 3;
                  final frequency = item['frequency'] as int? ?? 0;
                  final isManualOverride = item['is_manual_override'] == 1;
                  
                  // Category-based color coding (back to original system)
                  final Color itemColor = switch(category.toLowerCase().trim()) {
                    'vegetables' => Color(0xFFBEDFBF),  // More opaque green
                    'fruits' => Color(0xFFA8D5AA),      // More opaque darker green
                    'dairy' => Color(0xFFB3D4FC),       // More opaque blue
                    'meats' => Color(0xFFFFCCCC),       // More opaque red
                    'grains' => Color(0xFFDBC8B8),      // More opaque brown
                    'sweets' => Color(0xFFFFC4D6),      // More opaque pink
                    'oils' => Color(0xFFFFE5A5),        // More opaque yellow
                    'electronics' => Color(0xFFB3E5FC),  // More opaque cyan
                    'drinks' => Color(0xFFB2DFDB),      // More opaque teal
                    'medicine' => Color(0xFFE1BEE7),    // More opaque purple
                    'cleaning' => Color(0xFFE0E0E0),    // More opaque gray
                    'other' => Color(0xFFEEEEEE),       // More opaque light gray
                    _ => Colors.white,
                  };
                  
                  // Priority icons based on urgency (keep the icons)
                  final IconData? priorityIcon = switch(urgencyLevel) {
                    5 => Icons.warning,          // Emergency 🚨
                    4 => Icons.priority_high,    // Critical ⚠️
                    3 => Icons.local_fire_department, // High 🔥
                    2 => Icons.list_alt,         // Medium 📋
                    1 => Icons.note,             // Low 📝
                    _ => null,
                  };
                  
                  final Color priorityIconColor = switch(urgencyLevel) {
                    5 => Colors.red[900]!,       // Emergency - Dark red
                    4 => Colors.red[700]!,       // Critical - Red
                    3 => Colors.orange[700]!,    // High - Orange
                    2 => Colors.blue[600]!,      // Medium - Blue
                    1 => Colors.grey[600]!,      // Low - Gray
                    _ => Colors.grey[600]!,
                  };

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Dismissible(
                      key: Key('item_${item['id']}'),
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.only(left: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item['checked'] == 1 ? Icons.remove_done : Icons.check,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 8),
                            Text(
                              item['checked'] == 1 ? 'Uncheck' : 'Check Off',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // Confirm delete
                          return await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Delete Item'),
                                content: Text('Are you sure you want to delete "${item['name']}"?'),
                                actions: [
                                  TextButton(
                                    child: Text('Cancel'),
                                    onPressed: () => Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: Text('Delete'),
                                    onPressed: () => Navigator.of(context).pop(true),
                                  ),
                                ],
                              );
                            },
                          ) ?? false;
                        }
                        return true; // Allow swipe for check/uncheck
                      },
                      onDismissed: (direction) {
                        if (direction == DismissDirection.startToEnd) {
                          // Toggle check/uncheck
                          HapticFeedback.mediumImpact();
                          toggleItem(item['id'], item['checked'] != 1);
                          
                          // Show feedback snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                item['checked'] == 1 
                                  ? '${item['name']} unchecked' 
                                  : '${item['name']} checked off'
                              ),
                              duration: Duration(seconds: 1),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  toggleItem(item['id'], item['checked'] == 1);
                                },
                              ),
                            ),
                          );
                        } else {
                          // Delete item
                          HapticFeedback.heavyImpact();
                          deleteItem(item['id']);
                          
                          // Show delete confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item['name']} deleted'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        }
                      },
                      child: GestureDetector(
                        onLongPress: () {
                          HapticFeedback.lightImpact();
                          _showEditDialog(item);
                        },
                        onDoubleTap: () {
                          HapticFeedback.selectionClick();
                          // Quick toggle on double tap
                          toggleItem(item['id'], item['checked'] != 1);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (priorityIcon != null) ...[
                                  Icon(
                                    priorityIcon,
                                    color: priorityIconColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: 4),
                                ],
                                Checkbox(
                                  value: item['checked'] == 1,
                                  onChanged: (bool? value) {
                                    HapticFeedback.selectionClick();
                                    toggleItem(item['id'], value ?? false);
                                  },
                                ),
                              ],
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['name']} (${item['quantity']} × ${item['amount_per_item'] ?? ''} ${item['metric'] ?? ''}) (${item['category']})',
                                  style: TextStyle(
                                    decoration: item['checked'] == 1 ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (frequency > 0) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    'Purchased ${frequency} times${isManualOverride ? ' • Manual priority' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.trending_up, 
                                    color: priorityIconColor,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showUrgencyDialog(item);
                                  },
                                  tooltip: 'Adjust Priority',
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showEditDialog(item);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    HapticFeedback.heavyImpact();
                                    _showDeleteConfirmation(item);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroceryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(bool?) onCheckboxChanged;
  final Function() onEdit;

  const GroceryItem({
    Key? key,
    required this.item,
    required this.onCheckboxChanged,
    required this.onEdit,
  }) : super(key: key);

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables': return Color(0xFFE8F5E9);
      case 'fruits': return Color(0xFFC8E6C9);
      case 'dairy': return Color(0xFFE3F2FD);
      case 'meats': return Color(0xFFFFEBEE);
      case 'grains': return Color(0xFFEFEBE9);
      case 'sweets': return Color(0xFFFCE4EC);
      case 'oils': return Color(0xFFFFFDE7);
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getCategoryColor(item['category']),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: item['checked'] == 1,
          onChanged: onCheckboxChanged,
        ),
        title: Text(
          '${item['name']} (${item['quantity']} × ${item['amount_per_item'] ?? ''} ${item['metric'] ?? ''}) (${item['category']})',
          style: TextStyle(
            decoration: item['checked'] == 1 ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
    );
  }
}

class UpdateConsoleScreen extends StatefulWidget {
  @override
  _UpdateConsoleScreenState createState() => _UpdateConsoleScreenState();
}

class _UpdateConsoleScreenState extends State<UpdateConsoleScreen> {
  List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _addLog('🚀 Update console ready');
    _startUpdate();
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startUpdate() async {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      _addLog('📡 Downloading APK from Pi server...');
      
      // Use our SSL-bypassing HTTP client to download APK
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      final response = await ioClient.get(
        Uri.parse('https://pantrybot.anonstorage.org:8443/api/apk/latest'),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        _addLog('✅ APK downloaded (${response.bodyBytes.length} bytes)');
        
        // Save to Downloads folder where user can access it
        final downloadsDir = Directory('/storage/emulated/0/Download');
        final apkFile = File('${downloadsDir.path}/pantrybot_update.apk');
        
        try {
          await apkFile.writeAsBytes(response.bodyBytes);
          _addLog('💾 Saved APK to Downloads folder');
          
          // Trigger Android install intent automatically
          _addLog('🚀 Triggering install prompt...');
          
          try {
            // Use method channel to call Android install intent
            const platform = MethodChannel('com.example.pantrybot/installer');
            await platform.invokeMethod('installApk', {'apkPath': apkFile.path});
            _addLog('✅ Android install prompt should appear now!');
          } catch (e) {
            _addLog('⚠️ Install intent failed, trying alternative...');
            
            // Fallback: Try to open the file directly with the system
            final result = await Process.run('am', [
              'start',
              '-t', 'application/vnd.android.package-archive',
              '-d', 'file://${apkFile.path}'
            ]);
            
            if (result.exitCode == 0) {
              _addLog('✅ Install triggered via system intent!');
            } else {
              _addLog('❌ Could not trigger install automatically');
              _addLog('📱 Please go to Downloads and tap pantrybot_update.apk');
            }
          }
          
        } catch (e) {
          _addLog('⚠️ Could not save to Downloads folder: ${e.toString()}');
          _addLog('📋 Falling back to manual instructions!');
        }
        
        _addLog('🎉 Update ready for installation!');
        
      } else {
        _addLog('❌ Failed to download APK (HTTP ${response.statusCode})');
      }
      
    } catch (e) {
      _addLog('💥 Error: ${e.toString()}');
    } finally {
      _isUpdating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Console'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.green,
              width: double.infinity,
              child: Text(
                'Live Update Console',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: TextStyle(
                        color: Colors.green,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final allLogs = _logs.join('\n');
                        Clipboard.setData(ClipboardData(text: allLogs));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Logs copied to clipboard!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Text('Copy Logs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

