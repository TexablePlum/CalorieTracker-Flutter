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
  bool _usePortions = false;

  @override
  void initState() {
    super.initState();
    _initializeQuantity();
  }

  void _initializeQuantity() {
    final servingSize = ProductMappers.safeGetDouble(widget.product['servingSize']);
    if (servingSize > 0) {
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
      _showErrorFeedback('Ilość musi być większa od 0');
      return;
    }

    final quantityInGrams = _usePortions 
        ? _currentQuantity * ProductMappers.safeGetDouble(widget.product['servingSize'])
        : _currentQuantity;

    final ingredient = RecipeIngredientForm(
      productId: widget.product['id'] ?? '',
      productName: widget.product['name'] ?? '',
      quantity: quantityInGrams.toString(),
      category: widget.product['category'],
    );

    Navigator.of(context).pop(ingredient);
  }

  void _showErrorFeedback(String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  double _calculateNutrition(dynamic per100Value) {
    if (per100Value == null) return 0.0;
    final per100 = ProductMappers.safeGetDouble(per100Value);
    
    final actualGrams = _usePortions 
        ? _currentQuantity * ProductMappers.safeGetDouble(widget.product['servingSize'])
        : _currentQuantity;
    
    return (per100 * actualGrams) / 100;
  }

  String _getCurrentUnit() {
    if (_usePortions) {
      return _currentQuantity == 1 ? 'porcja' : 'porcji';
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

  // Zwraca nazwę dla jednostki (nie porcji)
  String _getBaseUnitName() {
    final unit = ProductMappers.mapUnit(widget.product['unit']);
    switch (unit) {
      case 'g':
        return 'Gramy';
      case 'ml':
        return 'Mililitry';
      case 'szt.':
        return 'Sztuki';
      default:
        return unit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProductCard(),
                  const SizedBox(height: 24),
                  _buildQuantitySection(),
                  const SizedBox(height: 24),
                  _buildNutritionCard(),
                  const SizedBox(height: 32),
                  _buildAddButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              const Expanded(
                child: Text(
                  "Dodaj składnik",
                  style: TextStyle(
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

  Widget _buildProductCard() {
    final productName = widget.product['name'] ?? 'Nieznany produkt';
    final brand = widget.product['brand'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFA69DF5).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ikona produktu z efektem świecenia
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFA69DF5).withOpacity(0.2),
                  const Color(0xFF8B7CF6).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFA69DF5).withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA69DF5).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              ProductMappers.getCategoryIcon(widget.product['category']),
              color: const Color(0xFFA69DF5),
              size: 36,
            ),
          ),
          
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                if (brand != null && brand.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    brand.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    ProductMappers.mapCategory(widget.product['category']),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.withOpacity(0.2),
                      Colors.orange.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.straighten,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Ustaw ilość',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          
          if (_hasServingSize()) ...[
            const SizedBox(height: 24),
            _buildUnitToggle(),
          ],
          
          const SizedBox(height: 24),
          _buildQuantityInput(),
          
          if (_usePortions && _hasServingSize()) ...[
            const SizedBox(height: 16),
            _buildPortionInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              'Porcje',
              _usePortions,
              () => setState(() {
                _usePortions = true;
                _quantityController.text = '1';
                _currentQuantity = 1.0;
              }),
            ),
          ),
          // Jednostka podstawowa (gramy/ml/szt)
          Expanded(
            child: _buildToggleButton(
              _getBaseUnitName(), // Dynamiczna nazwa jednostki
              !_usePortions,
              () => setState(() {
                _usePortions = false;
                _quantityController.text = '100';
                _currentQuantity = 100.0;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA69DF5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFA69DF5).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Ilość',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                suffixText: _getCurrentUnit(),
                suffixStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA69DF5),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
              onChanged: _updateQuantity,
            ),
          ),
        ),
        
        const SizedBox(width: 20),
        
        Column(
          children: _usePortions
              ? [
                  _buildQuickButton('0.5', 0.5),
                  const SizedBox(height: 12),
                  _buildQuickButton('1', 1),
                  const SizedBox(height: 12),
                  _buildQuickButton('2', 2),
                ]
              : [
                  _buildQuickButton('50', 50),
                  const SizedBox(height: 12),
                  _buildQuickButton('100', 100),
                  const SizedBox(height: 12),
                  _buildQuickButton('200', 200),
                ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(String label, double value) {
    final isSelected = _currentQuantity == value;
    
    return Container(
      width: 70,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _quantityController.text = value.toString();
            _updateQuantity(value.toString());
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: isSelected 
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFA69DF5),
                        Color(0xFF8B7CF6),
                      ],
                    )
                  : null,
              color: isSelected ? null : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFFA69DF5) 
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'To jest ${_getDisplayQuantity()}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard() {
    final nutrition = _calculateNutrition(widget.product['caloriesPer100g']);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.2),
                      Colors.green.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_dining,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wartości odżywcze',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'dla ${_getDisplayQuantity()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Kalorie
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFA69DF5).withOpacity(0.1),
                  const Color(0xFF8B7CF6).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFA69DF5).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kalorie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${nutrition.round()} kcal',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA69DF5),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Makro
          _buildNutritionRow(
            'Białko',
            _calculateNutrition(widget.product['proteinPer100g']),
            'g',
            Colors.red,
            Icons.fitness_center,
          ),
          const SizedBox(height: 16),
          _buildNutritionRow(
            'Tłuszcze',
            _calculateNutrition(widget.product['fatPer100g']),
            'g',
            Colors.yellow[700]!,
            Icons.water_drop,
          ),
          const SizedBox(height: 16),
          _buildNutritionRow(
            'Węglowodany',
            _calculateNutrition(widget.product['carbohydratesPer100g']),
            'g',
            Colors.green,
            Icons.grass,
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String name, double value, String unit, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            ProductMappers.formatNutritionValue(value, unit),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      width: double.infinity,
      height: 64,
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA69DF5).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveIngredient,
          borderRadius: BorderRadius.circular(20),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Dodaj składnik',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}