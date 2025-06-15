import 'package:calorie_tracker_flutter_front/mappers/product_mappers.dart';
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
        category: ingredient.category,
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

    // Dodatkowa walidacja składników
    if (_ingredients.isEmpty) {
      setState(() {
        _errorMessage = 'Składniki są wymagane - dodaj przynajmniej jeden składnik';
      });
      return;
    }

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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFA69DF5),
            Color(0xFF8B7CF6),
            Color(0xFF7C3AED),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA69DF5).withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Text(
                  _isEditMode ? "Edytuj przepis" : "Dodaj przepis",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA69DF5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFFA69DF5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (required)
              const Text(
                " *",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFA69DF5), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientCard(int index) {
    final ingredient = _ingredients[index];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFA69DF5).withOpacity(0.2),
                  const Color(0xFF8B7CF6).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFA69DF5).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              ProductMappers.getCategoryIcon(ingredient.category),
              color: const Color(0xFFA69DF5),
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ProductMappers.mapCategory(ingredient.category), // Pokazuje nazwę kategorii
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Input dla ilości
          Container(
            width: 90,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: ingredient.quantity,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: (value) => _updateIngredientQuantity(index, value),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'g',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Przycisk usuwania
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 16),
              onPressed: () => _removeIngredient(index),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    
                    // Podstawowe informacje
                    _buildSection(
                      'Podstawowe informacje',
                      Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Nazwa przepisu',
                            hint: 'np. Spaghetti Bolognese',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nazwa przepisu jest wymagana';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _servingsController,
                                  label: 'Liczba porcji',
                                  hint: '4',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (value) {
                                    final parsed = int.tryParse(value ?? '');
                                    if (parsed == null || parsed <= 0) {
                                      return 'Podaj liczbę porcji (1-50)';
                                    }
                                    if (parsed > 50) {
                                      return 'Maksymalnie 50 porcji';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _timeController,
                                  label: 'Czas (min)',
                                  hint: 'np. 30',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (value) {
                                    final parsed = int.tryParse(value ?? '');
                                    if (parsed == null || parsed <= 0) {
                                      return 'Podaj czas przygotowania';
                                    }
                                    if (parsed > 1440) {
                                      return 'Maksymalnie 1440 min (24h)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _weightController,
                            label: 'Waga całkowita (g)',
                            hint: 'np. 500',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            validator: (value) {
                              final parsed = double.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Podaj wagę całkowitą gotowej potrawy';
                              }
                              if (parsed > 50000) {
                                return 'Maksymalnie 50000g (50kg)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      icon: Icons.info_outline,
                    ),

                    // Składniki
                    _buildSection(
                      'Składniki (${_ingredients.length})',
                      Column(
                        children: [
                          if (_ingredients.isNotEmpty)
                            ...List.generate(_ingredients.length, (index) {
                              return _buildIngredientCard(index);
                            }),
                          
                          // Przycisk dodaj składnik
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addIngredient,
                              icon: const Icon(Icons.add),
                              label: const Text('Dodaj składnik'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFA69DF5),
                                side: const BorderSide(color: Color(0xFFA69DF5)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          
                          // Komunikat o składnikach
                          if (_ingredients.isEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700]),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Dodaj przynajmniej jeden składnik aby utworzyć przepis',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      icon: Icons.restaurant,
                    ),

                    // Instrukcje przygotowania
                    _buildSection(
                      'Instrukcje przygotowania',
                      _buildTextField(
                        controller: _instructionsController,
                        label: 'Sposób przygotowania',
                        hint: 'Opisz krok po kroku jak przygotować potrawę...',
                        keyboardType: TextInputType.multiline,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Instrukcje przygotowania są wymagane';
                          }
                          return null;
                        },
                      ),
                      icon: Icons.list_alt,
                    ),

                    // Błędy
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 12),
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
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveRecipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA69DF5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: const Color(0xFFA69DF5).withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isEditMode ? 'Zaktualizuj przepis' : 'Zapisz przepis',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32), // Przestrzeń na dole
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}