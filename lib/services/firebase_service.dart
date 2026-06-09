import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import 'database_service.dart';
import 'dart:io';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DatabaseReference get _productRef {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _db.ref("users/${user.uid}/products");
  }

  Reference get _storageRef {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _storage.ref().child("users/${user.uid}/images");
  }

  Future<void> backupAll(List<Product> products, {Function(int current, int total)? onProgress}) async {
    Map<String, dynamic> updates = {};
    final int total = products.length;
    int count = 0;

    for (var product in products) {
      String key = product.productCode.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      if (key.isEmpty) key = "ID_${product.id}";
      
      // Upload image to Firebase Storage
      if (product.imagePath != null && File(product.imagePath!).existsSync()) {
        try {
          final File imageFile = File(product.imagePath!);
          final String fileName = "$key.jpg";
          await _storageRef.child(fileName).putFile(imageFile);
        } catch (e) {
          debugPrint("Storage upload error for $key: $e");
        }
      }

      product.isSynced = true;
      updates[key] = product.toMap();
      
      count++;
      if (onProgress != null) onProgress(count, total);
    }
    
    await _productRef.update(updates);
  }

  Future<int?> restoreAll({Function(int current, int total)? onProgress}) async {
    final snapshot = await _productRef.get();
    if (!snapshot.exists || snapshot.value == null) return null;

    final dbService = DatabaseService();
    final directory = await getApplicationDocumentsDirectory();
    final String imagesPath = p.join(directory.path, 'product_images');
    
    // Ensure the product_images directory exists
    final imagesDir = Directory(imagesPath);
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    List<Product> products = [];

    if (snapshot.value is Map) {
      final Map<dynamic, dynamic> data = snapshot.value as Map;
      final int total = data.length;
      int count = 0;
      
      for (var entry in data.entries) {
        try {
          final productData = Map<dynamic, dynamic>.from(entry.value as Map);
          String key = entry.key.toString();
          
          // Try to download image from storage
          final String localImagePath = p.join(imagesPath, "$key.jpg");
          final File localFile = File(localImagePath);
          
          try {
            // Check if it exists on server first to avoid generic error noise
            final metadata = await _storageRef.child("$key.jpg").getMetadata();
            if (metadata.size != null && metadata.size! > 0) {
              await _storageRef.child("$key.jpg").writeToFile(localFile);
              productData['imagePath'] = localImagePath;
            }
          } catch (e) {
            debugPrint("Image not found or download failed for $key: $e");
          }

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
      await dbService.deleteAll();
      await dbService.batchInsertProducts(products);
    }
    
    return products.length;
  }

  Future<void> wipeDataFromServer() async {
    await _productRef.remove();
    try {
      final listResult = await _storageRef.listAll();
      for (var item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      debugPrint("Storage wipe error: $e");
    }
  }
}
