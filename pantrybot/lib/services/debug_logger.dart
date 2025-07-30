import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class DebugLogger extends ChangeNotifier {
  static final DebugLogger _instance = DebugLogger._internal();
  static DebugLogger get instance => _instance;

  DebugLogger._internal() {
    _setupLogger();
  }

  final List<String> _logs = [];
  late Logger _logger;
  final int _maxLogs = 1000; // Limit logs to prevent memory issues

  List<String> get logs => List.unmodifiable(_logs);

  void _setupLogger() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 50,
        colors: false,
        printEmojis: false,
        printTime: true,
      ),
      output: _CustomLogOutput(this),
    );

    // Override print function to capture all print statements
    if (kDebugMode) {
      developer.log('🔧 Debug Logger initialized - capturing all logs');
    }
  }

  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    
    _logs.add(logEntry);
    
    // Limit log count to prevent memory issues
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    // Notify listeners (the UI)
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    addLog('🧹 Logs cleared');
  }

  // Custom logging methods
  void info(String message) {
    addLog('💡 INFO: $message');
    _logger.i(message);
  }

  void error(String message) {
    addLog('❗️ ERROR: $message');
    _logger.e(message);
  }

  void debug(String message) {
    addLog('🔧 DEBUG: $message');
    _logger.d(message);
  }

  void updraft(String message) {
    addLog('🚀 UPDRAFT: $message');
  }
}

// Custom log output to capture logger messages
class _CustomLogOutput extends LogOutput {
  final DebugLogger debugLogger;
  
  _CustomLogOutput(this.debugLogger);

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // Don't add duplicate entries for our own logs
      if (!line.contains('Debug Logger initialized')) {
        debugLogger.addLog(line);
      }
    }
  }
}

// Initialize debug logger (print override removed due to Dart limitations)
void setupGlobalPrintCapture() {
  if (kDebugMode) {
    // Just initialize the logger - manual logging via DebugLogger.instance methods
    DebugLogger.instance.addLog('🔧 Debug Logger ready - use DebugLogger.instance.info() for logging');
  }
} 