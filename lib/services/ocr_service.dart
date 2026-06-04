import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../models/product.dart';

class OCRService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _barcodeScanner = BarcodeScanner();

  Future<Product?> processImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);

    // 1. Scan for Barcodes
    final barcodes = await _barcodeScanner.processImage(inputImage);
    String? foundBarcode;
    if (barcodes.isNotEmpty) {
      foundBarcode = barcodes.first.rawValue;
    }

    // 2. Perform OCR
    await _textRecognizer.processImage(inputImage);

    // Here we will implement the same regex logic from your Kotlin TextParser
    // for extracting MFG and EXP dates.

    return Product(
      productCode: foundBarcode ?? "",
      name: "Scanning result...",
      barcode: foundBarcode,
    );
  }

  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}
