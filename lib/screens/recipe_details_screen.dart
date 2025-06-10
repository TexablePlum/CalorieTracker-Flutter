import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../models/recipe.dart';
import '../mappers/product_mappers.dart';
import '../screens/add_recipe_screen.dart';

class RecipeDetailsScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailsScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isLoadingUser = true;
  Map<String, Map<String, dynamic>> _ingredientDetails = {};
  bool _isLoadingIngredients = true;
  bool _isActionInProgress = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadIngredientDetails();
  }

  /// Pobiera dane aktualnie zalogowanego użytkownika
  Future<void> _loadCurrentUser() async {
    try {
      final dio = context.read<Dio>();
      final response = await dio.get('/api/auth/me');
      
      if (!mounted) return;
      
      setState(() {
        _currentUser = Map<String, dynamic>.from(response.data);
        _isLoadingUser = false;
      });
      
    } catch (e) {
      debugPrint('❌ Error loading current user: $e');
      
      if (!mounted) return;
      
      setState(() {
        _currentUser = null;
        _isLoadingUser = false;
      });
    }
  }

  /// Pobiera szczegóły składników
  Future<void> _loadIngredientDetails() async {
    try {
      final dio = context.read<Dio>();
      
      for (final ingredient in widget.recipe.ingredients) {
        if (ingredient.productId.isNotEmpty) {
          try {
            final response = await dio.get('/api/Products/${ingredient.productId}');
            _ingredientDetails[ingredient.productId] = Map<String, dynamic>.from(response.data);
          } catch (e) {
            debugPrint('❌ Error loading ingredient ${ingredient.productId}: $e');
            // Kontynuuje z innymi składnikami nawet jeśli jeden się nie uda
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoadingIngredients = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading ingredient details: $e');
      if (mounted) {
        setState(() {
          _isLoadingIngredients = false;
        });
      }
    }
  }

  /// Sprawdza czy aktualny użytkownik jest autorem przepisu
  bool get _isCurrentUserAuthor {
    if (_currentUser == null) return false;
    return widget.recipe.isOwnedBy(_currentUser!['id']?.toString());
  }

  Map<String, double> _getTotalNutrition() {
    // Używa totalNutrition z Recipe jeśli dostępne
    if (widget.recipe.totalNutrition != null) {
      final nutrition = widget.recipe.totalNutrition!;
      return {
        'calories': ProductMappers.safeGetDouble(nutrition['calories']),
        'protein': ProductMappers.safeGetDouble(nutrition['protein']),
        'fat': ProductMappers.safeGetDouble(nutrition['fat']),
        'carbs': ProductMappers.safeGetDouble(nutrition['carbohydrates']),
        'fiber': ProductMappers.safeGetDouble(nutrition['fiber']),
        'sugar': ProductMappers.safeGetDouble(nutrition['sugar']),
        'sodium': ProductMappers.safeGetDouble(nutrition['sodium']),
      };
    }

    // oblicza lokalnie na podstawie składników jeśli są dostępne
    if (_ingredientDetails.isNotEmpty) {
      double totalCalories = 0;
      double totalProtein = 0;
      double totalFat = 0;
      double totalCarbs = 0;
      double totalFiber = 0;
      double totalSugar = 0;
      double totalSodium = 0;

      for (final ingredient in widget.recipe.ingredients) {
        final details = _ingredientDetails[ingredient.productId];
        if (details != null) {
          final quantity = ingredient.quantity;
          final factor = quantity / 100;
          
          totalCalories += ProductMappers.safeGetDouble(details['caloriesPer100g']) * factor;
          totalProtein += ProductMappers.safeGetDouble(details['proteinPer100g']) * factor;
          totalFat += ProductMappers.safeGetDouble(details['fatPer100g']) * factor;
          totalCarbs += ProductMappers.safeGetDouble(details['carbohydratesPer100g']) * factor;
          totalFiber += ProductMappers.safeGetDouble(details['fiberPer100g']) * factor;
          totalSugar += ProductMappers.safeGetDouble(details['sugarsPer100g']) * factor;
          totalSodium += ProductMappers.safeGetDouble(details['sodiumPer100g']) * factor;
        }
      }

      return {
        'calories': totalCalories,
        'protein': totalProtein,
        'fat': totalFat,
        'carbs': totalCarbs,
        'fiber': totalFiber,
        'sugar': totalSugar,
        'sodium': totalSodium,
      };
    }

    // Ultimate fallback - zwraca zera jeśli nic nie działa
    return {
      'calories': 0.0,
      'protein': 0.0,
      'fat': 0.0,
      'carbs': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'sodium': 0.0,
    };
  }

  /// Nawiguje do ekranu edycji przepisu
  Future<void> _editRecipe() async {
    setState(() => _isActionInProgress = true);
    
    try {
      final result = await Navigator.of(context).push<Recipe>(
        MaterialPageRoute(
          builder: (_) => AddRecipeScreen(recipeToEdit: widget.recipe),
        ),
      );

      // Jeśli otrzymano zaktualizowane dane przepisu odświeża ekran
      if (result != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(recipe: result),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }
  Future<void> _deleteRecipe() async {
    setState(() => _isActionInProgress = true);

    try {
      final dio = context.read<Dio>();
      
      await dio.delete('/api/Recipes/${widget.recipe.id}');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Przepis został usunięty'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop(); // Wraca do listy przepisów
      
    } on DioException catch (e) {
      if (!mounted) return;
      
      String errorMessage;
      switch (e.response?.statusCode) {
        case 403:
          errorMessage = 'Nie masz uprawnień do usunięcia tego przepisu';
          break;
        case 404:
          errorMessage = 'Przepis nie został znaleziony';
          break;
        default:
          errorMessage = 'Nie udało się usunąć przepisu. Spróbuj ponownie.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wystąpił nieoczekiwany błąd'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }
  /// Pokazuje dialog potwierdzenia usunięcia
  Future<void> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń przepis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Czy na pewno chcesz usunąć przepis "${widget.recipe.name}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ta akcja jest nieodwracalna!',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteRecipe();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // Opcje dla właściciela przepisu
          if (!_isLoadingUser && _isCurrentUserAuthor && !_isActionInProgress) ...[
            IconButton(
              onPressed: _editRecipe,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edytuj przepis',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmation();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Usuń przepis'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          // Loading indicator podczas akcji
          if (_isActionInProgress)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header przepisu
            _buildRecipeHeader(),
            
            const SizedBox(height: 16),

            // Składniki
            _buildIngredientsSection(),

            const SizedBox(height: 16),

            // Wartości odżywcze
            if (!_isLoadingIngredients) ...[
              _buildNutritionSection(),
              const SizedBox(height: 16),
            ],

            // Instrukcje
            if (widget.recipe.instructions != null && widget.recipe.instructions!.isNotEmpty)
              _buildInstructionsSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            // TODO: Implementacja dodawania do posiłku
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Funkcja dodawania do posiłku będzie wkrótce'),
                backgroundColor: Color(0xFFA69DF5),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Dodaj do posiłku'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA69DF5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.recipe.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Napis "Mój przepis" jeśli user jest autorem
                if (!_isLoadingUser && _isCurrentUserAuthor)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA69DF5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFA69DF5).withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Color(0xFFA69DF5),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Mój przepis',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA69DF5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  Icons.people,
                  '${widget.recipe.servingsCount} porcji',
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.timer,
                  widget.recipe.formattedPreparationTime,
                  Colors.green,
                ),
              ],
            ),
            if (widget.recipe.totalWeightGrams > 0) ...[
              const SizedBox(height: 8),
              _buildInfoChip(
                Icons.monitor_weight,
                '${widget.recipe.totalWeightGrams.round()}g całkowita waga',
                Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SKŁADNIKI',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFA69DF5),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...widget.recipe.ingredients.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ingredient = entry.value;
                  final details = _ingredientDetails[ingredient.productId];
                  
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 20),
                      _buildIngredientRow(ingredient, details),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(RecipeIngredient ingredient, Map<String, dynamic>? details) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ilość
        SizedBox(
          width: 80,
          child: Text(
            ingredient.formattedQuantity,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFA69DF5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Nazwa produktu
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ingredient.productName ?? 'Nieznany produkt',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (details != null) ...[
                const SizedBox(height: 4),
                Text(
                  _getIngredientNutritionInfo(ingredient, details),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Loading indicator dla składnika
        if (_isLoadingIngredients && details == null)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  String _getIngredientNutritionInfo(RecipeIngredient ingredient, Map<String, dynamic> details) {
    final quantity = ingredient.quantity;
    final factor = quantity / 100; // API podaje wartości na 100g
    
    final calories = ProductMappers.safeGetDouble(details['caloriesPer100g']) * factor;
    final protein = ProductMappers.safeGetDouble(details['proteinPer100g']) * factor;
    
    return '${calories.round()} kcal, ${protein.toStringAsFixed(1)}g białka';
  }

  Widget _buildNutritionSection() {
    final nutrition = _getTotalNutrition();
    final servings = widget.recipe.servingsCount;
    final hasDetailedNutrition = nutrition['fiber']! > 0 || nutrition['sugar']! > 0 || nutrition['sodium']! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WARTOŚCI ODŻYWCZE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFA69DF5),
          ),
        ),
        const SizedBox(height: 8),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Całkowite wartości
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA69DF5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CAŁY PRZEPIS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${nutrition['calories']!.round()} kcal',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA69DF5),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Makroskładniki całkowite
                _buildNutritionRow('Białko', nutrition['protein']!, 'g'),
                const Divider(height: 20),
                _buildNutritionRow('Tłuszcze', nutrition['fat']!, 'g'),
                const Divider(height: 20),
                _buildNutritionRow('Węglowodany', nutrition['carbs']!, 'g'),
                
                // Dodatkowe składniki (jeśli dostępne)
                if (hasDetailedNutrition) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'SZCZEGÓŁOWE WARTOŚCI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (nutrition['fiber']! > 0) ...[
                    _buildNutritionRow('Błonnik', nutrition['fiber']!, 'g'),
                    const Divider(height: 20),
                  ],
                  if (nutrition['sugar']! > 0) ...[
                    _buildNutritionRow('Cukry', nutrition['sugar']!, 'g'),
                    const Divider(height: 20),
                  ],
                  if (nutrition['sodium']! > 0)
                    _buildNutritionRow('Sód', nutrition['sodium']!, 'mg'),
                ],
                
                const SizedBox(height: 16),
                
                // Na porcję
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'NA PORCJĘ (${servings} porcji)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(nutrition['calories']! / servings).round()} kcal',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Białko: ${(nutrition['protein']! / servings).toStringAsFixed(1)}g | '
                        'Tłuszcze: ${(nutrition['fat']! / servings).toStringAsFixed(1)}g | '
                        'Węglowodany: ${(nutrition['carbs']! / servings).toStringAsFixed(1)}g',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionRow(String label, double value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          '${value.toStringAsFixed(1)} $unit',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INSTRUKCJE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFA69DF5),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.recipe.instructions!,
              style: const TextStyle(
                height: 1.5,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}