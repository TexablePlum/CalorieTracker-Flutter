import 'package:calorie_tracker_flutter_front/screens/add_product_screen.dart';
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

class _ProductSearchScreenState extends State<ProductSearchScreen> 
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  late Dio _dio;
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Stan dla zakładki Szukaj
  final List<Map<String, dynamic>> _searchProducts = [];
  bool _isSearchLoading = false;
  String? _searchError;

  // Stan dla zakładki Własne
  final List<Map<String, dynamic>> _myProducts = [];
  bool _isMyLoading = false;
  String? _myError;

  @override
  void initState() {
    super.initState();
    _dio = context.read<Dio>();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _loadMyProducts();
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Wyszukuje produkty w zakładce Szukaj
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
          _searchError = 'Błąd wyszukiwania produktów';
          _isSearchLoading = false;
        });
      }
    }
  }

  /// Ładuje produkty użytkownika w zakładce Własne
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
          _myError = 'Błąd ładowania własnych produktów';
          _isMyLoading = false;
        });
      }
    }
  }

  void _selectProduct(Map<String, dynamic> product) async {
    final productId = product['id'];
    if (productId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak ID produktu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Pokazuje loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(),
    );

    try {
      // Pobiera pełne dane produktu z API
      final response = await _dio.get('/api/Products/$productId');
      final fullProduct = Map<String, dynamic>.from(response.data);
      
      if (!mounted) return;
      
      // Zamyka loading dialog
      Navigator.of(context).pop();

      // Przechodzi do ekranu ustawienia ilości składnika z pełnymi danymi
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddIngredientScreen(product: fullProduct),
        ),
      );
      
      if (!mounted) return;
      
      if (result != null) {
        // Zwraca składnik do poprzedniego ekranu
        Navigator.of(context).pop(result);
      }

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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildStickyHeader(),
        ],
        body: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Zakładka Szukaj z wbudowanym polem wyszukiwania
                  Column(
                    children: [
                      _buildSearchBar(),
                      Expanded(child: _buildSearchTab()),
                    ],
                  ),
                  // Zakładka Własne bez pola wyszukiwania
                  _buildMyProductsTab(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStickyHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      snap: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final safeAreaTop = MediaQuery.of(context).padding.top;
          final toolbarHeight = kToolbarHeight;
          final tabBarHeight = 48.0; // wysokość TabBar z PreferredSize
          
          // Wysokość kiedy header jest całkowicie zwinięty
          final collapsedHeight = safeAreaTop + toolbarHeight + tabBarHeight;
          
          // Sprawdza czy jest blisko zwinięcia
          final isCollapsed = constraints.maxHeight <= collapsedHeight + 10;
          
          return Container(
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    // Row z przyciskami i tytułami
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: isCollapsed
                                ? const Text(
                                    'Wybierz produkt',
                                    key: ValueKey('collapsed'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  )
                                : const Text(
                                    'Wybierz produkt 🥗',
                                    key: ValueKey('expanded'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white, size: 20),
                            onPressed: _navigateToAddProduct,
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: 'Szukaj'),
            Tab(text: 'Własne'),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Wyszukaj produkty...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.search, color: Colors.grey[500], size: 20),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchProducts.clear();
                          _searchError = null;
                        });
                      },
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      ),
    );
  }

  Future<void> _navigateToAddProduct() async {
    try {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => const AddProductScreen(),
        ),
      );

      // Jeśli dodano nowy produkt odświeża listę własnych produktów
      if (result != null && mounted) {
        await _loadMyProducts();
        
        // Przełącza na zakładkę Własne jeśli user jest w Szukaj
        if (_tabController.index == 0) {
          _tabController.animateTo(1);
        }
        
        // Pokazije sukces
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Produkt "${result['name']}" został dodany!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie udało się otworzyć ekranu dodawania produktu'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSearchTab() {
    if (_isSearchLoading) {
      return _buildLoadingState('Wyszukiwanie produktów...');
    }

    if (_searchError != null) {
      return _buildErrorWidget(_searchError!, () {
        if (mounted) _searchAllProducts(_searchController.text);
      });
    }

    if (_searchProducts.isEmpty) {
      return _buildEmptySearchState();
    }

    // W wyszukiwaniu pokazu kafelek "mój"
    return _buildProductList(_searchProducts, showOwnerBadge: true);
  }

  Widget _buildMyProductsTab() {
    if (_isMyLoading) {
      return _buildLoadingState('Ładowanie Twoich produktów...');
    }

    if (_myError != null) {
      return _buildErrorWidget(_myError!, () {
        if (mounted) _loadMyProducts();
      });
    }

    if (_myProducts.isEmpty) {
      return _buildEmptyMyProductsState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (mounted) await _loadMyProducts();
      },
      color: const Color(0xFFA69DF5),
      // W Własne NIE pokazuje kafelka "Mój"
      child: _buildProductList(_myProducts, showOwnerBadge: false),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> products, {required bool showOwnerBadge}) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductCard(products[index], showOwnerBadge: showOwnerBadge);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, {required bool showOwnerBadge}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectProduct(product),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // ikona produktu
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFA69DF5).withOpacity(0.15),
                          const Color(0xFF8B7CF6).withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFA69DF5).withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      ProductMappers.getCategoryIcon(product['category']),
                      color: const Color(0xFFA69DF5),
                      size: 22,
                    ),
                  ),
                  
                  const SizedBox(width: 14),
                  
                  // Główne info 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nazwa 
                        Row(
                          children: [
                            Flexible(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  text: product['name'] ?? 'Bez nazwy',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                  children: [
                                    if (showOwnerBadge) ...[
                                      const TextSpan(text: '  '),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFA69DF5).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFA69DF5).withOpacity(0.3),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: const Text(
                                            'Mój',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFFA69DF5),
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Marka - jeśli dostępna
                        if (product['brand'] != null && product['brand'].toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product['brand'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        
                        const SizedBox(height: 6),
                        
                        //tagi
                        Row(
                          children: [
                            // Kategoria
                            _buildCompactTag(
                              ProductMappers.mapCategory(product['category']),
                              Colors.blue,
                            ),
                            
                            const SizedBox(width: 6),
                            
                            // Kalorie 
                            if (product['caloriesPer100g'] != null)
                              _buildCompactTag(
                                '${product['caloriesPer100g']} kcal/100${ProductMappers.mapUnit(product['unit'])}',
                                Colors.orange,
                              ),
                            
                            // Porcja 
                            if (product['servingSize'] != null && product['servingSize'] > 0) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: _buildCompactTag(
                                  'Porcja: ${ProductMappers.formatNutritionValue(product['servingSize'], ProductMappers.mapUnit(product['unit']))}',
                                  Colors.green,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // przycisk dodaj
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 150),
                    tween: Tween(begin: 1.0, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFA69DF5),
                                Color(0xFF8B7CF6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA69DF5).withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _selectProduct(product),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper do tagów
  Widget _buildCompactTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFA69DF5),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFA69DF5).withOpacity(0.2),
                    const Color(0xFF8B7CF6).withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search,
                size: 64,
                color: Color(0xFFA69DF5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Wyszukaj produkty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Wprowadź nazwę produktu w pole wyszukiwania\naby znaleźć składnik dla przepisu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMyProductsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withOpacity(0.2),
                    Colors.green.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_outlined,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Brak własnych produktów',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dodaj produkty w sekcji skanera\naby tworzyć własną bazę składników',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Wystąpił błąd',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Spróbuj ponownie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA69DF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: const Color(0xFFA69DF5).withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFA69DF5).withOpacity(0.2),
                    const Color(0xFF8B7CF6).withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFFA69DF5),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ładowanie produktu...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pobieranie szczegółowych informacji',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}