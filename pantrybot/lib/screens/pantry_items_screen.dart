import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

class PantryItemsScreen extends StatefulWidget {
  final int userId;
  final bool isAdmin;

  const PantryItemsScreen({
    Key? key,
    required this.userId,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _PantryItemsScreenState createState() => _PantryItemsScreenState();
}

class _PantryItemsScreenState extends State<PantryItemsScreen> {
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'expiry_date';

  @override
  void initState() {
    super.initState();
    fetchItems();
  }

  Future<void> fetchItems() async {
    try {
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final response = await httpClient.get(
        Uri.parse('https://192.168.1.192:8443/pantry/items?user_id=${widget.userId}&sort=$sortBy'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> itemsData = jsonDecode(response.body);
        setState(() {
          items = itemsData.map((item) => Map<String, dynamic>.from(item)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching items: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteItem(int itemId) async {
    try {
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final response = await httpClient.delete(
        Uri.parse('https://192.168.1.192:8443/pantry/items/$itemId'),
      );

      if (response.statusCode == 200) {
        fetchItems(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item')),
      );
    }
  }

  List<Map<String, dynamic>> getFilteredItems() {
    if (searchQuery.isEmpty) return items;
    return items.where((item) => 
      item['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
      item['type'].toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  Color getExpiryColor(String expiryDate) {
    try {
      final expiry = DateTime.parse(expiryDate);
      final now = DateTime.now();
      final difference = expiry.difference(now).inDays;

      if (difference < 0) return Colors.red; // Expired
      if (difference <= 3) return Colors.orange; // Expiring soon
      if (difference <= 7) return Colors.yellow; // Expiring this week
      return Colors.green; // Fresh
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = getFilteredItems();

    return Scaffold(
      appBar: AppBar(
        title: Text('Pantry Items'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddItemDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and sort controls
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search items...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text('Sort by: '),
                    Expanded(
                      child: DropdownButton<String>(
                        value: sortBy,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: 'expiry_date', child: Text('Expiry Date')),
                          DropdownMenuItem(value: 'name', child: Text('Name')),
                          DropdownMenuItem(value: 'type', child: Text('Category')),
                          DropdownMenuItem(value: 'entry_date', child: Text('Date Added')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            sortBy = value!;
                          });
                          fetchItems();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.kitchen, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No pantry items found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add some items to get started!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final expiryColor = getExpiryColor(item['expiry_date']);
                          
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 4,
                                color: expiryColor,
                              ),
                              title: Text(
                                item['name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category: ${item['type']}'),
                                  Text('Quantity: ${item['quantity']}'),
                                  Text('Expires: ${item['expiry_date']}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditItemDialog(item),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDelete(item),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    _showItemDialog();
  }

  void _showEditItemDialog(Map<String, dynamic> item) {
    _showItemDialog(item: item);
  }

  void _showItemDialog({Map<String, dynamic>? item}) {
    final nameController = TextEditingController(text: item?['name'] ?? '');
    final quantityController = TextEditingController(text: item?['quantity']?.toString() ?? '1');
    String selectedType = item?['type'] ?? 'Vegetables';
    DateTime selectedDate = item != null 
        ? DateTime.parse(item['expiry_date']) 
        : DateTime.now().add(Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Pantry Item' : 'Edit Pantry Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Dairy', 'Meat', 'Vegetables', 'Fruits', 'Grains', 'Sweets', 'Oils']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                ListTile(
                  title: Text('Expiry Date'),
                  subtitle: Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveItem(
                  item?['id'],
                  nameController.text,
                  selectedType,
                  int.tryParse(quantityController.text) ?? 1,
                  selectedDate,
                );
                Navigator.pop(context);
              },
              child: Text(item == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveItem(int? itemId, String name, String type, int quantity, DateTime expiryDate) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }

    try {
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final httpClient = IOClient(ioc);

      final body = jsonEncode({
        'name': name,
        'type': type,
        'quantity': quantity,
        'expiry_date': '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
        'user_id': widget.userId,
      });

      http.Response response;
      if (itemId == null) {
        // Add new item
        response = await httpClient.post(
        Uri.parse('https://192.168.1.192:8443/pantry/items'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
      } else {
        // Update existing item
        response = await httpClient.put(
        Uri.parse('https://192.168.1.192:8443/pantry/items/$itemId'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchItems(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(itemId == null ? 'Item added successfully' : 'Item updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item')),
      );
    }
  }

  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteItem(item['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
} 