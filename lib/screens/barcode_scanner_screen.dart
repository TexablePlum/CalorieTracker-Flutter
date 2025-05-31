import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

/// Rezultat skanowania - może być kod lub produkt
class ScanResult {
  final String? barcode;
  final Map<String, dynamic>? product;
  final bool wasProductFound;

  ScanResult.barcode(this.barcode) : product = null, wasProductFound = false;
  ScanResult.product(this.product, this.barcode) : wasProductFound = true;
  ScanResult.notFound(this.barcode) : product = null, wasProductFound = false;
}

/// Reużywalny skaner kodów kreskowych z opcjonalną integracją API
/// 
/// Użycie:
/// // Tylko skanowanie kodu
/// final result = await Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => BarcodeScannerScreen()),
/// );
/// 
/// // Z automatycznym wyszukiwaniem produktu
/// final result = await Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => BarcodeScannerScreen(searchProducts: true)),
/// );
class BarcodeScannerScreen extends StatefulWidget {
  final bool searchProducts; // Czy automatycznie wyszukiwać produkty w API
  final String? customTitle;
  final String? customInstruction;

  const BarcodeScannerScreen({
    super.key,
    this.searchProducts = false,
    this.customTitle,
    this.customInstruction,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    // Zapobiega wielokrotnemu skanowaniu
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        debugPrint('Kod znaleziony: ${barcode.rawValue}');
        _handleBarcodeFound(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _handleBarcodeFound(String barcode) async {
    setState(() {
      _isProcessing = true;
    });

    // Zatrzymuje skanowanie
    _controller?.stop();

    if (widget.searchProducts) {
      // Wyszukuje produkt w API
      await _searchProduct(barcode);
    } else {
      // Zwraca tylko kod
      Navigator.of(context).pop(ScanResult.barcode(barcode));
    }
  }

  Future<void> _searchProduct(String barcode) async {
    try {
      final dio = context.read<Dio>();
      
      final response = await dio.get(
        '/api/Products/barcode/$barcode',
        options: Options(
          extra: {'skipErrorHandler': true}, // Pomija ErrorHandlerService
        ),
      );

      if (!mounted) return;

      // Produkt znaleziony
      Navigator.of(context).pop(ScanResult.product(response.data, barcode));
      
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 404) {
        // Produkt nie znaleziony
        Navigator.of(context).pop(ScanResult.notFound(barcode));
      } else {
        // Błąd API - zwraca kod i parent obsłuży błąd
        Navigator.of(context).pop(ScanResult.barcode(barcode));
      }
    } catch (e) {
      if (!mounted) return;
      // Błąd - zwraca kod
      Navigator.of(context).pop(ScanResult.barcode(barcode));
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFA69DF5),
          ),
        ),
        backgroundColor: Colors.black,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kamera w tle
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // Overlay z obszarem skanowania
          _buildScannerOverlay(context),

          // Przycisk anuluj
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _handleCancel,
                ),
              ),
            ),
          ),

          // Instrukcje na dole
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.customInstruction ?? 'Skieruj kamerę na kod kreskowy produktu',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Loading overlay jeśli wyszukuje produkt
          if (_isProcessing && widget.searchProducts)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFA69DF5)),
                    SizedBox(height: 16),
                    Text(
                      'Wyszukiwanie produktu...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanAreaWidth = screenSize.width * 0.8;
    final scanAreaHeight = scanAreaWidth * 0.6;

    return Stack(
      children: [
        // Przyciemnione tło z jasnym obszarem skanowania
        CustomPaint(
          size: Size(screenSize.width, screenSize.height),
          painter: ScannerOverlayPainter(
            scanAreaWidth: scanAreaWidth,
            scanAreaHeight: scanAreaHeight,
          ),
        ),

        // Narożniki i animacja w obszarze skanowania
        Center(
          child: Container(
            width: scanAreaWidth,
            height: scanAreaHeight,
            child: Stack(
              children: [
                // Narożniki
                ...buildCorners(),

                // Animowana linia skanowania (tylko jeśli skanuje)
                if (!_isProcessing) const ScanningLine(),
              ],
            ),
          ),
        ),

        // Tekst nad obszarem skanowania
        Positioned(
          top: (screenSize.height - scanAreaHeight) / 2 - 60,
          left: 0,
          right: 0,
          child: Text(
            widget.customTitle ?? 'Umieść kod kreskowy w ramce',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black45,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  List<Widget> buildCorners() {
    return [
      // Lewy górny
      Positioned(
        top: -3,
        left: -3,
        child: Container(
          width: 25,
          height: 25,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white, width: 4),
              left: BorderSide(color: Colors.white, width: 4),
            ),
          ),
        ),
      ),
      // Prawy górny
      Positioned(
        top: -3,
        right: -3,
        child: Container(
          width: 25,
          height: 25,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white, width: 4),
              right: BorderSide(color: Colors.white, width: 4),
            ),
          ),
        ),
      ),
      // Lewy dolny
      Positioned(
        bottom: -3,
        left: -3,
        child: Container(
          width: 25,
          height: 25,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 4),
              left: BorderSide(color: Colors.white, width: 4),
            ),
          ),
        ),
      ),
      // Prawy dolny
      Positioned(
        bottom: -3,
        right: -3,
        child: Container(
          width: 25,
          height: 25,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 4),
              right: BorderSide(color: Colors.white, width: 4),
            ),
          ),
        ),
      ),
    ];
  }
}

// Custom painter dla przyciemnionego tła z jasnym obszarem skanowania
class ScannerOverlayPainter extends CustomPainter {
  final double scanAreaWidth;
  final double scanAreaHeight;

  ScannerOverlayPainter({
    required this.scanAreaWidth,
    required this.scanAreaHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaWidth,
      height: scanAreaHeight,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, darkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Animowana linia skanowania
class ScanningLine extends StatefulWidget {
  const ScanningLine({super.key});

  @override
  State<ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<ScanningLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: ScanningLinePainter(_animation.value),
        );
      },
    );
  }
}

// Painter dla animowanej linii
class ScanningLinePainter extends CustomPainter {
  final double animationValue;

  ScanningLinePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final lineY = size.height * animationValue;

    final paint = Paint()
      ..color = const Color(0xFFA69DF5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        const Color(0xFFA69DF5).withOpacity(0.5),
        const Color(0xFFA69DF5),
        const Color(0xFFA69DF5).withOpacity(0.5),
        Colors.transparent,
      ],
    );

    final rect = Rect.fromLTWH(0, lineY - 5, size.width, 10);
    paint.shader = gradient.createShader(rect);

    canvas.drawLine(
      Offset(10, lineY),
      Offset(size.width - 10, lineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}