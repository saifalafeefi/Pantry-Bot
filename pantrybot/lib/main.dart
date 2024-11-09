import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

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

enum SortOption {
  unchecked,
  aToZ,
  zToA,
  oldest,
  newest,
}

class _PantryListState extends State<PantryList> {
  List<dynamic> items = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _originalItems = [];
  SortOption _currentSort = SortOption.newest;

  // Make sure this URL uses http://
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  // Add this HTTP client that bypasses certificate verification
  final client = HttpClient()
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    fetchItems();
    
    // Set up timer to refresh every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      fetchItems();
    });
  }

  // Add dispose method to clean up the timer
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchItems() async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.get(Uri.parse('$baseUrl/grocery/items'));
      if (response.statusCode == 200) {
        setState(() {
          items = jsonDecode(response.body);
          _originalItems = List.from(items);
          _sortItems();
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

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      items = List.from(_originalItems);
    });
  }

  void _showQuantityDialog(String itemName) {
    int quantity = 1;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Quantity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) {
                            setState(() => quantity--);
                          }
                        },
                      ),
                      SizedBox(
                        width: 50,
                        child: TextField(
                          textAlign: TextAlign.center,
                          controller: TextEditingController(text: quantity.toString()),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final newQuantity = int.tryParse(value);
                            if (newQuantity != null && newQuantity > 0) {
                              setState(() => quantity = newQuantity);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() => quantity++);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: () {
                    final finalName = '$itemName ($quantity)';
                    Navigator.of(context).pop();
                    addItem(finalName);  // Use your existing addItem method
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
          items.sort((a, b) => (a['checked'] as int).compareTo(b['checked'] as int));
          break;
        case SortOption.aToZ:
          items.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          break;
        case SortOption.zToA:
          items.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
          break;
        case SortOption.oldest:
          items.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
          break;
        case SortOption.newest:
          items.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PantryBot Shopping List'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.filter_list),
            onSelected: (SortOption result) {
              setState(() {
                _currentSort = result;
                _sortItems();
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
                      _showQuantityDialog(_controller.text);
                    }
                  },
                ),
              ],
            ),
          ),
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
                      if (value.isEmpty) {
                        items = List.from(_originalItems);
                      } else {
                        items = _originalItems
                            .where((item) => item['name']
                                .toString()
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      }
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