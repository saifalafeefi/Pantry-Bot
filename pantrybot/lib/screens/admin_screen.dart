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
  Map<int, List<Map<String, dynamic>>> _userItems = {};
  bool _isLoading = false;
  final String baseUrl = 'https://192.168.1.192:8443';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
          _fetchUserItems(user['id']);
        }
      }
    } catch (e) {
      print('Error fetching users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserItems(int userId) async {
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
          _userItems[userId] = List<Map<String, dynamic>>.from(items);
        });
      }
    } catch (e) {
      print('Error fetching items for user $userId: $e');
    }
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
                final userItems = _userItems[user['id']] ?? [];
                
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
                    subtitle: Text('${userItems.length} items • Created: ${user['created_at']}'),
                    children: [
                      if (userItems.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No items yet', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ...userItems.map((item) => ListTile(
                          dense: true,
                          leading: Icon(
                            item['checked'] == 1 ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: item['checked'] == 1 ? Colors.green : Colors.grey,
                          ),
                          title: Text(item['name']),
                          subtitle: Text('${item['category']} • Qty: ${item['quantity']}'),
                          trailing: Text(
                            item['created_at'].toString().split('T')[0],
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )).toList(),
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