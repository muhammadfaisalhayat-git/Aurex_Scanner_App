import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/product.dart';
import 'database_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference get _productRef {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _db.ref("users/${user.uid}/products");
  }

  Future<void> backupAll(List<Product> products, {Function(int current, int total)? onProgress}) async {
    Map<String, dynamic> updates = {};
    final int total = products.length;
    int count = 0;

    for (var product in products) {
      String key = product.productCode.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      if (key.isEmpty) key = "ID_${product.id}";
      
      product.isSynced = true;
      updates[key] = product.toMap();
      
      count++;
      if (onProgress != null) onProgress(count, total);
    }
    
    await _productRef.update(updates);
  }

  Future<int?> restoreAll({Function(int current, int total)? onProgress}) async {
    // 1. Enable Persistence for faster lookup
    _db.setPersistenceEnabled(true);

    final snapshot = await _productRef.get();
    if (!snapshot.exists || snapshot.value == null) return null;

    final dbService = DatabaseService();
    List<Product> products = [];

    if (snapshot.value is Map) {
      final Map<dynamic, dynamic> data = snapshot.value as Map;
      final int total = data.length;
      int count = 0;
      
      for (var entry in data.entries) {
        try {
          // Parse product data
          final productData = Map<dynamic, dynamic>.from(entry.value as Map);
          
          // DO NOT nullify ID here if we want to keep cloud mapping, 
          // but for local UI we need to ensure they are unique.
          // Re-generating IDs locally ensures they show up as separate cards.
          productData['id'] = null; 

          products.add(Product.fromMap(productData));
          count++;
          if (onProgress != null) onProgress(count, total);
        } catch (e) {
          debugPrint("Error parsing product: $e");
        }
      }
    }

    if (products.isNotEmpty) {
      // 2. Clear local database to prevent mixing old and new data
      await dbService.deleteAll();
      
      // 3. Perform batch insert with unique local IDs
      await dbService.batchInsertProducts(products);
    }
    
    return products.length;
  }
}
