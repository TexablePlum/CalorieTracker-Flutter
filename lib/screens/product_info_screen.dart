import 'package:calorie_tracker_flutter_front/mappers/product_mappers.dart';
import 'package:calorie_tracker_flutter_front/screens/add_product_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

/// Prosty ekran wyświetlający informacje o produkcie
/// 
/// Jedynym celem tego ekranu jest pokazanie danych produktu.
/// Funkcjonalności edycji/usuwania są dostępne tylko dla produktów utworzonych przez użytkownika.
class ProductInfoScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final Widget? bottomWidget; // Opcjonalny widget na dole

  const ProductInfoScreen({
    super.key,
    required this.product,
    this.bottomWidget,
  });

  @override
  State<ProductInfoScreen> createState() => _ProductInfoScreenState();
}

class _ProductInfoScreenState extends State<ProductInfoScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isLoadingUser = true;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
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

  /// Sprawdza czy aktualny użytkownik jest autorem produktu
  bool get _isCurrentUserAuthor {
    if (_currentUser == null) return false;
    
    final currentUserId = _currentUser!['id']?.toString();
    final productAuthorId = (widget.product['createdBy'] ?? widget.product['createdByUserId'])?.toString();
    
    return currentUserId != null && 
           productAuthorId != null && 
           currentUserId == productAuthorId;
  }

  /// Nawiguje do ekranu edycji produktu
  Future<void> _editProduct() async {
    setState(() => _isActionInProgress = true);
    
    try {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => AddProductScreen(productToEdit: widget.product),
        ),
      );

      // Jeśli dostaliśmy zaktualizowane dane produktu odświeża ekran
      if (result != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProductInfoScreen(
              product: result,
              bottomWidget: widget.bottomWidget,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  /// Usuwa produkt po potwierdzeniu
  Future<void> _deleteProduct() async {
    final shouldDelete = await _showDeleteConfirmation();
    if (!shouldDelete) return;

    setState(() => _isActionInProgress = true);

    try {
      final dio = context.read<Dio>();
      final productId = widget.product['id'];
      
      if (productId == null) {
        throw Exception('Brak ID produktu');
      }

      await dio.delete('/api/Products/$productId');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produkt został usunięty'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop(); // Wraca do poprzedniego ekranu
      
    } on DioException catch (e) {
      if (!mounted) return;
      
      String errorMessage;
      switch (e.response?.statusCode) {
        case 403:
          errorMessage = 'Nie masz uprawnień do usunięcia tego produktu';
          break;
        case 404:
          errorMessage = 'Produkt nie został znaleziony';
          break;
        default:
          errorMessage = 'Nie udało się usunąć produktu. Spróbuj ponownie.';
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
  Future<bool> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń produkt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Czy na pewno chcesz usunąć ten produkt?'),
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

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informacje o produkcie'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // Pokazuje przyciski tylko jeśli użytkownik jest autorem i nie trwa akcja
          if (!_isLoadingUser && _isCurrentUserAuthor && !_isActionInProgress) ...[
            IconButton(
              onPressed: _editProduct,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edytuj produkt',
            ),
            IconButton(
              onPressed: _deleteProduct,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Usuń produkt',
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
            // Header produktu
            _buildProductHeader(),
            
            const SizedBox(height: 16),

            // Wartości odżywcze - główne
            _buildMainNutritionSection(),

            // Szczegółowe wartości odżywcze
            if (_hasAnyDetailedNutrition()) ...[
              const SizedBox(height: 16),
              _buildDetailedNutritionSection(),
            ],

            // Informacje dodatkowe
            if (_hasServingSize()) ...[
              const SizedBox(height: 16),
              _buildAdditionalInfoSection(),
            ],

            // Opis
            if (_hasDescription()) ...[
              const SizedBox(height: 16),
              _buildDescriptionSection(),
            ],

            // Składniki
            if (_hasIngredients()) ...[
              const SizedBox(height: 16),
              _buildIngredientsSection(),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomWidget,
    );
  }

  Widget _buildProductHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product['name'] ?? 'Nieznana nazwa',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.product['brand'] != null && 
                          widget.product['brand'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.product['brand'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // "Mój produkt" jeśli user jest autorem
                if (!_isLoadingUser && _isCurrentUserAuthor)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA69DF5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFA69DF5).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person,
                          size: 14,
                          color: Color(0xFFA69DF5),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Mój produkt',
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
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  widget.product['barcode'] ?? 'Brak kodu',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (widget.product['category'] != null && 
                widget.product['category'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    ProductMappers.mapCategory(widget.product['category']),
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
    );
  }

  Widget _buildMainNutritionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WARTOŚCI ODŻYWCZE (na 100g)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFA69DF5),
          ),
        ),
        const SizedBox(height: 8),
        
        // Kalorie
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
                  ProductMappers.formatNutritionValue(widget.product['caloriesPer100g'], 'kcal'),
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
                _buildNutritionRow('Białko', widget.product['proteinPer100g'], 'g'),
                const Divider(height: 20),
                _buildNutritionRow('Tłuszcze', widget.product['fatPer100g'], 'g'),
                const Divider(height: 20),
                _buildNutritionRow('Węglowodany', widget.product['carbohydratesPer100g'], 'g'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedNutritionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  _buildNutritionRow('Błonnik', widget.product['fiberPer100g'], 'g'),
                if (_hasField('sugarsPer100g')) ...[
                  if (_hasField('fiberPer100g')) const Divider(height: 20),
                  _buildNutritionRow('Cukry', widget.product['sugarsPer100g'], 'g'),
                ],
                if (_hasField('sodiumPer100g')) ...[
                  if (_hasField('fiberPer100g') || _hasField('sugarsPer100g'))
                    const Divider(height: 20),
                  _buildNutritionRow('Sód', widget.product['sodiumPer100g'], 'mg'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                widget.product['servingSize'], 
                ProductMappers.mapUnit(widget.product['unit'])
              )
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              widget.product['description'],
              style: const TextStyle(height: 1.5),
            ),
          ),
        ),
      ],
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
            child: Text(
              widget.product['ingredients'],
              style: const TextStyle(height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionRow(String label, dynamic value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(
          ProductMappers.formatNutritionValue(value, unit),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Helper do sprawdzania czy dane pola istnieją
  bool _hasField(String fieldName) {
    return widget.product.containsKey(fieldName) && widget.product[fieldName] != null;
  }

  bool _hasAnyDetailedNutrition() {
    return _hasField('fiberPer100g') || 
           _hasField('sugarsPer100g') || 
           _hasField('sodiumPer100g');
  }

  bool _hasServingSize() {
    return ProductMappers.safeGetDouble(widget.product['servingSize']) > 0;
  }

  bool _hasDescription() {
    return widget.product['description'] != null && 
           widget.product['description'].toString().isNotEmpty;
  }

  bool _hasIngredients() {
    return widget.product['ingredients'] != null && 
           widget.product['ingredients'].toString().isNotEmpty;
  }
}