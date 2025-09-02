import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'edit_recipe_screen.dart';
import '../main.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  final int userId;

  const RecipeDetailScreen({Key? key, required this.recipeId, required this.userId}) : super(key: key);

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? recipe;
  List<Map<String, dynamic>> ingredientsStatus = [];
  bool isLoading = true;
  String? error;
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
  }

  Future<void> _loadRecipeDetails() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Create HTTP client with SSL bypass
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      // Load recipe details
      final recipeResponse = await ioClient.get(
        Uri.parse('$baseUrl/recipes/${widget.recipeId}?user_id=${widget.userId}'),
      ).timeout(Duration(seconds: 10));

      if (recipeResponse.statusCode != 200) {
        throw Exception('Failed to load recipe: ${recipeResponse.statusCode}');
      }

      final recipeData = json.decode(recipeResponse.body);

      // Load ingredient status
      final statusResponse = await ioClient.get(
        Uri.parse('$baseUrl/recipes/${widget.recipeId}/ingredients/status?user_id=${widget.userId}'),
      ).timeout(Duration(seconds: 10));

      List<Map<String, dynamic>> statusData = [];
      if (statusResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(statusResponse.body);
        statusData = data.cast<Map<String, dynamic>>();
      }

      setState(() {
        recipe = recipeData;
        ingredientsStatus = statusData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error loading recipe: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _deleteRecipe() async {
    try {
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      final response = await ioClient.delete(
        Uri.parse('$baseUrl/recipes/${widget.recipeId}?user_id=${widget.userId}'),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        Navigator.of(context).pop(true); // Return true to indicate recipe was deleted
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete recipe: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting recipe: $e')),
      );
    }
  }

  void _confirmDeleteRecipe() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Recipe'),
          content: Text('Are you sure you want to delete this recipe? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRecipe();
              },
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'low_stock':
        return Colors.orange;
      case 'unavailable':
      default:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'low_stock':
        return Icons.warning;
      case 'unavailable':
      default:
        return Icons.cancel;
    }
  }

  String _formatTime(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }

  String _formatIngredientText(Map<String, dynamic> ingredient) {
    final name = ingredient['name'] ?? '';
    final quantity = ingredient['quantity'];
    final unit = ingredient['unit'] ?? '';
    
    // Only show quantity and unit if they have meaningful values
    final hasQuantity = quantity != null && quantity > 0 && quantity != 1.0;
    final hasUnit = unit.isNotEmpty && unit.toLowerCase() != 'piece';
    
    if (hasQuantity && hasUnit) {
      return '$quantity $unit $name';
    } else if (hasQuantity) {
      return '$quantity $name';
    } else if (hasUnit) {
      return '$unit $name';
    } else {
      return name;
    }
  }

  Future<void> _addToGroceryList(Map<String, dynamic> ingredient) async {
    try {
      // Create HTTP client with SSL bypass
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);

      // Prepare grocery item data
      final groceryItem = {
        'name': ingredient['name'],
        'quantity': (ingredient['quantity'] ?? 1.0).round(),
        'category': 'Other', // Default category - could be improved with categorization logic
        'metric': ingredient['unit'] == 'Piece' ? null : ingredient['unit'],
        'amount_per_item': null,
        'user_id': widget.userId,
      };

      final response = await ioClient.post(
        Uri.parse('$baseUrl/grocery/items'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(groceryItem),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${ingredient['name']} added to grocery list!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View List',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to grocery list - need to import and navigate
                _navigateToGroceryList();
              },
            ),
          ),
        );
      } else {
        throw Exception('Failed to add item: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error adding to grocery list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToGroceryList() {
    // Navigate directly to grocery list screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PantryList(
          isAdmin: false, // We don't have admin status from recipe screen
          userId: widget.userId,
          username: '', // We don't have username from recipe screen
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe?['title'] ?? 'Recipe'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              if (recipe != null) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditRecipeScreen(
                      userId: widget.userId,
                      recipe: recipe!,
                    ),
                  ),
                );
                if (result == true) {
                  _loadRecipeDetails(); // Refresh recipe details
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _confirmDeleteRecipe,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(error!, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRecipeDetails,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipe Image
                      if (recipe?['image_path'] != null)
                        Container(
                          width: double.infinity,
                          height: 200,
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.orange.shade100,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(recipe!['image_path']),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.restaurant_menu, size: 48, color: Colors.orange.shade300),
                                      Text('Image not found', style: TextStyle(color: Colors.orange.shade400)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      // Recipe Title & Info
                      Text(
                        recipe?['title'] ?? 'Untitled',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      if (recipe?['description']?.isNotEmpty == true)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            recipe!['description'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),

                      // Timing and servings info
                      Row(
                        children: [
                          if (recipe?['prep_time'] != null && recipe!['prep_time'] > 0)
                            _buildInfoChip(
                              icon: Icons.schedule,
                              label: 'Prep: ${_formatTime(recipe!['prep_time'])}',
                            ),
                          if (recipe?['cook_time'] != null && recipe!['cook_time'] > 0)
                            _buildInfoChip(
                              icon: Icons.local_fire_department,
                              label: 'Cook: ${_formatTime(recipe!['cook_time'])}',
                            ),
                          if (recipe?['servings'] != null && recipe!['servings'] > 0)
                            _buildInfoChip(
                              icon: Icons.people,
                              label: '${recipe!['servings']} servings',
                            ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Ingredients Section
                      Text(
                        'Ingredients',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),

                      if (recipe?['ingredients']?.isNotEmpty == true)
                        ...recipe!['ingredients'].asMap().entries.map<Widget>((entry) {
                          final ingredient = entry.value;
                          final ingredientStatus = ingredientsStatus.firstWhere(
                            (status) => status['name'] == ingredient['name'],
                            orElse: () => {'status': 'unknown'},
                          );

                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getStatusIcon(ingredientStatus['status'] ?? 'unknown'),
                                  color: _getStatusColor(ingredientStatus['status'] ?? 'unknown'),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _formatIngredientText(ingredient),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                                if (ingredientStatus['status'] == 'unavailable')
                                  IconButton(
                                    icon: Icon(Icons.add_shopping_cart, color: Colors.blue),
                                    onPressed: () => _addToGroceryList(ingredient),
                                    tooltip: 'Add to grocery list',
                                  ),
                              ],
                            ),
                          );
                        }).toList(),

                      SizedBox(height: 24),

                      // Instructions Section
                      Text(
                        'Instructions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),

                      if (recipe?['steps']?.isNotEmpty == true)
                        ...recipe!['steps'].asMap().entries.map<Widget>((entry) {
                          final step = entry.value;
                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${step['number']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    step['instruction'],
                                    style: TextStyle(fontSize: 16, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orange.shade700),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}