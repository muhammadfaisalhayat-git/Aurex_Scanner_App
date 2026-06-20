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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final int days = AppDateUtils.calculateRemainingDays(product.expDate);
    final bool isExpired = AppDateUtils.isExpired(product.expDate);
    final l10n = AppLocalizations.of(context)!;
    
    Color statusColor = theme.colorScheme.primary;
    bool shouldBlink = false;

    if (isExpired) {
      statusColor = Colors.red;
    } else if (days <= 30) {
      statusColor = isDark ? Colors.orangeAccent : const Color(0xFF5D4037); 
      shouldBlink = true;
    }

    Widget imageWidget;
    // Explicitly use the first image path as the primary thumbnail
    final String? thumbnailPath = product.imagePaths.isNotEmpty ? product.imagePaths.first : null;
    
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final file = File(thumbnailPath);
      if (file.existsSync()) {
        imageWidget = Image.file(file, width: 70, height: 70, fit: BoxFit.cover);
      } else {
        imageWidget = _buildPlaceholder(isDark);
      }
    } else {
      imageWidget = _buildPlaceholder(isDark);
    }

    final cardContent = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.cardColor,
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageWidget,
                  ),
                  if (product.imagePaths.length > 1)
                    Positioned(
                      right: 4, bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text("${product.imagePaths.length}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.isEmpty ? "Unknown Product" : product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "EXP: ${product.expDate ?? 'N/A'}",
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 13),
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
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 12),
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

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(color: isDark ? Colors.grey.shade900 : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.image_outlined, color: isDark ? Colors.white24 : Colors.grey, size: 40),
    );
  }
}
