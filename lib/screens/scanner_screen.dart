import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import '../services/text_parser.dart';
import '../services/learning_service.dart';
import '../models/product.dart';
import 'result_screen.dart';
import 'product_list_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isAnalyzing = false;
  String? _capturedImagePath;
  bool _isFlashOn = false;
  
  // Real-time metadata
  List<_HighlightBox> _realtimeHighlights = [];
  List<TextBlock> _processingBlocks = [];

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final _textRecognizer = TextRecognizer();
  final _barcodeScanner = BarcodeScanner();
  final _audioPlayer = AudioPlayer();
  
  Timer? _analysisTimer;
  final Set<String> _beepedData = {};

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _laserAnimation = Tween<double>(begin: 0, end: 1).animate(_laserController);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    // Target the main back camera
    CameraDescription? mainCamera;
    for (var c in cameras) {
      if (c.lensDirection == CameraLensDirection.back) {
        mainCamera = c;
        break;
      }
    }
    mainCamera ??= cameras[0];

    _controller = CameraController(
      mainCamera, 
      ResolutionPreset.max,
      enableAudio: false,
    );
    
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startRealtimeAnalysis();
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _startRealtimeAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) async {
      if (_isProcessing || _isAnalyzing || _controller == null || !_controller!.value.isInitialized) return;
      
      _isAnalyzing = true;
      try {
        final image = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        
        final results = await Future.wait([
          _barcodeScanner.processImage(inputImage),
          _textRecognizer.processImage(inputImage),
        ]);

        final barcodes = results[0] as List<Barcode>;
        final recognizedText = results[1] as RecognizedText;
        
        List<_HighlightBox> boxes = [];
        bool newlyDetected = false;

        // 1. Check Barcodes
        if (barcodes.isNotEmpty) {
           final code = barcodes.first.rawValue ?? "";
           if (!_beepedData.contains(code)) {
              newlyDetected = true;
              _beepedData.add(code);
           }
           if (barcodes.first.boundingBox != null) {
              boxes.add(_HighlightBox(barcodes.first.boundingBox!, Colors.blue));
           }
        }

        // 2. Check Dates
        final dateRegex = RegExp(r'\b\d{1,2}[./ \-]\d{2,4}\b');
        for (var block in recognizedText.blocks) {
          final blockText = block.text.toLowerCase();
          for (var line in block.lines) {
            if (dateRegex.hasMatch(line.text)) {
              final val = dateRegex.firstMatch(line.text)!.group(0)!;
              if (!_beepedData.contains(val)) {
                 newlyDetected = true;
                 _beepedData.add(val);
              }
              Color color = Colors.green; 
              if (blockText.contains("exp") || blockText.contains("expire") || blockText.contains("valid") || blockText.contains("انتهاء")) {
                color = Colors.red;
              }
              boxes.add(_HighlightBox(line.boundingBox, color));
            }
          }
        }

        if (mounted && boxes.isNotEmpty) {
          if (newlyDetected) {
            unawaited(_audioPlayer.play(AssetSource('sounds/beep.mp3')).catchError((_) {}));
          }
          setState(() {
            _realtimeHighlights = boxes;
          });
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _realtimeHighlights = []);
          });
        }
        
        File(image.path).delete().catchError((_) {});
      } catch (_) {}
      _isAnalyzing = false;
    });
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    
    _analysisTimer?.cancel();
    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      _capturedImagePath = image.path;
      await _audioPlayer.play(AssetSource('sounds/beep.mp3')).catchError((_) {});
      
      if (mounted) setState(() {});

      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _processingBlocks = recognizedText.blocks;
        });
      }

      // 1. Show Professional Sweep Animation
      await Future.delayed(const Duration(seconds: 3));

      // 2. Comprehensive Field Analysis
      final barcodes = await _barcodeScanner.processImage(inputImage);
      Product product = TextParser.parse(recognizedText);
      
      // 3. APPLY SELF-LEARNING INTELLIGENCE
      product = LearningService().applyIntelligence(product);

      product.barcode = barcodes.isNotEmpty ? barcodes.first.rawValue : null;
      product.productCode = product.barcode ?? product.productCode;
      product.imagePath = image.path;

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => ResultScreen(product: product)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _startRealtimeAnalysis();
      }
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
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

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          
          // Real-time Visual Circles (mapped based on preview size)
          ..._realtimeHighlights.map((box) => Positioned(
            left: box.rect.left * (screenWidth / 1000.0), 
            top: box.rect.top * (screenHeight / 1000.0),
            child: Container(
              width: box.rect.width * (screenWidth / 1000.0), 
              height: box.rect.height * (screenHeight / 1000.0),
              decoration: BoxDecoration(
                border: Border.all(color: box.color, width: 3), 
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          )),

          // Frame Overlay
          Container(
            decoration: const ShapeDecoration(
              shape: _LegacyScannerOverlay(laserPosition: 0, showLaser: false),
            ),
          ),

          if (_isProcessing && _capturedImagePath != null) _buildProcessingUI(),

          if (!_isProcessing)
            Positioned(
              top: 50, left: 10,
              child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 35), onPressed: () => Navigator.pop(context)),
            ),

          if (!_isProcessing)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Row(
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
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white, size: 30),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductListScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image, color: Colors.white, size: 30),
                    onPressed: () {}, 
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingUI() {
    return AnimatedBuilder(
      animation: _laserAnimation,
      builder: (context, child) {
        final double h = MediaQuery.of(context).size.height;
        final double laserY = h * _laserAnimation.value;
        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(child: Image.file(File(_capturedImagePath!), fit: BoxFit.cover)),
              Container(color: Colors.black45),
              
              // Hover and Highlight Animation
              ..._processingBlocks.map((block) {
                final r = block.boundingBox;
                final bool isHit = laserY > r.top && laserY < r.bottom + 80;
                return Positioned(
                  left: r.left, top: r.top,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isHit ? 1.0 : 0.0,
                    child: Container(
                      width: r.width, height: r.height,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2), 
                        border: Border.all(color: Colors.greenAccent, width: 2)
                      ),
                    ),
                  ),
                );
              }),

              // Laser Scanning Line
              Positioned(
                top: laserY, left: 0, right: 0,
                child: Container(
                  height: 3, 
                  decoration: BoxDecoration(
                    color: Colors.greenAccent, 
                    boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 15, spreadRadius: 2)]
                  )
                ),
              ),

              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                    SizedBox(height: 35),
                    Text("Please wait the picture is processing...", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HighlightBox {
  final Rect rect;
  final Color color;
  _HighlightBox(this.rect, this.color);
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
