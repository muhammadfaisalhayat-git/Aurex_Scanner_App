import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import '../services/learning_service.dart';
import '../widgets/highlighted_image.dart';
import 'field_scanner_screen.dart';
import 'dart:async';

class ResultScreen extends StatefulWidget {
  final Product product;
  const ResultScreen({super.key, required this.product});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _mfgController;
  late TextEditingController _expController;
  late TextEditingController _qtyController;
  late TextEditingController _sizeController;
  String _selectedCategory = "General";
  late TextEditingController _warehouseController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _codeController = TextEditingController(text: widget.product.productCode);
    _mfgController = TextEditingController(text: widget.product.mfgDate);
    _expController = TextEditingController(text: widget.product.expDate);
    _qtyController = TextEditingController(text: widget.product.quantity);
    _sizeController = TextEditingController(text: widget.product.size);
    _selectedCategory = widget.product.category ?? "General";
    _warehouseController = TextEditingController(text: widget.product.warehouseName);
    
    if (widget.product.id == null) _isEditing = true;
  }

  Future<void> _save() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    final p = widget.product;
    p.name = _nameController.text; 
    p.productCode = _codeController.text; 
    p.mfgDate = _mfgController.text;
    p.expDate = _expController.text; 
    p.quantity = _qtyController.text; 
    p.size = _sizeController.text;
    p.category = _selectedCategory; 
    p.warehouseName = _warehouseController.text;

    try {
      // 1. Core Logic: Self-Learning from this entry
      await LearningService().learnLayout(p);
      await LearningService().learnFromCorrection(p);

      // 2. Persist to Database & Cloud
      await Provider.of<DatabaseService>(context, listen: false).insertProduct(p);
      await Provider.of<FirebaseService>(context, listen: false).backupAll([p]);
      
      if (mounted) { 
        Navigator.pop(context); // Close loading
        Navigator.pop(context, true); // Return with refresh signal
      }
    } catch (e) {
      if (mounted) { 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF388E3C);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Product Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryGreen,
        leading: const Icon(Icons.grid_view, color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          if (widget.product.imagePath != null) 
            HighlightedImage(
              imagePath: widget.product.imagePath!, 
              mfgBox: widget.product.mfgBox, 
              expBox: widget.product.expBox,
              height: 250
            )
          else
            Container(
              height: 220, width: double.infinity, color: Colors.grey.shade200,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No image available", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildField("Product Code", _codeController),
              _buildField("Product Name", _nameController, isAr: true),
              Row(children: [
                Expanded(child: _buildField("MFG Date", _mfgController)),
                const SizedBox(width: 10),
                Expanded(child: _buildField("EXP Date", _expController)),
              ]),
              
              Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    items: ["General", "Seeds", "Fertilizer", "Tools"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
              ),

              _buildField("Warehouse", _warehouseController, isAr: true),
              _buildField("Quantity", _qtyController),
              _buildField("Size/Weight", _sizeController),
              
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E7D6A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _save, child: const Text("UPDATE PRODUCT", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              )),
            ]),
          )
        ]),
      ),
    );
  }

  Widget _buildField(String lbl, TextEditingController ctrl, {bool isAr = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: TextField(
        controller: ctrl, textAlign: isAr ? TextAlign.right : TextAlign.left,
        decoration: InputDecoration(
          labelText: lbl, labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.grey), 
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FieldScannerScreen(fieldName: lbl)),
              );
              if (result != null && mounted) {
                setState(() {
                  ctrl.text = result.toString();
                });
              }
            }
          ),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
