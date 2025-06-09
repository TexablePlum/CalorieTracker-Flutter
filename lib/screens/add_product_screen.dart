import 'package:calorie_tracker_flutter_front/mappers/product_mappers.dart';
import 'package:calorie_tracker_flutter_front/screens/barcode_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

class AddProductScreen extends StatefulWidget {
  final String? scannedBarcode; // Opcjonalny kod kreskowy ze skanera
  final Map<String, dynamic>? productToEdit; // Opcjonalny produkt do edycji

  const AddProductScreen({
    super.key, 
    this.scannedBarcode,
    this.productToEdit,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  /* ──────────────────────────────────────────────
     CONTROLLERS / STATE
  ────────────────────────────────────────────── */
  final _formKey = GlobalKey<FormState>();
  
  // Kontrolery dla pól formularza
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _servingSizeController = TextEditingController();
  
  // Kontrolery dla informacji żywieniowych
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbohydratesController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarsController = TextEditingController();
  final _sodiumController = TextEditingController();

  // Wybrane kategoria i jednostka
  // Domyślne wartości
  String _selectedCategory = 'Inne';
  String _selectedUnit = 'g';

  bool _isLoading = false;
  String? _errorMessage;

  /// Sprawdza czy jesteśmy w trybie edycji
  bool get _isEditMode => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  /// Inicjalizuje formularz - wypełnia danymi do edycji lub kodem kreskowym
  void _initializeForm() {
    if (_isEditMode) {
      // Tryb edycji - wypełnia formularz danymi produktu
      final product = widget.productToEdit!;
      
      _nameController.text = ProductMappers.safeGetString(product['name']);
      _brandController.text = ProductMappers.safeGetString(product['brand']);
      _descriptionController.text = ProductMappers.safeGetString(product['description']);
      _ingredientsController.text = ProductMappers.safeGetString(product['ingredients']);
      _barcodeController.text = ProductMappers.safeGetString(product['barcode']);
      _servingSizeController.text = _formatNumber(product['servingSize']);
      
      _caloriesController.text = _formatNumber(product['caloriesPer100g']);
      _proteinController.text = _formatNumber(product['proteinPer100g']);
      _fatController.text = _formatNumber(product['fatPer100g']);
      _carbohydratesController.text = _formatNumber(product['carbohydratesPer100g']);
      _fiberController.text = _formatNumber(product['fiberPer100g']);
      _sugarsController.text = _formatNumber(product['sugarsPer100g']);
      _sodiumController.text = _formatNumber(product['sodiumPer100g']);
      
      _selectedCategory = ProductMappers.mapCategory(product['category']);
      _selectedUnit = ProductMappers.mapUnit(product['unit']);
      
    } else if (widget.scannedBarcode != null) {
      // Tryb dodawania z kodem kreskowym
      _barcodeController.text = widget.scannedBarcode!;
    }
  }

  /// Formatuje liczbę do stringa (usuwa .0 dla liczb całkowitych)
  String _formatNumber(dynamic value) {
    if (value == null) return '';
    
    final doubleValue = ProductMappers.safeGetDouble(value);
    
    if (doubleValue == doubleValue.roundToDouble()) {
      return doubleValue.round().toString();
    } else {
      return doubleValue.toString();
    }
  }

  @override
  void dispose() {
    // Zwalnia kontrolery
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _barcodeController.dispose();
    _servingSizeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbohydratesController.dispose();
    _fiberController.dispose();
    _sugarsController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  /* ──────────────────────────────────────────────
     SUBMIT PRODUCT
  ────────────────────────────────────────────── */
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = context.read<Dio>();
      
      // Przygotowuje dane do wysłania
      final requestData = {
        "name": _nameController.text.trim(),
        "brand": _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : null,
        "description": _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        "ingredients": _ingredientsController.text.trim().isNotEmpty ? _ingredientsController.text.trim() : null,
        "barcode": _barcodeController.text.trim().isNotEmpty ? _barcodeController.text.trim() : null,
        "category": ProductMappers.mapCategoryToEnum(_selectedCategory),
        "unit": ProductMappers.mapUnitToEnum(_selectedUnit),
        "servingSize": _parseDouble(_servingSizeController.text),
        "caloriesPer100g": _parseDouble(_caloriesController.text),
        "proteinPer100g": _parseDouble(_proteinController.text),
        "fatPer100g": _parseDouble(_fatController.text),
        "carbohydratesPer100g": _parseDouble(_carbohydratesController.text),
        "fiberPer100g": _parseDouble(_fiberController.text),
        "sugarsPer100g": _parseDouble(_sugarsController.text),
        "sodiumPer100g": _parseDouble(_sodiumController.text),
      };

      if (_isEditMode) {
        await _updateProduct(dio, requestData);
      } else {
        await _createProduct(dio, requestData);
      }

    } on DioException catch (e) {
      debugPrint('❌ ${_isEditMode ? 'EditProduct' : 'AddProduct'}: DioException: ${e.type} - ${e.response?.statusCode}');
      debugPrint('❌ Error data: ${e.response?.data}');
      
      if (!mounted) return;

      // Sprawdza czy błąd wystąpił podczas pobierania danych produktu (tylko dla trybu dodawania)
      if (!_isEditMode && 
          e.requestOptions.path.contains('/api/Products/') && 
          e.requestOptions.method == 'GET') {
        // Produkt został utworzony, ale nie udało się pobrać jego danych
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produkt został dodany, ale wystąpił problem z jego wyświetleniem'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = _extractErrorMessage(e.response?.data, e.response?.statusCode);
        });
      }

    } catch (e) {
      debugPrint('❌ ${_isEditMode ? 'EditProduct' : 'AddProduct'}: Unexpected error: $e');
      
      if (!mounted) return;
      
      setState(() {
        _errorMessage = "Wystąpił nieoczekiwany błąd. Spróbuj ponownie.";
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Tworzy nowy produkt
  Future<void> _createProduct(Dio dio, Map<String, dynamic> requestData) async {
    debugPrint('🍎 AddProduct: Creating new product...');

    final response = await dio.post('/api/Products', data: requestData);
    final productId = response.data['id'];
    
    if (productId == null) {
      throw Exception('Brak ID utworzonego produktu');
    }

    // Pobiera pełne dane utworzonego produktu
    final productResponse = await dio.get('/api/Products/$productId');
    final createdProduct = Map<String, dynamic>.from(productResponse.data);

    if (!mounted) return;

    debugPrint('🍎 AddProduct: Product created successfully');

    // Wraca z danymi nowego produktu
    Navigator.of(context).pop(createdProduct);
  }

  /// Aktualizuje istniejący produkt
  Future<void> _updateProduct(Dio dio, Map<String, dynamic> requestData) async {
    final productId = widget.productToEdit!['id'];
    
    debugPrint('✏️ EditProduct: Updating product $productId...');

    await dio.put('/api/Products/$productId', data: requestData);
    
    // Pobiera zaktualizowane dane produktu
    final productResponse = await dio.get('/api/Products/$productId');
    final updatedProduct = Map<String, dynamic>.from(productResponse.data);

    if (!mounted) return;

    debugPrint('✏️ EditProduct: Product updated successfully');

    // Wraca z zaktualizowanymi danymi produktu
    Navigator.of(context).pop(updatedProduct);
  }

  /* ──────────────────────────────────────────────
     BARCODE SCANNER
  ────────────────────────────────────────────── */
  Future<void> _openBarcodeScanner() async {
    try {
      final result = await Navigator.push<ScanResult>(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeScannerScreen(
            searchProducts: false,
            customTitle: "Zeskanuj kod kreskowy",
            customInstruction: "Skieruj kamerę na kod kreskowy produktu",
          ),
          fullscreenDialog: true,
        ),
      );

      if (result != null && result.barcode != null) {
        setState(() {
          _barcodeController.text = result.barcode!;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kod kreskowy zeskanowany: ${result.barcode}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening scanner: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się otworzyć skanera'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /* ──────────────────────────────────────────────
     HELPER METHODS
  ────────────────────────────────────────────── */
  double? _parseDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  String _extractErrorMessage(dynamic data, int? statusCode) {
    try {
      if (data is Map && data['errors'] != null) {
        final errors = (data['errors'] as Map<String, dynamic>)
            .values
            .expand((e) => e is List ? e : [e])
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join('\n');
        return errors.isNotEmpty ? errors : "Błąd walidacji danych";
      }
      
      if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
      
      switch (statusCode) {
        case 400:
          return "Nieprawidłowe dane. Sprawdź wprowadzone wartości.";
        case 403:
          return "Nie masz uprawnień do tej operacji.";
        case 404:
          return "Produkt nie został znaleziony.";
        case 409:
          return "Produkt o tym kodzie kreskowym już istnieje.";
        case 422:
          return "Dane nie przeszły walidacji. Sprawdź wszystkie pola.";
        default:
          return "Błąd serwera (kod: ${statusCode ?? 'nieznany'})";
      }
    } catch (e) {
      return "Błąd przetwarzania odpowiedzi serwera.";
    }
  }

  /* ──────────────────────────────────────────────
     UI BUILDERS
  ────────────────────────────────────────────── */
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFA69DF5),
            const Color(0xFF8B7CF6),
            const Color(0xFF7C3AED),
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
                  _isEditMode ? "Edytuj produkt" : "Dodaj produkt",
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool required = true,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
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
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: suffixIcon,
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
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
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
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /* ──────────────────────────────────────────────
     BUILD
  ────────────────────────────────────────────── */
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
                  children: [
                    const SizedBox(height: 8),
                    
                    _buildSection("Podstawowe informacje", [
                      _buildTextField(
                        controller: _nameController,
                        label: "Nazwa produktu",
                        hint: "np. Mleko 3.2%",
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Nazwa produktu jest wymagana";
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _brandController,
                        label: "Marka",
                        hint: "np. Łaciate",
                        required: false,
                      ),
                      _buildTextField(
                        controller: _barcodeController,
                        label: "Kod kreskowy",
                        hint: "np. 5900512345678",
                        keyboardType: TextInputType.number,
                        required: false,
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Color(0xFFA69DF5),
                          ),
                          onPressed: _openBarcodeScanner,
                          tooltip: "Skanuj kod kreskowy",
                        ),
                      ),
                      _buildDropdown<String>(
                        label: "Kategoria",
                        value: _selectedCategory,
                        items: ProductMappers.getAllCategories().map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCategory = value!),
                      ),
                      //Wielkość porcji i jednostka
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _servingSizeController,
                              label: "Wielkość porcji",
                              hint: "np. 100",
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              required: true, // ZMIENIONE: teraz wymagane
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Wielkość porcji jest wymagana";
                                }
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null || parsed <= 0) {
                                  return "Wprowadź prawidłową wielkość porcji";
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<String>(
                              label: "Jednostka",
                              value: _selectedUnit,
                              items: ProductMappers.getAllUnits().map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedUnit = value!),
                            ),
                          ),
                        ],
                      ),
                    ]),

                    // Sekcja informacji żywieniowych (na 100g/100ml)
                    _buildSection("Informacje żywieniowe (na 100g/100ml)", [
                      _buildTextField(
                        controller: _caloriesController,
                        label: "Kalorie (kcal)",
                        hint: "np. 64",
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        required: false,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _proteinController,
                              label: "Białko (g)",
                              hint: "np. 3.2",
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              required: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _fatController,
                              label: "Tłuszcz (g)",
                              hint: "np. 3.2",
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              required: false,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _carbohydratesController,
                              label: "Węglowodany (g)",
                              hint: "np. 4.8",
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              required: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _fiberController,
                              label: "Błonnik (g)",
                              hint: "np. 0",
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              required: false,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _sugarsController,
                              label: "Cukry (g)",
                              hint: "np. 4.8",
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              required: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _sodiumController,
                              label: "Sód (mg)",
                              hint: "np. 44",
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              required: false,
                            ),
                          ),
                        ],
                      ),
                    ]),

                    // Additional Information
                    _buildSection("Dodatkowe informacje", [
                      _buildTextField(
                        controller: _descriptionController,
                        label: "Opis",
                        hint: "Opcjonalny opis produktu",
                        maxLines: 3,
                        required: false,
                      ),
                      _buildTextField(
                        controller: _ingredientsController,
                        label: "Składniki",
                        hint: "Lista składników oddzielona przecinkami",
                        maxLines: 3,
                        required: false,
                      ),
                    ]),

                    _buildErrorMessage(),

                    // Submit Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.only(top: 8, bottom: 32),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA69DF5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          shadowColor: const Color(0xFFA69DF5).withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _isEditMode ? "Zaktualizuj produkt" : "Dodaj produkt",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
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