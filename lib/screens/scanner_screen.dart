import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:provider/provider.dart';
import '../services/text_parser.dart';
import '../services/erp_service.dart';
import '../models/product.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  final _textRecognizer = TextRecognizer();
  final _barcodeScanner = BarcodeScanner();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      // 1. Scan Barcode
      final barcodes = await _barcodeScanner.processImage(inputImage);
      String? barcode = barcodes.isNotEmpty ? barcodes.first.rawValue : null;

      // 2. Scan OCR
      final recognizedText = await _textRecognizer.processImage(inputImage);
      Product product = TextParser.parse(recognizedText);

      product.barcode = barcode;
      product.productCode = barcode ?? "";
      product.imagePath = image.path;

      // 3. ERP Integration
      if (barcode != null) {
        final erpService = Provider.of<ErpService>(context, listen: false);
        final erpProduct = await erpService.fetchProductFromErp(barcode);
        if (erpProduct != null) {
          product.name = erpProduct.name;
          product.category = erpProduct.category;
          product.warehouseName = erpProduct.warehouseName;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(product: product),
        ),
      );
    } catch (e) {
      debugPrint("Error during scan: \$e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          Container(
            decoration: const ShapeDecoration(
              shape: OverlayShape(),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
                GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: _isProcessing
                      ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white))
                      : const Center(child: Icon(Icons.camera_alt, color: Colors.white, size: 40)),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.flash_off, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OverlayShape extends ShapeBorder {
  const OverlayShape();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanRect = Rect.fromCenter(
      center: rect.center,
      width: rect.width * 0.8,
      height: rect.height * 0.3,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRect(scanRect),
      ),
      paint,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFF5E7D6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(scanRect, borderPaint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
