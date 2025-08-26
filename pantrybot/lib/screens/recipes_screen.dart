import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'recipe_detail_screen.dart';
import 'add_recipe_screen.dart';

class RecipesScreen extends StatefulWidget {
  final int userId;
  final bool isAdmin;

  const RecipesScreen({Key? key, required this.userId, required this.isAdmin}) : super(key: key);

  @override
  _RecipesScreenState createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Map<String, dynamic>> recipes = [];
  bool isLoading = true;
  String? error;
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Create HTTP client with SSL bypass
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);
      
      final response = await ioClient.get(
        Uri.parse('$baseUrl/recipes?user_id=${widget.userId}'),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          recipes = data.cast<Map<String, dynamic>>();
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load recipes: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error loading recipes: $e';
        isLoading = false;
      });
    }
  }

  String _formatTime(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recipes'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRecipes,
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
                        onPressed: _loadRecipes,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : recipes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No recipes yet'),
                          Text('Tap + to add your first recipe!'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRecipes,
                      child: GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // 3 columns as requested
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.75, // Adjust card height for 3 columns
                        ),
                        itemCount: recipes.length,
                        itemBuilder: (context, index) {
                          final recipe = recipes[index];
                          return GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecipeDetailScreen(
                                    recipeId: recipe['id'],
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadRecipes(); // Refresh if recipe was modified
                              }
                            },
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        color: Colors.orange.shade100,
                                      ),
                                      child: recipe['image_path'] != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                              child: Image.file(
                                                File(recipe['image_path']),
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return _buildPlaceholder();
                                                },
                                              ),
                                            )
                                          : _buildPlaceholder(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recipe['title'] ?? 'Untitled',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12, // Smaller for 3-column layout
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          if (recipe['prep_time'] != null || recipe['cook_time'] != null)
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 12, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '${_formatTime(recipe['prep_time'])} ${_formatTime(recipe['cook_time'])}'.trim(),
                                                    style: TextStyle(
                                                      fontSize: 10, // Even smaller for 3-column
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (recipe['servings'] != null && recipe['servings'] > 0)
                                            Row(
                                              children: [
                                                Icon(Icons.people, size: 12, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${recipe['servings']} servings',
                                                  style: TextStyle(
                                                    fontSize: 10, // Even smaller for 3-column
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddRecipeScreen(userId: widget.userId),
            ),
          );
          if (result == true) {
            _loadRecipes(); // Refresh after adding new recipe
          }
        },
        backgroundColor: Colors.orange,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.orange.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 32,
            color: Colors.orange.shade300,
          ),
          SizedBox(height: 4),
          Text(
            'No Image',
            style: TextStyle(
              color: Colors.orange.shade400,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}