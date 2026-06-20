import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import '../services/learning_service.dart';
import '../widgets/highlighted_image.dart';
import 'field_scanner_screen.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';

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
      await LearningService().learnLayout(p);
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.productDetails, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
              height: 220, width: double.infinity, color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 60, color: isDark ? Colors.white24 : Colors.grey),
                  const SizedBox(height: 10),
                  Text(l10n.noImageAvailable, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildField(l10n.productCode, _codeController),
              _buildField(l10n.productName, _nameController, isAr: true),
              Row(children: [
                Expanded(child: _buildField(l10n.mfgDate, _mfgController)),
                const SizedBox(width: 10),
                Expanded(child: _buildField(l10n.expDate, _expController)),
              ]),
              
              Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor, 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                    items: ["General", "Seeds", "Fertilizer", "Tools"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
              ),

              _buildField(l10n.warehouse, _warehouseController, isAr: true),
              _buildField(l10n.quantity, _qtyController),
              _buildField(l10n.size, _sizeController),
              
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                onPressed: _save, child: Text(l10n.updateProduct.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              )),
            ]),
          )
        ]),
      ),
    );
  }

  Widget _buildField(String lbl, TextEditingController ctrl, {bool isAr = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200, 
        borderRadius: BorderRadius.circular(8)
      ),
      child: TextField(
        controller: ctrl, 
        textAlign: isAr ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: lbl, 
          labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey, fontSize: 14),
          suffixIcon: IconButton(
            icon: Icon(Icons.qr_code_scanner, color: isDark ? Colors.grey : Colors.grey), 
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
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
