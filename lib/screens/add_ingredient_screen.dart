import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../mappers/product_mappers.dart';
import '../models/recipe_form.dart';

class AddIngredientScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const AddIngredientScreen({
    super.key,
    required this.product,
  });

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final _quantityController = TextEditingController(text: '100');
  double _currentQuantity = 100.0;
  bool _usePortions = false; // false = gramy, true = porcje

  @override
  void initState() {
    super.initState();
    // Sprawdza czy produkt ma zdefiniowaną wielkość porcji
    final servingSize = ProductMappers.safeGetDouble(widget.product['servingSize']);
    if (servingSize > 0) {
      // Jeśli ma porcję ustawia domyślnie 1 porcję
      _usePortions = true;
      _quantityController.text = '1';
      _currentQuantity = 1.0;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(String value) {
    final parsed = double.tryParse(value);
    setState(() {
      _currentQuantity = parsed ?? 0.0;
    });
  }

  void _saveIngredient() {
    if (_currentQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ilość musi być większa od 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Przelicza na gramy jeśli używa porcji
    final quantityInGrams = _usePortions 
        ? _currentQuantity * ProductMappers.safeGetDouble(widget.product['servingSize'])
        : _currentQuantity;

    final ingredient = RecipeIngredientForm(
      productId: widget.product['id'] ?? '',
      productName: widget.product['name'] ?? '',
      quantity: quantityInGrams.toString(),
    );

    Navigator.of(context).pop(ingredient);
  }

  // Oblicza wartości odżywcze na podstawie ilości
  double _calculateNutrition(dynamic per100Value) {
    if (per100Value == null) return 0.0;
    final per100 = ProductMappers.safeGetDouble(per100Value);
    
    // Przelicz wartość na podstawie aktualnej ilości
    final actualGrams = _usePortions 
        ? _currentQuantity * ProductMappers.safeGetDouble(widget.product['servingSize'])
        : _currentQuantity;
    
    return (per100 * actualGrams) / 100;
  }

  String _getCurrentUnit() {
    if (_usePortions) {
      final servingSize = ProductMappers.safeGetDouble(widget.product['servingSize']);
      ProductMappers.mapUnit(widget.product['unit']);
      return servingSize > 1 ? 'porcji' : 'porcja';
    }
    return ProductMappers.mapUnit(widget.product['unit']);
  }

  String _getDisplayQuantity() {
    if (_usePortions) {
      final servingSize = ProductMappers.safeGetDouble(widget.product['servingSize']);
      final baseUnit = ProductMappers.mapUnit(widget.product['unit']);
      final totalGrams = _currentQuantity * servingSize;
      return '${ProductMappers.formatNutritionValue(_currentQuantity, _getCurrentUnit())} (${ProductMappers.formatNutritionValue(totalGrams, baseUnit)})';
    }
    return ProductMappers.formatNutritionValue(_currentQuantity, _getCurrentUnit());
  }

  bool _hasServingSize() {
    return ProductMappers.safeGetDouble(widget.product['servingSize']) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['name'] ?? 'Nieznany produkt';
    final brand = widget.product['brand'];
    final hasServings = _hasServingSize();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodaj składnik'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: _saveIngredient,
            child: const Text(
              'Dodaj',
              style: TextStyle(
                color: Color(0xFFA69DF5),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header produktu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (brand != null && brand.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      brand.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Kategoria: ${ProductMappers.mapCategory(widget.product['category'])}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Ustawienie ilości
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ilość',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  
                  // Przełącznik gram/porcje (tylko jeśli produkt ma porcje)
                  if (hasServings) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(ProductMappers.mapUnit(widget.product['unit'])),
                          ),
                          ButtonSegment(
                            value: true,
                            label: const Text('Porcje'),
                          ),
                        ],
                        selected: {_usePortions},
                        onSelectionChanged: (value) {
                          setState(() {
                            _usePortions = value.first;
                            // Resetuj ilość przy zmianie jednostki
                            if (_usePortions) {
                              _quantityController.text = '1';
                              _currentQuantity = 1.0;
                            } else {
                              _quantityController.text = '100';
                              _currentQuantity = 100.0;
                            }
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) 
                                ? const Color(0xFFA69DF5) 
                                : Colors.grey[100],
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) 
                                ? Colors.white 
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Ilość',
                            suffix: Text(
                              _getCurrentUnit(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA69DF5),
                              ),
                            ),
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFA69DF5), width: 2),
                            ),
                          ),
                          onChanged: _updateQuantity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Szybkie przyciski, dostosowane do jednostki
                      Column(
                        children: _usePortions
                            ? [
                                _buildQuickButton('0.5', 0.5),
                                const SizedBox(height: 8),
                                _buildQuickButton('1', 1),
                                const SizedBox(height: 8),
                                _buildQuickButton('2', 2),
                              ]
                            : [
                                _buildQuickButton('50', 50),
                                const SizedBox(height: 8),
                                _buildQuickButton('100', 100),
                                const SizedBox(height: 8),
                                _buildQuickButton('200', 200),
                              ],
                      ),
                    ],
                  ),
                  
                  // Podsumowanie - pokazuje przeliczenie jeśli używa porcji
                  if (_usePortions && hasServings) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'To jest ${_getDisplayQuantity()}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Wartości odżywcze
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wartości odżywcze (${_getDisplayQuantity()})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kalorie 
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA69DF5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFA69DF5).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kalorie',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ProductMappers.formatNutritionValue(
                            _calculateNutrition(widget.product['caloriesPer100g']),
                            'kcal',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA69DF5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Makroskładniki
                  _buildNutritionRow(
                    'Białko',
                    _calculateNutrition(widget.product['proteinPer100g']),
                    'g',
                    Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildNutritionRow(
                    'Tłuszcze',
                    _calculateNutrition(widget.product['fatPer100g']),
                    'g',
                    Colors.yellow[700]!,
                  ),
                  const SizedBox(height: 12),
                  _buildNutritionRow(
                    'Węglowodany',
                    _calculateNutrition(widget.product['carbohydratesPer100g']),
                    'g',
                    Colors.green,
                  ),

                  // Dodatkowe składniki (jeśli dostępne)
                  if (widget.product['fiberPer100g'] != null ||
                      widget.product['sugarsPer100g'] != null ||
                      widget.product['sodiumPer100g'] != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    if (widget.product['fiberPer100g'] != null) ...[
                      _buildNutritionRow(
                        'Błonnik',
                        _calculateNutrition(widget.product['fiberPer100g']),
                        'g',
                        Colors.brown,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    if (widget.product['sugarsPer100g'] != null) ...[
                      _buildNutritionRow(
                        'Cukry',
                        _calculateNutrition(widget.product['sugarsPer100g']),
                        'g',
                        Colors.pink,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    if (widget.product['sodiumPer100g'] != null)
                      _buildNutritionRow(
                        'Sód',
                        _calculateNutrition(widget.product['sodiumPer100g']),
                        'mg',
                        Colors.orange,
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Przycisk dodaj
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveIngredient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA69DF5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Dodaj składnik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, double value) {
    return SizedBox(
      width: 60,
      height: 36,
      child: OutlinedButton(
        onPressed: () {
          _quantityController.text = value.toString();
          _updateQuantity(value.toString());
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFA69DF5),
          side: const BorderSide(color: Color(0xFFA69DF5)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String name, double value, String unit, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          ProductMappers.formatNutritionValue(value, unit),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}