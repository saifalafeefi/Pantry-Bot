import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'login_screen.dart';

const String baseUrl = 'https://pantrybot.anonstorage.org:8443';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _selectedUser;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchUsers();
    _fetchSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => CheckboxListTile(
                title: Text('Admin User'),
                value: isAdmin,
                onChanged: (bool? value) {
                  setState(() => isAdmin = value ?? false);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _addUser(
                usernameController.text,
                passwordController.text,
                isAdmin,
              );
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addUser(String username, String password, bool isAdmin) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'is_admin': isAdmin ? 1 : 0,
        }),
      );

      if (response.statusCode == 200) {
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding user: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error adding user: $e');
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(_searchController.text);
    });
  }

  Future<void> _fetchSuggestions([String? query]) async {
    setState(() => _isLoading = true);
    
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final queryParams = {
        'admin': 'true',
        if (query?.isNotEmpty ?? false) 'query': query!,
        if (_selectedUser != null && _selectedUser != 'All Users') 'user': _selectedUser!,
      };

      final uri = Uri.parse('$baseUrl/grocery/suggestions')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editSuggestion(Map<String, dynamic> suggestion) async {
    final TextEditingController nameController = TextEditingController(text: suggestion['name']);
    final TextEditingController categoryController = TextEditingController(text: suggestion['category']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Suggestion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(labelText: 'Category'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Update suggestion in database
              await _updateSuggestion(
                suggestion['id'],
                nameController.text,
                categoryController.text,
              );
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSuggestion(int id, String name, String category) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/grocery/suggestions/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'category': category,
        }),
      );
      if (response.statusCode == 200) {
        _fetchSuggestions();
      }
    } catch (e) {
      print('Error updating suggestion: $e');
    }
  }

  Future<void> _deleteSuggestion(int id) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/grocery/suggestions/$id'),
      );
      if (response.statusCode == 200) {
        _fetchSuggestions();
      }
    } catch (e) {
      print('Error deleting suggestion: $e');
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Suggestion'),
        content: Text('Are you sure you want to delete this suggestion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Add delete suggestion logic here
              Navigator.pop(context);
            },
            child: Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin Panel'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Suggestions'),
              Tab(text: 'Users'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => LoginScreen())
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Suggestions Tab
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedUser,
                          decoration: InputDecoration(
                            labelText: 'Select User',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String>(value: null, child: Text('All Users')),
                            ..._users.map((user) => DropdownMenuItem<String>(
                              value: user['username'] as String,
                              child: Text(user['username'] as String),
                            )).toList(),
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedUser = newValue;
                              _fetchSuggestions(_searchController.text);
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search Suggestions',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildSuggestionsList(),
                ),
              ],
            ),
            // Users Tab
            _buildUsersTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddUserDialog,
          child: Icon(Icons.add),
          tooltip: 'Add User',
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          title: Text(suggestion['name']),
          subtitle: Text(
            'Category: ${suggestion['category']} | Used: ${suggestion['use_count']} times'
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => _editSuggestion(suggestion),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _showDeleteConfirmation(suggestion),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: Icon(Icons.person),
          title: Text(user['username']),
          subtitle: Text(user['is_admin'] == 1 ? 'Admin' : 'User'),
          trailing: user['username'] != 'admin' ? IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _showDeleteUserConfirmation(user),
          ) : null,
        );
      },
    );
  }

  void _showDeleteUserConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['username']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Add delete user API call here
              Navigator.pop(context);
            },
            child: Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
} 