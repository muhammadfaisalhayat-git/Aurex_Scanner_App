import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import '../services/erp_service.dart';
import 'dart:io';

class ResultScreen extends StatefulWidget {
  final Product product;
  const ResultScreen({super.key, required this.product});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _mfgController;
  late TextEditingController _expController;
  late TextEditingController _qtyController;
  late TextEditingController _sizeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _codeController = TextEditingController(text: widget.product.productCode);
    _mfgController = TextEditingController(text: widget.product.mfgDate);
    _expController = TextEditingController(text: widget.product.expDate);
    _qtyController = TextEditingController(text: widget.product.quantity);
    _sizeController = TextEditingController(text: widget.product.size);
  }

  Future<void> _saveProduct() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final updatedProduct = widget.product;
    updatedProduct.name = _nameController.text;
    updatedProduct.productCode = _codeController.text;
    updatedProduct.mfgDate = _mfgController.text;
    updatedProduct.expDate = _expController.text;
    updatedProduct.quantity = _qtyController.text;
    updatedProduct.size = _sizeController.text;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final erpService = Provider.of<ErpService>(context, listen: false);

    try {
      // 1. Save Locally
      await dbService.insertProduct(updatedProduct);

      // 2. Try Background Sync
      await firebaseService.backupAll([updatedProduct]);

      // 3. Optional: Push to Main ERP Website
      await erpService.pushToErp(updatedProduct);

      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Complete: Saved to Local, Cloud & ERP")));
      Navigator.pop(context); // Go back to Dashboard
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Details"),
        actions: [
          IconButton(onPressed: _saveProduct, icon: const Icon(Icons.check)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.product.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(File(widget.product.imagePath!), height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 24),
            _buildTextField("Product Name", _nameController, Icons.shopping_basket),
            _buildTextField("Product Code", _codeController, Icons.qr_code),
            Row(
              children: [
                Expanded(child: _buildTextField("MFG Date", _mfgController, Icons.date_range)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField("EXP Date", _expController, Icons.event_available, color: Colors.red)),
              ],
            ),
            _buildTextField("Quantity", _qtyController, Icons.production_quantity_limits),
            _buildTextField("Size/Weight", _sizeController, Icons.scale),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E7D6A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SAVE TO HISTORY", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: color),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: TextStyle(color: color),
        ),
      ),
    );
  }
}
