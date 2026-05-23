import 'package:flutter/material.dart';
import '../models/product.dart';
import 'dart:io';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.imagePath != null && File(product.imagePath!).existsSync()
              ? Image.file(File(product.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
              : Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported),
                ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Code: \${product.productCode}"),
            Text("EXP: \${product.expDate ?? 'N/A'}",
                 style: TextStyle(color: _getExpiryColor(product.expDate))),
          ],
        ),
        trailing: Icon(
          product.isSynced ? Icons.cloud_done : Icons.cloud_off,
          color: product.isSynced ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Color _getExpiryColor(String? expDate) {
    // Simple logic for color coding expiry - can be improved with date parsing
    return Colors.red;
  }
}
