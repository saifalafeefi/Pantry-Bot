import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';

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
  category,
}

enum ItemCategory {
  Vegetables,
  Fruits,
  Dairy,
  Meats,
  Grains,
  Sweets,
  Oils,
  Electronics,
  Drinks,
  Medicine,
  Cleaning,
  Other,
}

enum FilterOption { all, checked, unchecked, category }

final categoryColors = {
  ItemCategory.Vegetables: Color(0xFFE8F5E9),  // Light green
  ItemCategory.Fruits: Color(0xFFC8E6C9),      // Slightly darker green
  ItemCategory.Dairy: Color(0xFFE3F2FD),       // Light blue
  ItemCategory.Meats: Color(0xFFFFEBEE),       // Light red
  ItemCategory.Grains: Color(0xFFEFEBE9),      // Light brown
  ItemCategory.Sweets: Color(0xFFFCE4EC),      // Pink
  ItemCategory.Oils: Color(0xFFFFFDE7),        // Light yellow
};

class _PantryListState extends State<PantryList> {
  List<dynamic> items = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _originalItems = [];
  SortOption _currentSort = SortOption.newest;
  FilterOption _filterOption = FilterOption.all;

  // Make sure this URL uses http://
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  // Add this HTTP client that bypasses certificate verification
  final client = HttpClient()
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

  Timer? _refreshTimer;

  String? _selectedCategory;

  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounceTimer;

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
          final newItems = jsonDecode(response.body);
          _originalItems = List.from(newItems);
          
          // Apply current search filter
          if (_searchController.text.isNotEmpty) {
            items = _originalItems
                .where((item) => item['name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
                .toList();
          } else {
            items = List.from(_originalItems);
          }
          _sortItems();
        });
      }
    } catch (e) {
      print('Error fetching items: $e');
    }
  }

  Future<void> addItem(String name, int quantity, String category) async {
    
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/grocery/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'quantity': quantity,
          'category': category,  // Make sure this is being sent
        }),
      );
            
      if (response.statusCode == 200) {
        _controller.clear();
        fetchItems();
      }
    } catch (e) {
      print('Error adding item: $e');
    }
  }

  Future<void> toggleItem(int id, bool checked) async {
    HapticFeedback.selectionClick();
    
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/grocery/items/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'checked': checked ? 1 : 0,
          'name': items.firstWhere((item) => item['id'] == id)['name'],
          'quantity': items.firstWhere((item) => item['id'] == id)['quantity'],
          'category': items.firstWhere((item) => item['id'] == id)['category'],
        }),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          var item = items.firstWhere((item) => item['id'] == id);
          item['checked'] = checked ? 1 : 0;
        });
        fetchItems();
      }
    } catch (e) {
      print('Error toggling item: $e');
    }
  }

  Future<void> deleteItem(int id) async {
    HapticFeedback.heavyImpact();
    
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

  void _showAddItemDialog(String itemName, {String? defaultCategory}) {
    HapticFeedback.mediumImpact();
    
    String selectedCategory = defaultCategory ?? 'Vegetables';
    int quantity = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Item: $itemName'),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Quantity: '),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) setState(() => quantity--);
                        },
                      ),
                      Text('$quantity'),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // Make sure this dropdown is working
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Vegetables', 'Fruits', 'Dairy', 'Meats', 
                      'Grains', 'Sweets', 'Oils', 'Electronics', 
                      'Drinks', 'Medicine', 'Cleaning', 'Other'
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedCategory = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Add'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    addItem(itemName, quantity, selectedCategory);
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
        case SortOption.category:
          // Sort by category
          items.sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));
          break;
      }
    });
  }

  void _showEditDialog(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    
    String name = item['name'];
    int quantity = item['quantity'];
    String category = item['category'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(labelText: 'Name'),
                    controller: TextEditingController(text: name),
                    onChanged: (value) => name = value,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Quantity: '),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) setState(() => quantity--);
                        },
                      ),
                      Text('$quantity'),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Vegetables', 'Fruits', 'Dairy', 'Meats', 
                      'Grains', 'Sweets', 'Oils', 'Electronics', 
                      'Drinks', 'Medicine', 'Cleaning', 'Other'
                    ].map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => category = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Save'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    updateItem(item['id'], name, quantity, category);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> updateItem(int id, String name, int quantity, String category) async {
    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/grocery/items/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'quantity': quantity,
          'category': category,
          'checked': items.firstWhere((item) => item['id'] == id)['checked'],
        }),
      );
      if (response.statusCode == 200) {
        fetchItems();
      }
    } catch (e) {
      print('Error updating item: $e');
    }
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('All Categories'),
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                      _currentSort = SortOption.newest;  // Reset to default sort
                    });
                    Navigator.of(context).pop();
                  },
                ),
                Divider(),
                ...[
                  'Vegetables', 'Fruits', 'Dairy', 'Meats', 
                  'Grains', 'Sweets', 'Oils', 'Electronics', 
                  'Drinks', 'Medicine', 'Cleaning', 'Other'
                ].map((category) => ListTile(
                  title: Text(category),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _currentSort = SortOption.newest;  // Reset to default sort
                    });
                    Navigator.of(context).pop();
                  },
                )).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    var allItems = items.map((item) => item as Map<String, dynamic>).toList();
    
    // If a category is selected, split and reorder the items
    if (_selectedCategory != null) {
      var categoryItems = allItems.where((item) => 
        item['category'] == _selectedCategory).toList();
      var otherItems = allItems.where((item) => 
        item['category'] != _selectedCategory).toList();
      
      // Sort each group separately
      _applySorting(categoryItems);
      _applySorting(otherItems);
      
      // Combine with selected category items at the top
      return [...categoryItems, ...otherItems];
    }
    
    // If no category selected, just sort all items
    _applySorting(allItems);
    return allItems;
  }

  void _applySorting(List<Map<String, dynamic>> items) {
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
      case SortOption.category:
        items.sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));
        break;
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final ioc = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    final http = IOClient(ioc);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/grocery/suggestions?query=${Uri.encodeComponent(query)}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  Widget _buildAddItemField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Add new item',
                  ),
                  onChanged: (value) {
                    // Debounce the API calls
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                      _fetchSuggestions(value);
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    HapticFeedback.mediumImpact();
                    _showAddItemDialog(_controller.text);
                  }
                },
              ),
            ],
          ),
          // Show suggestions below the input field
          if (_suggestions.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _suggestions.map((suggestion) => ListTile(
                  title: Text(suggestion['name']),
                  subtitle: Text(suggestion['category']),
                  trailing: Text('Used ${suggestion['use_count']} times'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _controller.text = suggestion['name'];
                    _showAddItemDialog(
                      suggestion['name'],
                      defaultCategory: suggestion['category'],
                    );
                    setState(() => _suggestions = []);
                  },
                )).toList(),
              ),
            ),
        ],
      ),
    );
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
                if (result == SortOption.category) {
                  _showCategoryFilterDialog();
                } else {
                  _currentSort = result;
                  _sortItems();
                }
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
              const PopupMenuDivider(),  // Add a divider
              const PopupMenuItem<SortOption>(
                value: SortOption.category,
                child: Text('Filter by Category'),
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
          _buildAddItemField(),
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
                itemCount: _getFilteredItems().length,
                itemBuilder: (context, index) {
                  final item = _getFilteredItems()[index];
                  final category = item['category'] as String? ?? 'Vegetables';
                  
                  final Color itemColor = switch(category.toLowerCase().trim()) {
                    'vegetables' => Color(0xFFBEDFBF),  // More opaque green
                    'fruits' => Color(0xFFA8D5AA),      // More opaque darker green
                    'dairy' => Color(0xFFB3D4FC),       // More opaque blue
                    'meats' => Color(0xFFFFCCCC),       // More opaque red
                    'grains' => Color(0xFFDBC8B8),      // More opaque brown
                    'sweets' => Color(0xFFFFC4D6),      // More opaque pink
                    'oils' => Color(0xFFFFE5A5),        // More opaque yellow
                    'electronics' => Color(0xFFB3E5FC),  // More opaque cyan
                    'drinks' => Color(0xFFB2DFDB),      // More opaque teal
                    'medicine' => Color(0xFFE1BEE7),    // More opaque purple
                    'cleaning' => Color(0xFFE0E0E0),    // More opaque gray
                    'other' => Color(0xFFEEEEEE),       // More opaque light gray
                    _ => Colors.white,
                  };

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: item['checked'] == 1,
                        onChanged: (bool? value) {
                          HapticFeedback.selectionClick();
                          toggleItem(item['id'], value ?? false);
                        },
                      ),
                      title: Text(
                        '${item['name']} (${item['quantity']}) ($category)',
                        style: TextStyle(
                          decoration: item['checked'] == 1 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showEditDialog(item);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              HapticFeedback.heavyImpact();
                              deleteItem(item['id']);
                            },
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
      ),
    );
  }
}

class GroceryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(bool?) onCheckboxChanged;
  final Function() onEdit;

  const GroceryItem({
    Key? key,
    required this.item,
    required this.onCheckboxChanged,
    required this.onEdit,
  }) : super(key: key);

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables': return Color(0xFFE8F5E9);
      case 'fruits': return Color(0xFFC8E6C9);
      case 'dairy': return Color(0xFFE3F2FD);
      case 'meats': return Color(0xFFFFEBEE);
      case 'grains': return Color(0xFFEFEBE9);
      case 'sweets': return Color(0xFFFCE4EC);
      case 'oils': return Color(0xFFFFFDE7);
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getCategoryColor(item['category']),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: item['checked'] == 1,
          onChanged: onCheckboxChanged,
        ),
        title: Text(
          '${item['name']} (${item['quantity']}) (${item['category']})',
          style: TextStyle(
            decoration: item['checked'] == 1 ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
    );
  }
}