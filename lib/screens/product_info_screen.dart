import 'package:calorie_tracker_flutter_front/mappers/product_mappers.dart';
import 'package:flutter/material.dart';
// import 'package:your_app/utils/product_mappers.dart';

/// Reużywalny ekran wyświetlający informacje o produkcie
/// 
/// Użycie:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ProductInfoScreen(product: productData),
///   ),
/// );
class ProductInfoScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final Widget? bottomWidget; // Opcjonalny widget na dole
  final String? customTitle; // Opcjonalny custom tytuł

  const ProductInfoScreen({
    super.key,
    required this.product,
    this.bottomWidget,
    this.customTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customTitle ?? 'Informacje o produkcie'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header produktu
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'Nieznana nazwa',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (product['brand'] != null && product['brand'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product['brand'],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          product['barcode'] ?? '',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (product['category'] != null && product['category'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            ProductMappers.mapCategory(product['category']),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Wartości odżywcze - główne
            const Text(
              'WARTOŚCI ODŻYWCZE (na 100g)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA69DF5),
              ),
            ),
            const SizedBox(height: 8),
            
            // Kalorie - wyróżnione
            Card(
              color: const Color(0xFFA69DF5).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kalorie',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ProductMappers.formatNutritionValue(product['caloriesPer100g'], 'kcal'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA69DF5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Makroskładniki
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildNutritionRow('Białko', product['proteinPer100g'], 'g'),
                    const Divider(height: 20),
                    _buildNutritionRow('Tłuszcze', product['fatPer100g'], 'g'),
                    const Divider(height: 20),
                    _buildNutritionRow('Węglowodany', product['carbohydratesPer100g'], 'g'),
                  ],
                ),
              ),
            ),

            // Szczegółowe wartości odżywcze (jeśli jakiekolwiek są dostępne w produkcie)
            if (_hasAnyDetailedNutrition()) ...[
              const SizedBox(height: 16),
              const Text(
                'SZCZEGÓŁOWE WARTOŚCI',
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
                      if (_hasField('fiberPer100g'))
                        _buildNutritionRow('Błonnik', product['fiberPer100g'], 'g'),
                      if (_hasField('sugarsPer100g')) ...[
                        if (_hasField('fiberPer100g'))
                          const Divider(height: 20),
                        _buildNutritionRow('Cukry', product['sugarsPer100g'], 'g'),
                      ],
                      if (_hasField('sodiumPer100g')) ...[
                        if (_hasField('fiberPer100g') || _hasField('sugarsPer100g'))
                          const Divider(height: 20),
                        _buildNutritionRow('Sód', product['sodiumPer100g'], 'mg'),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Informacje dodatkowe
            if (ProductMappers.safeGetDouble(product['servingSize']) > 0) ...[
              const SizedBox(height: 16),
              const Text(
                'INFORMACJE DODATKOWE',
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
                  child: _buildInfoRow(
                    'Wielkość porcji', 
                    ProductMappers.formatNutritionValue(
                      product['servingSize'], 
                      ProductMappers.mapUnit(product['unit'])
                    )
                  ),
                ),
              ),
            ],

            // Opis
            if (product['description'] != null && product['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'OPIS',
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
                    product['description'],
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
            ],

            // Składniki
            if (product['ingredients'] != null && product['ingredients'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
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
                  child: Text(
                    product['ingredients'],
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: bottomWidget, // Opcjonalny widget na dole
    );
  }

  // Sprawdza czy pole istnieje w produkcie (niezależnie od wartości)
  bool _hasField(String fieldName) {
    return product.containsKey(fieldName) && product[fieldName] != null;
  }

  // Sprawdza czy jakiekolwiek szczegółowe wartości są dostępne
  bool _hasAnyDetailedNutrition() {
    return _hasField('fiberPer100g') || 
           _hasField('sugarsPer100g') || 
           _hasField('sodiumPer100g');
  }

  Widget _buildNutritionRow(String label, dynamic value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          ProductMappers.formatNutritionValue(value, unit),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}