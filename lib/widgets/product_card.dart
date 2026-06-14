import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/date_utils.dart';
import 'dart:io';
import 'blinking_widget.dart';
import '../l10n/app_localizations.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final int days = AppDateUtils.calculateRemainingDays(product.expDate);
    final bool isExpired = AppDateUtils.isExpired(product.expDate);
    final l10n = AppLocalizations.of(context)!;
    
    Color statusColor = Colors.green;
    bool shouldBlink = false;

    if (isExpired) {
      statusColor = Colors.red;
    } else if (days <= 30) {
      statusColor = const Color(0xFF5D4037); // Dark Brown
      shouldBlink = true;
    }

    Widget imageWidget;
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      final file = File(product.imagePath!);
      if (file.existsSync()) {
        imageWidget = Image.file(file, width: 70, height: 70, fit: BoxFit.cover);
      } else {
        imageWidget = _buildPlaceholder();
      }
    } else {
      imageWidget = _buildPlaceholder();
    }

    final cardContent = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageWidget,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.name.isEmpty ? "Unknown Product" : product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "EXP: ${product.expDate ?? 'N/A'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    Text(
                      isExpired 
                        ? l10n.expiredBy(days.abs())
                        : l10n.remainingDays(days),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Qty: ${product.quantity} | ${product.size ?? 'N/A'} | Wh: ${product.warehouseName ?? 'General'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isExpired ? Icons.error : Icons.check_circle, 
                color: statusColor, 
                size: 24
              ),
            ],
          ),
        ),
      ),
    );

    return shouldBlink ? BlinkingWidget(child: cardContent) : cardContent;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
    );
  }
}
