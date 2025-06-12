class ApiConfig {
  // Use HTTP domain for universal access (port 8080 works)
  static const String apiUrl = 'http://pantrybot.anonstorage.org:8080';
  
  // Longer timeout for proxied requests
  static const Duration timeout = Duration(seconds: 45);
  
  /// Get the API base URL
  static String get baseUrl => apiUrl;
} 