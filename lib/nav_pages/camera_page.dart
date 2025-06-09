import 'package:calorie_tracker_flutter_front/nav_pages/main_page.dart';
import 'package:calorie_tracker_flutter_front/screens/add_product_screen.dart';
import 'package:flutter/material.dart';
import 'package:calorie_tracker_flutter_front/screens/barcode_scanner_screen.dart';
import 'package:calorie_tracker_flutter_front/screens/product_info_screen.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  Future<void> _startScanning() async {
    final result = await Navigator.push<ScanResult>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          searchProducts: true, // Automatyczne wyszukiwanie w API
        ),
        fullscreenDialog: true,
      ),
    );

    if (!mounted || result == null) return;

    if (result.wasProductFound && result.product != null) {
      // Produkt znaleziony - pokazuje stronę produktu
      _showProductScreen(result.product!);
    } else if (result.barcode != null) {
      // Produkt nie znaleziony - pokazuje dialog
      _showProductNotFound(result.barcode!);
    }
  }

  void _showProductScreen(Map<String, dynamic> product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductInfoScreen(
          product: product,
          bottomWidget: _buildProductActionButtons(),
        ),
      ),
    );
  }

  Future<void> _navigateToAddProduct(String barcode) async {
    Navigator.of(context).pop(); // Zamyka dialog
    
    final productData = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(scannedBarcode: barcode),
      ),
    );

    // Jeśli otrzymaliśmy dane produktu - pokazuje je
    if (productData != null) {
      _showProductScreen(productData);
    }
  }

  Widget _buildProductActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _startScanning();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Skanuj kolejny'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFA69DF5),
                side: const BorderSide(color: Color(0xFFA69DF5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductNotFound(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Produkt nie znaleziony'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Nie znaleziono produktu o kodzie:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            SelectableText(
              barcode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Czy chcesz dodać ten produkt do bazy danych?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startScanning();
            },
            child: const Text('Skanuj inny'),
          ),
          ElevatedButton(
            onPressed: () => _navigateToAddProduct(barcode),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA69DF5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Dodaj produkt'),
          ),
        ],
      ),
    );
  }
  
  void _handleBackNavigation() {
    if (ModalRoute.of(context)?.isFirst ?? true) {
      final mainPageState = context.findAncestorStateOfType<MainPageState>();
      if (mainPageState != null) {
        mainPageState.goToPreviousTab();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFA69DF5),
        title: const Text("Skaner kodów"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackNavigation,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Color(0xFFA69DF5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Skaner kodów kreskowych',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA69DF5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Naciśnij przycisk poniżej, aby\nzeskanować kod kreskowy produktu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startScanning,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA69DF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.camera_alt),
              label: const Text(
                'Skanuj kod',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}