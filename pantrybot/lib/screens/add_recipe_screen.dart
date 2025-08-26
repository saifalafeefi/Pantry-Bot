import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

class AddRecipeScreen extends StatefulWidget {
  final int userId;

  const AddRecipeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _AddRecipeScreenState createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final String baseUrl = 'https://pantrybot.anonstorage.org:8443';

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();

  // Dynamic lists
  List<Map<String, TextEditingController>> ingredients = [];
  List<TextEditingController> steps = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _addIngredient();
    _addStep();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    
    for (var ingredient in ingredients) {
      ingredient['name']?.dispose();
      ingredient['quantity']?.dispose();
      ingredient['unit']?.dispose();
    }
    
    for (var step in steps) {
      step.dispose();
    }
    
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      ingredients.add({
        'name': TextEditingController(),
        'quantity': TextEditingController(),
        'unit': TextEditingController(),
      });
    });
  }

  void _removeIngredient(int index) {
    if (ingredients.length > 1) {
      setState(() {
        ingredients[index]['name']?.dispose();
        ingredients[index]['quantity']?.dispose();
        ingredients[index]['unit']?.dispose();
        ingredients.removeAt(index);
      });
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
      // Prepare recipe data
      final recipeData = {
        'user_id': widget.userId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'prep_time': int.tryParse(_prepTimeController.text) ?? 0,
        'cook_time': int.tryParse(_cookTimeController.text) ?? 0,
        'servings': int.tryParse(_servingsController.text) ?? 1,
        'ingredients': ingredients
            .where((ingredient) => ingredient['name']!.text.isNotEmpty)
            .map((ingredient) => {
                  'name': ingredient['name']!.text,
                  'quantity': double.tryParse(ingredient['quantity']!.text) ?? 1.0,
                  'unit': ingredient['unit']!.text,
                })
            .toList(),
        'steps': steps
            .where((step) => step.text.isNotEmpty)
            .map((step) => step.text)
            .toList(),
      };

      // Create HTTP client with SSL bypass
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(client);

      final response = await ioClient.post(
        Uri.parse('$baseUrl/recipes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(recipeData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to save recipe: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving recipe: $e'),
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
        title: Text('Add Recipe'),
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

              ...ingredients.asMap().entries.map((entry) {
                final index = entry.key;
                final ingredient = entry.value;
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: ingredient['name'],
                              decoration: InputDecoration(
                                labelText: 'Ingredient',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: index == 0
                                  ? (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: ingredient['quantity'],
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
                              controller: ingredient['unit'],
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: ingredients.length > 1 ? () => _removeIngredient(index) : null,
                            icon: Icon(Icons.remove_circle, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                            Text('Saving Recipe...'),
                          ],
                        )
                      : Text(
                          'Save Recipe',
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