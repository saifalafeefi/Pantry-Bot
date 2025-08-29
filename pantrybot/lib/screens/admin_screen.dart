import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _users = [];
  Map<int, List<Map<String, dynamic>>> _userGroceryItems = {};
  Map<int, List<Map<String, dynamic>>> _userPantryItems = {};
  Map<int, List<Map<String, dynamic>>> _userSuggestions = {};
  bool _isLoading = false;
  int? _currentUserId;
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';
  
  // Search and sorting - per user
  Map<int, String> _userSearchQueries = {};
  Map<int, String> _userSortOptions = {};
  Map<int, bool> _userSortAscending = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _fetchUsers();
  }

  Future<void> _getCurrentUserId() async {
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final httpClient = IOClient(ioc);

    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/users'));
      
      if (response.statusCode == 200) {
        final users = jsonDecode(response.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(users);
        });
        
        // Fetch items for each user
        for (var user in _users) {
          _fetchUserGroceryItems(user['id']);
          _fetchUserPantryItems(user['id']);
          _fetchUserSuggestions(user['id']);
        }
      }
    } catch (e) {
      print('Error fetching users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserGroceryItems(int userId) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final httpClient = IOClient(ioc);

    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/grocery/items?user_id=$userId')
      );
      
      if (response.statusCode == 200) {
        final items = jsonDecode(response.body);
        setState(() {
          _userGroceryItems[userId] = List<Map<String, dynamic>>.from(items);
        });
      }
    } catch (e) {
      print('Error fetching grocery items for user $userId: $e');
    }
  }

  Future<void> _fetchUserPantryItems(int userId) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final httpClient = IOClient(ioc);

    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/pantry/items?user_id=$userId')
      );
      
      if (response.statusCode == 200) {
        final items = jsonDecode(response.body);
        setState(() {
          _userPantryItems[userId] = List<Map<String, dynamic>>.from(items);
        });
      }
    } catch (e) {
      print('Error fetching pantry items for user $userId: $e');
    }
  }

  Future<void> _fetchUserSuggestions(int userId) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final httpClient = IOClient(ioc);

    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/grocery/suggestions?user_id=$userId&admin=true')
      );
      
      if (response.statusCode == 200) {
        final suggestions = jsonDecode(response.body);
        setState(() {
          _userSuggestions[userId] = List<Map<String, dynamic>>.from(suggestions);
        });
      }
    } catch (e) {
      print('Error fetching suggestions for user $userId: $e');
    }
  }

  Future<void> _deleteGroceryItem(int itemId, String itemName, int userId) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Grocery Item'),
        content: Text('Are you sure you want to delete "$itemName" from grocery list?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final response = await httpClient.delete(
        Uri.parse('$baseUrl/grocery/items/$itemId')
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Grocery item "$itemName" deleted successfully')),
        );
        _fetchUserGroceryItems(userId); // Refresh the items for this user
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete grocery item')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting grocery item: $e')),
      );
    }
  }

  Future<void> _deletePantryItem(int itemId, String itemName, int userId) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Pantry Item'),
        content: Text('Are you sure you want to delete "$itemName" from pantry?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final response = await httpClient.delete(
        Uri.parse('$baseUrl/pantry/items/$itemId')
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pantry item "$itemName" deleted successfully')),
        );
        _fetchUserPantryItems(userId); // Refresh the items for this user
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete pantry item')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting pantry item: $e')),
      );
    }
  }

  Future<void> _deleteSuggestion(String suggestionName, String suggestionCategory, int userId) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Suggestion'),
        content: Text('Are you sure you want to delete "$suggestionName" from suggestions?\n\nThis will remove it from the search autocomplete.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final response = await httpClient.delete(
        Uri.parse('$baseUrl/grocery/suggestions/$suggestionName/$suggestionCategory/$userId')
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suggestion "$suggestionName" deleted successfully')),
        );
        _fetchUserSuggestions(userId); // Refresh the suggestions for this user
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete suggestion')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting suggestion: $e')),
      );
    }
  }

  Future<void> _deleteUser(int userId, String username) async {
    // Don't allow deleting yourself
    if (userId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot delete your own account!')),
      );
      return;
    }

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete user "$username"?\n\nThis will permanently delete:\n• Their account\n• All their grocery items\n• All their pantry items\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final response = await httpClient.delete(
        Uri.parse('$baseUrl/users/$userId')
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User "$username" deleted successfully')),
        );
        _fetchUsers(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _filterAndSortItems(List<Map<String, dynamic>> items, String itemType, int userId) {
    final searchQuery = _userSearchQueries[userId] ?? '';
    final sortOption = _userSortOptions[userId] ?? 'name';
    final sortAscending = _userSortAscending[userId] ?? true;
    
    // Filter by search query
    List<Map<String, dynamic>> filteredItems = items.where((item) {
      if (searchQuery.isEmpty) return true;
      final name = item['name']?.toString().toLowerCase() ?? '';
      final category = item['category']?.toString().toLowerCase() ?? '';
      final type = item['type']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      
      return name.contains(query) || category.contains(query) || type.contains(query);
    }).toList();
    
    // Sort items
    filteredItems.sort((a, b) {
      int comparison = 0;
      
      switch (sortOption) {
        case 'name':
          comparison = (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
          break;
        case 'category':
          final aCategory = itemType == 'pantry' ? (a['type'] ?? '') : (a['category'] ?? '');
          final bCategory = itemType == 'pantry' ? (b['type'] ?? '') : (b['category'] ?? '');
          comparison = aCategory.toString().compareTo(bCategory.toString());
          break;
        case 'date':
          if (itemType == 'grocery') {
            comparison = (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString());
          } else if (itemType == 'pantry') {
            comparison = (a['entry_date'] ?? '').toString().compareTo((b['entry_date'] ?? '').toString());
          } else {
            comparison = (a['last_used'] ?? '').toString().compareTo((b['last_used'] ?? '').toString());
          }
          break;
        case 'frequency':
          if (itemType == 'suggestions') {
            comparison = (a['frequency'] ?? 0).compareTo(b['frequency'] ?? 0);
          } else {
            comparison = (a['quantity'] ?? 0).compareTo(b['quantity'] ?? 0);
          }
          break;
      }
      
      return sortAscending ? comparison : -comparison;
    });
    
    return filteredItems;
  }

  Widget _buildItemsList(List<Map<String, dynamic>> items, int userId, String itemType) {
    final filteredItems = _filterAndSortItems(items, itemType, userId);
    
    if (filteredItems.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            items.isEmpty ? 'No $itemType items yet' : 'No items match search criteria',
            style: TextStyle(color: Colors.grey)
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return ListTile(
          dense: true,
          leading: Icon(
            itemType == 'grocery' 
              ? (item['checked'] == 1 ? Icons.check_circle : Icons.radio_button_unchecked)
              : itemType == 'pantry'
                ? Icons.inventory
                : Icons.history,
            color: itemType == 'grocery' 
              ? (item['checked'] == 1 ? Colors.green : Colors.grey)
              : itemType == 'pantry'
                ? Colors.blue
                : Colors.orange,
          ),
          title: Text(item['name']),
          subtitle: itemType == 'grocery'
            ? Text('${item['category']} • Qty: ${item['quantity']}')
            : itemType == 'pantry'
              ? Text('${item['type']} • Qty: ${item['quantity']} • Expires: ${item['expiry_date']}')
              : Text('${item['category']} • Used ${item['frequency']} times • Last: ${item['last_used']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                itemType == 'grocery' 
                  ? item['created_at'].toString().split('T')[0]
                  : itemType == 'pantry'
                    ? item['entry_date'].toString()
                    : item['last_used'].toString().split('T')[0],
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  if (itemType == 'grocery') {
                    _deleteGroceryItem(item['id'], item['name'], userId);
                  } else if (itemType == 'pantry') {
                    _deletePantryItem(item['id'], item['name'], userId);
                  } else {
                    _deleteSuggestion(item['name'], item['category'], userId);
                  }
                },
                tooltip: 'Delete Item',
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final userGroceryItems = _userGroceryItems[user['id']] ?? [];
                final userPantryItems = _userPantryItems[user['id']] ?? [];
                final userSuggestions = _userSuggestions[user['id']] ?? [];
                final totalItems = userGroceryItems.length + userPantryItems.length + userSuggestions.length;
                
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Icon(
                          user['is_admin'] == 1 ? Icons.admin_panel_settings : Icons.person,
                          color: user['is_admin'] == 1 ? Colors.red : Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Text(user['username']),
                        if (user['is_admin'] == 1)
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'ADMIN',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text('$totalItems total items (${userGroceryItems.length} grocery, ${userPantryItems.length} pantry, ${userSuggestions.length} suggestions) • Created: ${user['created_at']}'),
                    trailing: user['id'] != _currentUserId 
                        ? IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(user['id'], user['username']),
                            tooltip: 'Delete User',
                          )
                        : null,
                    children: [
                      // User-specific search and sort controls
                      Container(
                        padding: EdgeInsets.all(12),
                        color: Colors.grey[50],
                        child: Column(
                          children: [
                            // Search box for this user
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Search ${user['username']}\'s items...',
                                prefixIcon: Icon(Icons.search, size: 20),
                                suffixIcon: (_userSearchQueries[user['id']] ?? '').isNotEmpty 
                                  ? IconButton(
                                      icon: Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _userSearchQueries[user['id']] = '';
                                        });
                                      },
                                    )
                                  : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _userSearchQueries[user['id']] = value;
                                });
                              },
                            ),
                            SizedBox(height: 8),
                            // Sort controls for this user
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _userSortOptions[user['id']] ?? 'name',
                                    decoration: InputDecoration(
                                      labelText: 'Sort by',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      isDense: true,
                                    ),
                                    items: [
                                      DropdownMenuItem(value: 'name', child: Text('Name')),
                                      DropdownMenuItem(value: 'category', child: Text('Category/Type')),
                                      DropdownMenuItem(value: 'date', child: Text('Date')),
                                      DropdownMenuItem(value: 'frequency', child: Text('Frequency/Qty')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _userSortOptions[user['id']] = value!;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    (_userSortAscending[user['id']] ?? true) 
                                      ? Icons.arrow_upward 
                                      : Icons.arrow_downward,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _userSortAscending[user['id']] = !(_userSortAscending[user['id']] ?? true);
                                    });
                                  },
                                  tooltip: (_userSortAscending[user['id']] ?? true) ? 'Ascending' : 'Descending',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Tabbed view for different data types
                      DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            TabBar(
                              labelColor: Colors.red,
                              unselectedLabelColor: Colors.grey,
                              tabs: [
                                Tab(text: 'Grocery (${userGroceryItems.length})'),
                                Tab(text: 'Pantry (${userPantryItems.length})'),
                                Tab(text: 'Suggestions (${userSuggestions.length})'),
                              ],
                            ),
                            Container(
                              height: (userGroceryItems.length + userPantryItems.length + userSuggestions.length) * 70.0 + 150,
                              child: TabBarView(
                                children: [
                                  // Grocery Items Tab
                                  _buildItemsList(userGroceryItems, user['id'], 'grocery'),
                                  // Pantry Items Tab
                                  _buildItemsList(userPantryItems, user['id'], 'pantry'),
                                  // Suggestions Tab
                                  _buildItemsList(userSuggestions, user['id'], 'suggestions'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchUsers,
        child: Icon(Icons.refresh),
        backgroundColor: Colors.red,
      ),
    );
  }
} 