import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import '../services/text_parser.dart';
import '../models/product.dart';
import '../services/neural_post_processor.dart';
import '../services/learning_service.dart';
import 'result_screen.dart';
import 'product_list_screen.dart';
import '../l10n/app_localizations.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isAnalyzing = false;
  bool _isFlashOn = false;
  
  // Multi-shot state
  final List<String> _capturedPaths = [];
  final List<RecognizedText> _capturedTexts = [];
  final List<Size> _capturedSizes = [];
  final List<List<TextBlock>> _capturedBlocks = [];
  String? _lastBarcode;

  // Zoom state
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  // Real-time metadata
  List<_HighlightBox> _realtimeHighlights = [];

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final _textRecognizer = TextRecognizer();
  final _barcodeScanner = BarcodeScanner();
  final _audioPlayer = AudioPlayer();
  final _beepSource = AssetSource('sounds/shutter_v2.wav');
  int _lastAnalysisTime = 0;
  final Set<String> _beepedData = {};

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupAudio();
    _laserController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _laserAnimation = Tween<double>(begin: 0, end: 1).animate(_laserController);
  }

  Future<void> _setupAudio() async {
    try {
      await _audioPlayer.setSource(_beepSource);
      await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}
  }

  Future<void> _playBeep() async {
    try { await _audioPlayer.play(_beepSource, mode: PlayerMode.lowLatency); } catch (_) {}
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    CameraDescription? mainCamera;
    for (var c in cameras) {
      if (c.lensDirection == CameraLensDirection.back) { mainCamera = c; break; }
    }
    mainCamera ??= cameras[0];

    _controller = CameraController(
      mainCamera, 
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    
    try {
      await _controller!.initialize();
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      if (mounted) {
        setState(() {});
        _startImageStream();
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _startImageStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing || _isAnalyzing) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastAnalysisTime < 1500) return;
      _lastAnalysisTime = now;

      _isAnalyzing = true;
      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) { _isAnalyzing = false; return; }

        final results = await Future.wait([
          _barcodeScanner.processImage(inputImage),
          _textRecognizer.processImage(inputImage),
        ]);

        final barcodes = results[0] as List<Barcode>;
        final recognizedText = results[1] as RecognizedText;
        
        // Accurate Image Size for normalization
        final Size baseSize = inputImage.metadata!.size;
        final rotation = inputImage.metadata!.rotation;
        
        // Adjust size for portrait mode (swap width/height if 90/270 degree rotation)
        final bool isPortrait = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
        final double imgW = isPortrait ? baseSize.height : baseSize.width;
        final double imgH = isPortrait ? baseSize.width : baseSize.height;
        final Size effectiveSize = Size(imgW, imgH);

        List<_HighlightBox> boxes = [];
        bool newlyDetected = false;

        if (barcodes.isNotEmpty) {
           final code = barcodes.first.rawValue ?? "";
           _lastBarcode = code;
           if (!_beepedData.contains(code)) { newlyDetected = true; _beepedData.add(code); }
           if (barcodes.first.boundingBox != null) {
              boxes.add(_HighlightBox(_normalizeRect(barcodes.first.boundingBox!, effectiveSize), Colors.blue));
           }
        }

        final dateRegex = RegExp(r'\b\d{1,2}[./ \-]\d{2,4}\b');
        for (var block in recognizedText.blocks) {
          final blockText = block.text.toLowerCase();
          for (var line in block.lines) {
            if (dateRegex.hasMatch(line.text)) {
              final val = dateRegex.firstMatch(line.text)!.group(0)!;
              if (!_beepedData.contains(val)) { newlyDetected = true; _beepedData.add(val); }
              
              // High-precision color assignment
              Color color = Colors.green; // Default to Green (MFG)
              
              // If the text contains expiry keywords, strictly set to Red
              final isExpiry = blockText.contains("exp") || 
                              blockText.contains("expire") || 
                              blockText.contains("valid") || 
                              blockText.contains("تاريخ الانتهاء") ||
                              blockText.contains("انتهاء") ||
                              blockText.contains("صلاحية") ||
                              blockText.contains("bb") ||
                              blockText.contains("best before");
              
              if (isExpiry) {
                color = Colors.red;
              }

              boxes.add(_HighlightBox(_normalizeRect(line.boundingBox, effectiveSize), color));
            }
          }
        }

        if (mounted && boxes.isNotEmpty) {
          if (newlyDetected) unawaited(_playBeep());
          setState(() { _realtimeHighlights = boxes; });
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) setState(() => _realtimeHighlights = []);
          });
        }
      } catch (_) {}
      _isAnalyzing = false;
    });
  }

  Rect _normalizeRect(Rect rawRect, Size imageSize) {
    // Maps raw camera pixel coordinates to a 1000x1000 normalized space
    double left = (rawRect.left / imageSize.width) * 1000.0;
    double top = (rawRect.top / imageSize.height) * 1000.0;
    double right = (rawRect.right / imageSize.width) * 1000.0;
    double bottom = (rawRect.bottom / imageSize.height) * 1000.0;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final sensorOrientation = _controller!.description.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = BytesBuilder();
    for (final plane in planes) { allBytes.add(plane.bytes); }
    return allBytes.toBytes();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    
    unawaited(_playBeep());

    try {
      final XFile rawImage = await _controller!.takePicture();
      
      final directory = await getApplicationDocumentsDirectory();
      final String imagesPath = p.join(directory.path, 'product_images');
      final dir = Directory(imagesPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final String permanentPath = p.join(imagesPath, "shot_${_capturedPaths.length}_${DateTime.now().millisecondsSinceEpoch}.jpg");
      final File imageFile = await File(rawImage.path).copy(permanentPath);

      final bytes = await imageFile.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      final imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());

      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      setState(() {
        _capturedPaths.add(imageFile.path);
        _capturedTexts.add(recognizedText);
        _capturedSizes.add(imageSize);
        _capturedBlocks.add(recognizedText.blocks);
      });

      // Show temporary overlay effect
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Captured Photo #${_capturedPaths.length}"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));

      File(rawImage.path).delete().catchError((_) {});
    } catch (e) {
      debugPrint("Capture Error: $e");
    }
  }

  Future<void> _finish() async {
    if (_capturedPaths.isEmpty) return;
    setState(() => _isProcessing = true);
    
    try {
      Product product = NeuralPostProcessor().refineMulti(_capturedTexts, _capturedSizes);
      for (var blocks in _capturedBlocks) {
        product = LearningService().applySpatialIntelligence(product, blocks);
      }

      product.barcode = _lastBarcode;
      product.productCode = product.barcode ?? product.productCode;
      product.imagePaths = List.from(_capturedPaths);

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => ResultScreen(product: product)));
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _controller?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.green)));
    }
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: (d) => _baseZoomLevel = _currentZoomLevel,
              onScaleUpdate: (d) {
                double newZoom = (_baseZoomLevel * d.scale).clamp(_minZoomLevel, _maxZoomLevel);
                if (newZoom != _currentZoomLevel) {
                  _currentZoomLevel = newZoom;
                  _controller!.setZoomLevel(_currentZoomLevel);
                  setState(() {});
                }
              },
              child: CameraPreview(_controller!),
            ),
          ),
          
          ..._realtimeHighlights.map((box) => _MappedHighlight(rect: box.rect, color: box.color)),
          Container(decoration: const ShapeDecoration(shape: _LegacyScannerOverlay(laserPosition: 0, showLaser: false))),

          if (_currentZoomLevel > 1.0)
            Positioned(bottom: 150, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text("${_currentZoomLevel.toStringAsFixed(1)}x", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),

          if (_isProcessing) _buildProcessingUI(),

          if (!_isProcessing)
            Positioned(top: 50, left: 10, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 35), onPressed: () => Navigator.pop(context))),

          if (!_isProcessing)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_capturedPaths.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "${_capturedPaths.length} PHOTOS CAPTURED",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, 
                              foregroundColor: Colors.green.shade800, 
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              elevation: 5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _finish,
                            icon: const Icon(Icons.check_circle, size: 24),
                            label: const Text("FINISH & PROCESS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 30),
                        onPressed: () {
                          _isFlashOn = !_isFlashOn;
                          _controller?.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
                          setState(() {});
                        },
                      ),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          height: 85, width: 85,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                          child: const Center(child: Icon(Icons.camera_alt, color: Colors.white, size: 45)),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.history, color: Colors.white, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductListScreen()))),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingUI() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
            const SizedBox(height: 30),
            Text(AppLocalizations.of(context)!.pleaseWaitProcessing, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}

class _HighlightBox {
  final Rect rect;
  final Color color;
  _HighlightBox(this.rect, this.color);
}

class _MappedHighlight extends StatelessWidget {
  final Rect rect;
  final Color color;
  const _MappedHighlight({required this.rect, required this.color});
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Positioned(
      left: rect.left * (screenWidth / 1000.0) - 5,
      top: rect.top * (screenHeight / 1000.0) - 5,
      child: Container(
        width: rect.width * (screenWidth / 1000.0) + 10,
        height: rect.height * (screenHeight / 1000.0) + 10,
        decoration: BoxDecoration(border: Border.all(color: color, width: 3), borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _LegacyScannerOverlay extends ShapeBorder {
  final double laserPosition;
  final bool showLaser;
  const _LegacyScannerOverlay({required this.laserPosition, this.showLaser = true});
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()..color = Colors.black.withOpacity(0.45);
    final w = rect.width * 0.9, h = rect.height * 0.55;
    final center = rect.center;
    final scanRect = Rect.fromCenter(center: center, width: w, height: h);
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(rect), Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(15)))), paint);
    final borderPaint = Paint()..color = const Color(0xFF388E3C)..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(15)), borderPaint);
  }
  @override
  ShapeBorder scale(double t) => this;
}
