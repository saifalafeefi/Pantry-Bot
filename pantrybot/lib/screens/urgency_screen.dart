import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

class UrgencyScreen extends StatefulWidget {
  final int userId;
  final String username;
  final bool isAdmin;

  const UrgencyScreen({
    Key? key,
    required this.userId,
    required this.username,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _UrgencyScreenState createState() => _UrgencyScreenState();
}

class _UrgencyScreenState extends State<UrgencyScreen> with TickerProviderStateMixin {
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';
  List<Map<String, dynamic>> _urgencyItems = [];
  List<Map<String, dynamic>> _filteredUrgencyItems = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterItems);
    _fetchUrgencyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUrgencyData() async {
    setState(() => _isLoading = true);
    
    try {
      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      // Fetch urgency items
      final itemsResponse = await ioClient.get(
        Uri.parse('$baseUrl/urgency/items?user_id=${widget.userId}'),
      ).timeout(Duration(seconds: 10));
      
      print('Urgency items response status: ${itemsResponse.statusCode}');
      print('Urgency items response body: ${itemsResponse.body}');
      
      // Fetch analytics
      final analyticsResponse = await ioClient.get(
        Uri.parse('$baseUrl/urgency/analytics/${widget.userId}'),
      ).timeout(Duration(seconds: 10));
      
      print('Analytics response status: ${analyticsResponse.statusCode}');
      print('Analytics response body: ${analyticsResponse.body}');
      
      if (itemsResponse.statusCode == 200 && analyticsResponse.statusCode == 200) {
        try {
          setState(() {
            _urgencyItems = List<Map<String, dynamic>>.from(json.decode(itemsResponse.body));
            _filteredUrgencyItems = List<Map<String, dynamic>>.from(_urgencyItems);
            _analytics = json.decode(analyticsResponse.body);
          });
        } catch (e) {
          print('JSON parsing error: $e');
          throw Exception('Failed to parse response data: $e');
        }
      } else {
        throw Exception('Failed to load urgency data. Items status: ${itemsResponse.statusCode}, Analytics status: ${analyticsResponse.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error loading urgency data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUrgency(String itemName, String category, int urgencyLevel, bool notificationEnabled) async {
    try {
      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      final response = await ioClient.put(
        Uri.parse('$baseUrl/urgency/items/$itemName/$category/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'urgency_level': urgencyLevel,
          'notification_enabled': notificationEnabled,
        }),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Priority updated for $itemName'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUrgencyData(); // Refresh
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
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredUrgencyItems = List<Map<String, dynamic>>.from(_urgencyItems);
      } else {
        _filteredUrgencyItems = _urgencyItems.where((item) {
          final name = (item['name'] as String).toLowerCase();
          final category = (item['category'] as String).toLowerCase();
          final urgencyLabel = _getUrgencyLabel(item['urgency_level'] as int).toLowerCase();
          
          return name.contains(query) || 
                 category.contains(query) || 
                 urgencyLabel.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _recalculateAllUrgencies() async {
    try {
      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      final response = await ioClient.post(
        Uri.parse('$baseUrl/urgency/calculate/${widget.userId}'),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result['message']}'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUrgencyData(); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to recalculate urgencies'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getUrgencyColor(int urgencyLevel) {
    switch (urgencyLevel) {
      case 1:
        return Colors.grey[100]!;
      case 2:
        return Colors.blue[100]!;
      case 3:
        return Colors.orange[100]!;
      case 4:
        return Colors.red[100]!;
      case 5:
        return Colors.red[800]!;
      default:
        return Colors.grey[100]!;
    }
  }

  IconData _getUrgencyIcon(int urgencyLevel) {
    switch (urgencyLevel) {
      case 5:
        return Icons.warning;
      case 4:
        return Icons.priority_high;
      case 3:
        return Icons.local_fire_department;
      case 2:
        return Icons.list_alt;
      case 1:
        return Icons.note;
      default:
        return Icons.help;
    }
  }

  String _getUrgencyLabel(int urgencyLevel) {
    switch (urgencyLevel) {
      case 5:
        return 'Emergency';
      case 4:
        return 'Critical';
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
        return 'Low';
      default:
        return 'Unknown';
    }
  }

  Widget _buildUrgencyItemsList() {
    if (_urgencyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No tracked items yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Add items to your grocery list to start tracking priorities'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Container(
          padding: EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, category, or priority...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
        // Results count
        if (_searchController.text.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Found ${_filteredUrgencyItems.length} items',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ),
        // Items List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchUrgencyData,
            child: _filteredUrgencyItems.isEmpty && _searchController.text.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No items found matching "${_searchController.text}"',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUrgencyItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredUrgencyItems[index];
          final urgencyLevel = item['urgency_level'] as int;
          final isManualOverride = item['is_manual_override'] as bool;
          final frequency = item['frequency'] as int;
          final daysSince = item['days_since_last'] as int;
          final avgInterval = item['average_interval'] as double;

          return Container(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: _getUrgencyColor(urgencyLevel),
              borderRadius: BorderRadius.circular(8),
              border: isManualOverride ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getUrgencyIcon(urgencyLevel),
                    color: urgencyLevel == 5 ? Colors.white : null,
                    size: 24,
                  ),
                  if (isManualOverride) ...[
                    SizedBox(width: 4),
                    Icon(Icons.edit, color: Colors.blue, size: 16),
                  ],
                ],
              ),
              title: Text(
                item['name'],
                style: TextStyle(
                  fontWeight: urgencyLevel >= 4 ? FontWeight.bold : FontWeight.normal,
                  color: urgencyLevel == 5 ? Colors.white : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['category']} • ${_getUrgencyLabel(urgencyLevel)} Priority',
                    style: TextStyle(
                      color: urgencyLevel == 5 ? Colors.white70 : null,
                    ),
                  ),
                  if (frequency > 0)
                    Text(
                      'Purchased $frequency times • ${daysSince}d since last • Avg: ${avgInterval.toStringAsFixed(1)}d',
                      style: TextStyle(
                        fontSize: 12,
                        color: urgencyLevel == 5 ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showUrgencyEditDialog(item);
                  } else if (value == 'reset') {
                    _resetToAutoUrgency(item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit Priority'),
                      ],
                    ),
                  ),
                  if (isManualOverride)
                    PopupMenuItem(
                      value: 'reset',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Reset to Auto'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsDashboard() {
    if (_analytics.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    final urgencyDistribution = _analytics['urgency_distribution'] as List? ?? [];
    final topFrequentItems = _analytics['top_frequent_items'] as List? ?? [];
    final overdueItems = _analytics['overdue_items'] as List? ?? [];
    final categoryStats = _analytics['category_stats'] as List? ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgency Distribution Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Priority Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  ...urgencyDistribution.map((dist) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _getUrgencyIcon(dist['urgency'] as int),
                          color: _getUrgencyColor(dist['urgency'] as int) == Colors.red[800] 
                            ? Colors.red[800] 
                            : Colors.grey[700],
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('${_getUrgencyLabel(dist['urgency'] as int)} Priority'),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getUrgencyColor(dist['urgency'] as int),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${dist['count']} items'),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Most Frequent Items Card
          if (topFrequentItems.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Most Frequently Purchased', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    ...topFrequentItems.take(5).map((item) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(child: Text(item['name'])),
                          Text('${item['frequency']}x • ${item['category']}'),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
          
          // Overdue Items Card
          if (overdueItems.isNotEmpty) ...[
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Overdue Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 16),
                    ...overdueItems.take(10).map((item) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _getUrgencyIcon(item['urgency_level'] as int),
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(child: Text(item['name'])),
                          Text('${item['days_since_last_use']}d overdue'),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
          
          // Category Statistics Card
          if (categoryStats.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    ...categoryStats.map((cat) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(child: Text(cat['category'])),
                              Text('${cat['item_count']} items'),
                            ],
                          ),
                          Row(
                            children: [
                              SizedBox(width: 32),
                              Expanded(
                                child: Text(
                                  'Avg frequency: ${(cat['avg_frequency'] as double).toStringAsFixed(1)} • Avg interval: ${(cat['avg_interval'] as double).toStringAsFixed(1)}d',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUrgencyEditDialog(Map<String, dynamic> item) {
    int currentUrgency = item['urgency_level'] as int;
    bool notificationEnabled = item['notification_enabled'] as bool;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Priority: ${item['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Priority Level: ${_getUrgencyLabel(currentUrgency)}'),
                  SizedBox(height: 20),
                  Slider(
                    value: currentUrgency.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _getUrgencyLabel(currentUrgency),
                    onChanged: (value) {
                      setState(() {
                        currentUrgency = value.round();
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  CheckboxListTile(
                    title: Text('Enable notifications'),
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
                    Navigator.pop(context);
                    _updateUrgency(item['name'], item['category'], currentUrgency, notificationEnabled);
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _resetToAutoUrgency(Map<String, dynamic> item) {
    final autoUrgency = item['auto_calculated_urgency'] as int;
    _updateUrgency(item['name'], item['category'], autoUrgency, item['notification_enabled'] as bool);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Priority Manager'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.list), text: 'Items'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _recalculateAllUrgencies,
            tooltip: 'Recalculate All',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUrgencyItemsList(),
                _buildAnalyticsDashboard(),
              ],
            ),
    );
  }
}