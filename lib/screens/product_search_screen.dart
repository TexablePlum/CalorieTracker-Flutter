import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../mappers/product_mappers.dart';
import '../screens/add_ingredient_screen.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late Dio _dio;
  late TabController _tabController;
  
  // Stan dla zakładki "Szukaj"
  final List<Map<String, dynamic>> _searchProducts = [];
  bool _isSearchLoading = false;
  String? _searchError;

  // Stan dla zakładki "Własne"
  final List<Map<String, dynamic>> _myProducts = [];
  bool _isMyLoading = false;
  String? _myError;

  @override
  void initState() {
    super.initState();
    _dio = context.read<Dio>();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Wyszukuje produkty w zakładce "Szukaj"
  Future<void> _searchAllProducts(String searchTerm) async {
    if (searchTerm.trim().isEmpty) {
      setState(() {
        _searchProducts.clear();
        _isSearchLoading = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
      _searchError = null;
    });

    try {
      final response = await _dio.get(
        '/api/Products/search',
        queryParameters: {
          'searchTerm': searchTerm,
          'take': 50,
        },
      );

      if (mounted) {
        setState(() {
          final responseData = response.data;
          if (responseData is Map && responseData['products'] is List) {
            _searchProducts.clear();
            _searchProducts.addAll(List<Map<String, dynamic>>.from(responseData['products']));
          } else {
            _searchProducts.clear();
          }
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Błąd wyszukiwania: $e';
          _isSearchLoading = false;
        });
      }
    }
  }

  /// Ładuje produkty użytkownika w zakładce "Własne"
  Future<void> _loadMyProducts() async {
    setState(() {
      _isMyLoading = true;
      _myError = null;
    });

    try {
      final response = await _dio.get(
        '/api/products/my-products',
        queryParameters: {
          'skip': 0,
          'take': 100,
        },
      );

      if (mounted) {
        setState(() {
          _myProducts.clear();
          _myProducts.addAll(List<Map<String, dynamic>>.from(response.data));
          _isMyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _myError = 'Błąd ładowania własnych produktów: $e';
          _isMyLoading = false;
        });
      }
    }
  }

  void _selectProduct(Map<String, dynamic> product) async {
    final productId = product['id'];
    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak ID produktu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Pokazuje loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFA69DF5)),
      ),
    );

    try {
      // Pobiera pełne dane produktu z API
      final response = await _dio.get('/api/Products/$productId');
      final fullProduct = Map<String, dynamic>.from(response.data);
      
      if (!mounted) return;
      
      // Zamyka loading dialog
      Navigator.of(context).pop();

      // Przechodzi do ekranu ustawienia ilości składnika z pełnymi danymi
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddIngredientScreen(product: fullProduct),
        ),
      ).then((ingredient) {
        if (ingredient != null) {
          // Zwraca składnik do poprzedniego ekranu
          Navigator.of(context).pop(ingredient);
        }
      });

    } on DioException catch (e) {
      if (!mounted) return;
      
      // Zamyka loading dialog
      Navigator.of(context).pop();
      
      String errorMessage;
      switch (e.response?.statusCode) {
        case 404:
          errorMessage = 'Produkt nie został znaleziony';
          break;
        case 403:
          errorMessage = 'Brak uprawnień do tego produktu';
          break;
        default:
          errorMessage = 'Nie udało się pobrać danych produktu';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      
      // Zamyka loading dialog
      Navigator.of(context).pop();
      
      debugPrint('❌ Unexpected error loading product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wystąpił nieoczekiwany błąd'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wybierz produkt'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFA69DF5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFA69DF5),
          tabs: const [
            Tab(text: 'Szukaj'),
            Tab(text: 'Własne'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar dla zakładki "Szukaj"
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              if (_tabController.index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Wyszukaj produkty...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchProducts.clear();
                                  _searchError = null;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _searchAllProducts,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setState(() {
                          _searchProducts.clear();
                          _searchError = null;
                        });
                      }
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
   
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(),
                _buildMyProductsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    if (_isSearchLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFA69DF5)),
      );
    }

    if (_searchError != null) {
      return _buildErrorWidget(_searchError!, () => _searchAllProducts(_searchController.text));
    }

    if (_searchProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty 
                  ? 'Nie znaleziono produktów'
                  : 'Wyszukaj produkty',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Wpisz nazwę produktu w pole wyszukiwania',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchProducts.length,
      itemBuilder: (context, index) {
        final product = _searchProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildMyProductsTab() {
    if (_isMyLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFA69DF5)),
      );
    }

    if (_myError != null) {
      return _buildErrorWidget(_myError!, _loadMyProducts);
    }

    if (_myProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Brak własnych produktów',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dodaj produkty w sekcji skanera',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyProducts,
      color: const Color(0xFFA69DF5),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _myProducts.length,
        itemBuilder: (context, index) {
          final product = _myProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Spróbuj ponownie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA69DF5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          product['name'] ?? 'Bez nazwy',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product['brand'] != null && product['brand'].toString().isNotEmpty)
              Text('Marka: ${product['brand']}'),
            if (product['category'] != null)
              Text('Kategoria: ${ProductMappers.mapCategory(product['category'])}'),
            Row(
              children: [
                if (product['caloriesPer100g'] != null)
                  Text('${product['caloriesPer100g']} kcal/100${ProductMappers.mapUnit(product['unit'])}'),
                if (product['servingSize'] != null && product['servingSize'] > 0) ...[
                  const Text(' • '),
                  Text('Porcja: ${ProductMappers.formatNutritionValue(product['servingSize'], ProductMappers.mapUnit(product['unit']))}'),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.add_circle_outline,
          color: Color(0xFFA69DF5),
        ),
        onTap: () => _selectProduct(product),
      ),
    );
  }
}