import 'package:flutter/material.dart';
import '../services/debug_logger.dart';

class DebugLogsScreen extends StatefulWidget {
  @override
  _DebugLogsScreenState createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listen to new logs and auto-scroll
    DebugLogger.instance.addListener(_onNewLog);
  }

  @override
  void dispose() {
    DebugLogger.instance.removeListener(_onNewLog);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewLog() {
    setState(() {});
    // Auto-scroll to bottom when new log arrives
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

  @override
  Widget build(BuildContext context) {
    final logs = DebugLogger.instance.logs;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Console'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              DebugLogger.instance.clearLogs();
              setState(() {});
            },
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: logs.isEmpty
            ? Center(
                child: Text(
                  'No logs yet...\nStart using the app to see logs here!',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  Color textColor;
                  
                  // Color-code based on log content
                  if (log.contains('ERROR') || log.contains('❗️')) {
                    textColor = Colors.red;
                  } else if (log.contains('INFO') || log.contains('💡')) {
                    textColor = Colors.lightBlue;
                  } else if (log.contains('🚀')) {
                    textColor = Colors.green;
                  } else if (log.contains('UPDRAFT')) {
                    textColor = Colors.orange;
                  } else {
                    textColor = Colors.white;
                  }
                  
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      log,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontFamily: 'Courier',
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.grey[800],
        onPressed: () {
          // Scroll to bottom
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        },
        child: Icon(Icons.keyboard_arrow_down, color: Colors.white),
      ),
    );
  }
} 