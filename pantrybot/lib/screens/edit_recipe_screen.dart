import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class EditRecipeScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> recipe;

  const EditRecipeScreen({Key? key, required this.userId, required this.recipe}) : super(key: key);

  @override
  _EditRecipeScreenState createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();

  // Dynamic lists with autocomplete support
  List<IngredientWidget> ingredientWidgets = [];
  List<TextEditingController> steps = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecipeData();
  }

  void _loadRecipeData() {
    // Pre-populate form fields
    _titleController.text = widget.recipe['title'] ?? '';
    _descriptionController.text = widget.recipe['description'] ?? '';
    _prepTimeController.text = (widget.recipe['prep_time'] ?? 0).toString();
    _cookTimeController.text = (widget.recipe['cook_time'] ?? 0).toString();
    _servingsController.text = (widget.recipe['servings'] ?? 1).toString();

    // Pre-populate ingredients
    final ingredients = widget.recipe['ingredients'] as List<dynamic>? ?? [];
    for (var ingredient in ingredients) {
      final ingredientWidget = IngredientWidget(
        key: GlobalKey<_IngredientWidgetState>(),
        userId: widget.userId,
        onRemove: () => _removeIngredient(ingredientWidgets.length - 1),
        canRemove: true,
        initialData: {
          'name': ingredient['name'] ?? '',
          'quantity': (ingredient['quantity'] ?? 1.0).toString(),
          'unit': ingredient['unit'] ?? 'Piece',
        },
      );
      ingredientWidgets.add(ingredientWidget);
    }

    // Ensure at least one ingredient field
    if (ingredientWidgets.isEmpty) {
      _addIngredient();
    }

    // Pre-populate steps
    final recipeSteps = widget.recipe['steps'] as List<dynamic>? ?? [];
    for (var step in recipeSteps) {
      final stepController = TextEditingController();
      stepController.text = step['instruction'] ?? '';
      steps.add(stepController);
    }

    // Ensure at least one step field
    if (steps.isEmpty) {
      _addStep();
    }

    // Update remove callbacks after loading
    _updateIngredientCallbacks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    
    for (var ingredient in ingredientWidgets) {
      ingredient.dispose();
    }
    
    for (var step in steps) {
      step.dispose();
    }
    
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      ingredientWidgets.add(IngredientWidget(
        key: GlobalKey<_IngredientWidgetState>(),
        userId: widget.userId,
        onRemove: () => _removeIngredient(ingredientWidgets.length - 1),
        canRemove: ingredientWidgets.length > 0,
      ));
      _updateIngredientCallbacks();
    });
  }

  void _removeIngredient(int index) {
    if (ingredientWidgets.length > 1) {
      setState(() {
        ingredientWidgets[index].dispose();
        ingredientWidgets.removeAt(index);
        _updateIngredientCallbacks();
      });
    }
  }

  void _updateIngredientCallbacks() {
    for (int i = 0; i < ingredientWidgets.length; i++) {
      ingredientWidgets[i].updateRemoveCallback(() => _removeIngredient(i));
      ingredientWidgets[i].updateCanRemove(ingredientWidgets.length > 1);
    }
  }

  void _addStep() {
    setState(() {
      steps.add(TextEditingController());
    });
  }

  void _removeStep(int index) {
    if (steps.length > 1) {
      setState(() {
        steps[index].dispose();
        steps.removeAt(index);
      });
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Collect ingredient data
      List<Map<String, dynamic>> ingredientData = [];
      for (var widget in ingredientWidgets) {
        final data = widget.getIngredientData();
        if (data != null && data['name'].isNotEmpty) {
          ingredientData.add(data);
        }
      }

      // Prepare recipe data
      final recipeData = {
        'user_id': widget.userId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'prep_time': int.tryParse(_prepTimeController.text) ?? 0,
        'cook_time': int.tryParse(_cookTimeController.text) ?? 0,
        'servings': int.tryParse(_servingsController.text) ?? 1,
        'ingredients': ingredientData,
        'steps': steps
            .where((step) => step.text.isNotEmpty)
            .map((step) => step.text)
            .toList(),
      };

      // Create HTTP client with SSL bypass
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);

      final response = await ioClient.put(
        Uri.parse('$baseUrl/recipes/${widget.recipe['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(recipeData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update recipe: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating recipe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Recipe'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveRecipe,
              child: Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Recipe Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a recipe title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),

              // Time and servings row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prepTimeController,
                      decoration: InputDecoration(
                        labelText: 'Prep Time (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cookTimeController,
                      decoration: InputDecoration(
                        labelText: 'Cook Time (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _servingsController,
                      decoration: InputDecoration(
                        labelText: 'Servings',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Ingredients section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addIngredient,
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              ...ingredientWidgets.asMap().entries.map((entry) {
                final index = entry.key;
                final widget = entry.value;
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget,
                );
              }).toList(),

              SizedBox(height: 24),

              // Steps section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Instructions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addStep,
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        margin: EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: step,
                          decoration: InputDecoration(
                            labelText: 'Instruction',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: index == 0
                              ? (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter at least one instruction';
                                  }
                                  return null;
                                }
                              : null,
                        ),
                      ),
                      IconButton(
                        onPressed: steps.length > 1 ? () => _removeStep(index) : null,
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                      ),
                    ],
                  ),
                );
              }).toList(),

              SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Updating Recipe...'),
                          ],
                        )
                      : Text(
                          'Update Recipe',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reuse the same IngredientWidget from add_recipe_screen.dart but with initial data support
class IngredientWidget extends StatefulWidget {
  final int userId;
  final VoidCallback onRemove;
  final bool canRemove;
  final Map<String, String>? initialData;

  IngredientWidget({
    Key? key,
    required this.userId,
    required this.onRemove,
    required this.canRemove,
    this.initialData,
  }) : super(key: key);

  late VoidCallback _onRemove;
  late bool _canRemove;

  void updateRemoveCallback(VoidCallback callback) {
    _onRemove = callback;
  }

  void updateCanRemove(bool canRemove) {
    _canRemove = canRemove;
  }

  @override
  _IngredientWidgetState createState() => _IngredientWidgetState();

  void dispose() {
    // Handled by the state class
  }

  Map<String, dynamic>? getIngredientData() {
    final state = key as GlobalKey?;
    return (state?.currentState as _IngredientWidgetState?)?.getIngredientData();
  }
}

class _IngredientWidgetState extends State<IngredientWidget> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  
  List<Map<String, dynamic>> suggestions = [];
  bool showSuggestions = false;
  Timer? _debounceTimer;
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  @override
  void initState() {
    super.initState();
    widget._onRemove = widget.onRemove;
    widget._canRemove = widget.canRemove;
    
    // Pre-populate with initial data if provided
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _quantityController.text = widget.initialData!['quantity'] ?? '';
      _unitController.text = widget.initialData!['unit'] ?? '';
    }
    
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onNameChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      if (_nameController.text.length > 0) {
        _getSuggestions(_nameController.text);
      } else {
        setState(() {
          suggestions.clear();
          showSuggestions = false;
        });
      }
    });
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);

      final response = await ioClient.get(
        Uri.parse('$baseUrl/ingredients/suggestions?user_id=${widget.userId}&query=${Uri.encodeQueryComponent(query)}'),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          suggestions = data.cast<Map<String, dynamic>>();
          showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error getting suggestions: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    setState(() {
      _nameController.text = suggestion['name'];
      _unitController.text = suggestion['metric'] ?? 'Piece';
      showSuggestions = false;
      suggestions.clear();
    });
  }

  Future<void> _showNewIngredientDialog() async {
    String? category;
    String? metric;
    String? amountPerItem;

    final categories = [
      'Vegetables', 'Fruits', 'Dairy', 'Meats', 'Grains', 'Sweets',
      'Oils', 'Electronics', 'Drinks', 'Medicine', 'Cleaning', 'Other'
    ];

    final metrics = ['Piece', 'Gram', 'Kg', 'Litre', 'ml', 'Pack', 'Bottle', 'Can', 'Bunch', 'Bag'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('New Ingredient: ${_nameController.text}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('This ingredient is not in your grocery database yet. Please specify:'),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        category = value;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: metric,
                    decoration: InputDecoration(
                      labelText: 'Default Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: metrics.map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        metric = value;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Amount per item (optional)',
                      hintText: 'e.g., 500g, 2L',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      amountPerItem = value;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Add to Database'),
                  onPressed: category != null ? () {
                    Navigator.of(context).pop({
                      'category': category!,
                      'metric': metric ?? 'Piece',
                      'amount_per_item': amountPerItem ?? '',
                    });
                  } : null,
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _addIngredientToDatabase(result);
    }
  }

  Future<void> _addIngredientToDatabase(Map<String, String> ingredientData) async {
    try {
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);

      final response = await ioClient.post(
        Uri.parse('$baseUrl/ingredients/add-to-history'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId,
          'name': _nameController.text,
          'category': ingredientData['category'],
          'metric': ingredientData['metric'],
          'amount_per_item': ingredientData['amount_per_item'],
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _unitController.text = ingredientData['metric']!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_nameController.text} added to grocery database!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding ingredient to database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Map<String, dynamic>? getIngredientData() {
    if (_nameController.text.isEmpty) return null;
    
    return {
      'name': _nameController.text,
      'quantity': double.tryParse(_quantityController.text) ?? 1.0,
      'unit': _unitController.text.isEmpty ? 'Piece' : _unitController.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Ingredient *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _nameController.text.isNotEmpty && suggestions.isEmpty
                          ? IconButton(
                              icon: Icon(Icons.add, color: Colors.blue),
                              onPressed: _showNewIngredientDialog,
                              tooltip: 'Add to database',
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      // Trigger rebuild to show/hide add button
                      setState(() {});
                    },
                  ),
                  if (showSuggestions)
                    Container(
                      constraints: BoxConstraints(maxHeight: 150),
                      child: Card(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(suggestion['name']),
                              subtitle: Text('${suggestion['category']} • ${suggestion['metric']}'),
                              onTap: () => _selectSuggestion(suggestion),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _unitController,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: widget._canRemove ? widget._onRemove : null,
              icon: Icon(Icons.remove_circle, color: Colors.red),
            ),
          ],
        ),
      ],
    );
  }
}