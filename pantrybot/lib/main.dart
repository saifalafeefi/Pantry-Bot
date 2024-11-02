import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PantryBot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PantryList(),
    );
  }
}

class PantryList extends StatefulWidget {
  const PantryList({Key? key}) : super(key: key);

  @override
  _PantryListState createState() => _PantryListState();
}

class _PantryListState extends State<PantryList> {
  List<dynamic> items = [];
  final TextEditingController _controller = TextEditingController();
  
  // Make sure this URL uses http://
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  // Add this HTTP client that bypasses certificate verification
  final client = HttpClient()
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

  @override
  void initState() {
    super.initState();
    fetchItems();
  }

  Future<void> fetchItems() async {
    try {
      final ioClient = IOClient(client);
      final response = await ioClient.get(
        Uri.parse('$baseUrl/grocery/items'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        setState(() {
          items = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error fetching items: $e');
    }
  }

  Future<void> addItem(String name) async {
    final ioClient = IOClient(client);
    await ioClient.post(
      Uri.parse('$baseUrl/grocery/items'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name}),
    );
    _controller.clear();
    fetchItems();
  }

  Future<void> toggleItem(int id, bool checked) async {
    final ioClient = IOClient(client);
    await ioClient.put(
      Uri.parse('$baseUrl/grocery/items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'checked': checked ? 1 : 0}),
    );
    fetchItems();
  }

  Future<void> deleteItem(int id) async {
    final ioClient = IOClient(client);
    await ioClient.delete(Uri.parse('$baseUrl/grocery/items/$id'));
    fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PantryBot Shopping List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              fetchItems();  // Refresh data
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Add new item',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      addItem(_controller.text);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchItems,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: Checkbox(
                      value: item['checked'] == 1,
                      onChanged: (bool? value) {
                        toggleItem(item['id'], value ?? false);
                      },
                    ),
                    title: Text(
                      item['name'],
                      style: TextStyle(
                        color: item['checked'] == 1 ? Colors.green : Colors.black,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => deleteItem(item['id']),
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