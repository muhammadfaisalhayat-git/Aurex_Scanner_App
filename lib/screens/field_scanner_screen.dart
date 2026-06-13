import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../services/text_parser.dart';

class FieldScannerScreen extends StatefulWidget {
  final String fieldName;
  const FieldScannerScreen({super.key, required this.fieldName});

  @override
  State<FieldScannerScreen> createState() => _FieldScannerScreenState();
}

class _FieldScannerScreenState extends State<FieldScannerScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  final _textRecognizer = TextRecognizer();
  final _barcodeScanner = BarcodeScanner();
  final _audioPlayer = AudioPlayer();
  bool _isFinished = false;
  bool _isAnalyzing = false;
  int _lastAnalysisTime = 0;
  
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _laserController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0, end: 1).animate(_laserController);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _controller = CameraController(
      cameras[0], 
      ResolutionPreset.high, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startAutoAnalysis();
      }
    } catch (e) {
      debugPrint("Field Camera Error: $e");
    }
  }

  void _startAutoAnalysis() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _controller!.startImageStream((CameraImage image) async {
      if (_isFinished || _isAnalyzing) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastAnalysisTime < 1000) return;
      _lastAnalysisTime = now;

      _isAnalyzing = true;
      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          await _autoDetect(inputImage);
        }
      } catch (e) {
        debugPrint("Field Analysis Error: $e");
      }
      _isAnalyzing = false;
    });
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
    for (final plane in planes) {
      allBytes.add(plane.bytes);
    }
    return allBytes.toBytes();
  }

  Future<void> _autoDetect(InputImage inputImage) async {
    if (_isFinished) return;

    try {
      String? result;

      // 1. Logic for Barcode/Product Code
      if (widget.fieldName.toLowerCase().contains("code")) {
        final barcodes = await _barcodeScanner.processImage(inputImage);
        if (barcodes.isNotEmpty) {
          result = TextParser.cleanProductCode(barcodes.first.rawValue ?? "");
        }
      }

      // 2. Logic for other fields using OCR
      if (result == null || result.isEmpty) {
        final recognizedText = await _textRecognizer.processImage(inputImage);
        final parsed = TextParser.parse(recognizedText);
        
        switch (widget.fieldName) {
          case "Product Name": result = (parsed.name != "Unknown Product") ? parsed.name : null; break;
          case "MFG Date": result = parsed.mfgDate; break;
          case "EXP Date": result = parsed.expDate; break;
          case "Quantity": result = (parsed.quantity != "1") ? parsed.quantity : null; break;
          case "Size/Weight": result = parsed.size; break;
        }
      }

      if (result != null && result.isNotEmpty && !_isFinished) {
        _isFinished = true;
        
        // Confirmation Beep
        unawaited(_audioPlayer.play(AssetSource('sounds/beep.wav')).catchError((_) {}));

        if (mounted) {
          Navigator.pop(context, result);
        }
      }
    } catch (_) {}
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          
          // Animated Scanning Interface
          AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, child) => Container(
              decoration: ShapeDecoration(shape: _AutoScanOverlay(laserPos: _laserAnimation.value)),
            ),
          ),
          
          // Header: No buttons, just status
          Positioned(
            top: 50, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  "AUTO-SCANNING ${widget.fieldName.toUpperCase()}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // Close Button
          Positioned(top: 45, left: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),

          // Guidance Text
          Positioned(
            bottom: 100, left: 0, right: 0,
            child: const Center(
              child: Column(
                children: [
                   Text("Align text/barcode inside the frame", style: TextStyle(color: Colors.white70, fontSize: 16)),
                   SizedBox(height: 15),
                   CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoScanOverlay extends ShapeBorder {
  final double laserPos;
  _AutoScanOverlay({required this.laserPos});
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()..color = Colors.black54;
    final w = rect.width * 0.85, h = rect.height * 0.25;
    final center = rect.center;
    final scanRect = Rect.fromCenter(center: center, width: w, height: h);
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(rect), Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(15)))), paint);
    final borderPaint = Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(15)), borderPaint);
    
    // Laser
    final laserPaint = Paint()..color = Colors.greenAccent..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawLine(Offset(scanRect.left, scanRect.top + h * laserPos), Offset(scanRect.right, scanRect.top + h * laserPos), laserPaint);
  }
  @override
  ShapeBorder scale(double t) => this;
}
