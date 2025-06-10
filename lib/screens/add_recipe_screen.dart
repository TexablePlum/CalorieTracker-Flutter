import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../models/recipe.dart';
import '../models/recipe_form.dart';
import '../services/recipe_service.dart';
import '../screens/product_search_screen.dart';

class AddRecipeScreen extends StatefulWidget {
  final Recipe? recipeToEdit; // Opcjonalny do edycji

  const AddRecipeScreen({
    super.key,
    this.recipeToEdit,
  });

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late RecipeService _recipeService;
  
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final _weightController = TextEditingController();
  final _timeController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  final List<RecipeIngredientForm> _ingredients = [];

  /// Sprawdza czy tryb edycji
  bool get _isEditMode => widget.recipeToEdit != null;

  @override
  void initState() {
    super.initState();
    _recipeService = RecipeService(context.read<Dio>());
    
    // Wypełnia formularz jeśli to edycja
    if (_isEditMode) {
      _populateFormFromRecipe();
    }
  }

  /// Wypełnia formularz danymi z istniejącego przepisu
  void _populateFormFromRecipe() {
    final recipe = widget.recipeToEdit!;
    
    _nameController.text = recipe.name;
    _instructionsController.text = recipe.instructions ?? '';
    _servingsController.text = recipe.servingsCount.toString();
    _weightController.text = recipe.totalWeightGrams.toString();
    _timeController.text = recipe.preparationTimeMinutes.toString();
    
    // Konwertuje składniki na formularzowe
    for (final ingredient in recipe.ingredients) {
      _ingredients.add(RecipeIngredientForm(
        productId: ingredient.productId,
        productName: ingredient.productName ?? 'Nieznany produkt',
        quantity: ingredient.quantity.toString(),
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _servingsController.dispose();
    _weightController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final ingredient = await Navigator.push<RecipeIngredientForm>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductSearchScreen(),
      ),
    );

    if (ingredient != null) {
      setState(() {
        _ingredients.add(ingredient);
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _updateIngredientQuantity(int index, String quantity) {
    setState(() {
      _ingredients[index].quantity = quantity;
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final formData = RecipeFormData(
        name: _nameController.text.trim(),
        instructions: _instructionsController.text.trim(),
        servingsCount: int.tryParse(_servingsController.text) ?? 1,
        totalWeightGrams: double.tryParse(_weightController.text) ?? 0.0,
        preparationTimeMinutes: int.tryParse(_timeController.text) ?? 0,
        ingredients: _ingredients,
      );

      Recipe result;
      
      if (_isEditMode) {
        // Aktualizuje istniejący przepis
        final dio = context.read<Dio>();
        await dio.put(
          '/api/Recipes/${widget.recipeToEdit!.id}',
          data: formData.toJson(),
        );
        
        // Pobiera zaktualizowane dane
        result = await _recipeService.getRecipeById(widget.recipeToEdit!.id);
      } else {
        // Tworzy nowy przepis
        result = await _recipeService.createRecipe(formData);
      }
      
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } on DioException catch (e) {
      if (mounted) {
        String errorMessage;
        switch (e.response?.statusCode) {
          case 400:
          case 422:
            errorMessage = _extractErrorMessage(e.response?.data) ?? 'Nieprawidłowe dane przepisu';
            break;
          case 403:
            errorMessage = _isEditMode 
                ? 'Nie masz uprawnień do edycji tego przepisu'
                : 'Nie masz uprawnień do tworzenia przepisów';
            break;
          case 404:
            errorMessage = 'Przepis nie został znaleziony';
            break;
          default:
            errorMessage = _isEditMode 
                ? 'Nie udało się zaktualizować przepisu'
                : 'Nie udało się utworzyć przepisu';
        }
        
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _isEditMode 
              ? 'Błąd aktualizacji przepisu: $e'
              : 'Błąd tworzenia przepisu: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Wyciąga komunikaty błędów z odpowiedzi API
  String? _extractErrorMessage(dynamic data) {
    try {
      if (data is Map && data['errors'] != null) {
        final errors = (data['errors'] as Map<String, dynamic>)
            .values
            .expand((e) => e is List ? e : [e])
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join('\n');
        return errors.isNotEmpty ? errors : null;
      }
      
      if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
    } catch (e) {
      debugPrint('Error extracting error message: $e');
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edytuj przepis' : 'Dodaj przepis'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveRecipe,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEditMode ? 'Zapisz' : 'Dodaj',
                    style: const TextStyle(
                      color: Color(0xFFA69DF5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nazwa przepisu
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa przepisu *',
                  hintText: 'np. Spaghetti Bolognese',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nazwa przepisu jest wymagana';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Liczba porcji i waga
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servingsController,
                      decoration: const InputDecoration(
                        labelText: 'Liczba porcji *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Podaj liczbę porcji';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Waga (g)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Czas przygotowania
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Czas przygotowania (minuty)',
                  hintText: 'np. 30',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              
              const SizedBox(height: 16),
              
              // Instrukcje
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instrukcje przygotowania',
                  hintText: 'Opisz krok po kroku jak przygotować przepis...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              
              const SizedBox(height: 24),
              
              // Składniki
              const Text(
                'Składniki *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              // Lista składników
              if (_ingredients.isNotEmpty)
                ...List.generate(_ingredients.length, (index) {
                  final ingredient = _ingredients[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            ingredient.productName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: ingredient.quantity,
                            decoration: const InputDecoration(
                              suffix: Text('g'),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            onChanged: (value) => _updateIngredientQuantity(index, value),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeIngredient(index),
                        ),
                      ],
                    ),
                  );
                }),
              
              // Przycisk dodaj składnik
              OutlinedButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Dodaj składnik'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA69DF5),
                  side: const BorderSide(color: Color(0xFFA69DF5)),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Komunikat o składnikach
              if (_ingredients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Dodaj przynajmniej jeden składnik',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Błąd
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Przycisk zapisz
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA69DF5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          _isEditMode ? 'Zaktualizuj przepis' : 'Zapisz przepis',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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