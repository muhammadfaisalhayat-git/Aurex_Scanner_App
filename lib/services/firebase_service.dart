import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import 'database_service.dart';
import 'dart:io';
import 'dart:async';

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

  Future<String> _getImagesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final String path = p.join(directory.path, 'product_images');
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<void> backupAll(List<Product> products, {Function(int current, int total)? onProgress}) async {
    final int total = products.length;
    int count = 0;
    Map<String, dynamic> updates = {};

    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      String key = product.productCode.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      if (key.isEmpty) key = "ID_${product.id}_${DateTime.now().millisecondsSinceEpoch}";
      
      bool allImagesUploaded = true;

      // Handle multiple images
      for (int imgIndex = 0; imgIndex < product.imagePaths.length; imgIndex++) {
        final path = product.imagePaths[imgIndex];
        final File imageFile = File(path);
        if (imageFile.existsSync()) {
          try {
            final String fileName = "${key}_$imgIndex.jpg";
            await _storageRef.child(fileName).putFile(imageFile).timeout(const Duration(seconds: 30));
            debugPrint("Backup: Successfully uploaded image $fileName");
          } catch (e) {
            allImagesUploaded = false;
            debugPrint("Backup: Storage upload FAILED for $key (img $imgIndex): $e");
          }
        }
      }

      if (allImagesUploaded) {
        product.isSynced = true;
        final productMap = product.toMap();
        // The imagePaths are stored as a JSON string in toMap
        updates[key] = productMap;
      }
      
      count++;
      if (onProgress != null) onProgress(count, total);
    }
    
    if (updates.isNotEmpty) {
      await _productRef.update(updates).timeout(const Duration(seconds: 20));
      final ds = DatabaseService();
      for (var p in products) {
        if (p.isSynced) await ds.updateProduct(p);
      }
    }
  }

  Future<int?> restoreAll({Function(int current, int total)? onProgress}) async {
    final snapshot = await _productRef.get().timeout(const Duration(seconds: 20));
    if (!snapshot.exists || snapshot.value == null) return null;

    final dbService = DatabaseService();
    final String imagesPath = await _getImagesDirectory();

    Map<dynamic, dynamic> rawData = {};
    if (snapshot.value is Map) {
      rawData = snapshot.value as Map;
    } else if (snapshot.value is List) {
      final list = snapshot.value as List;
      for (int i = 0; i < list.length; i++) {
        if (list[i] != null) rawData[i.toString()] = list[i];
      }
    }

    final int total = rawData.length;
    int processedCount = 0;
    List<Product> restoredProducts = [];

    for (var entry in rawData.entries) {
      try {
        final productData = Map<String, dynamic>.from(entry.value as Map);
        final String entryKey = entry.key.toString();
        
        // Handle multiple images from cloud
        List<String> localPaths = [];
        
        // We attempt to download images based on a standard naming convention
        // since we don't know the exact count in advance easily without storing metadata,
        // or we can store the count.
        // Actually, the Product.fromMap already tries to parse imagePaths from the JSON string.
        final restoredProduct = Product.fromMap(productData);
        final List<String> remotePaths = restoredProduct.imagePaths;

        for (int idx = 0; idx < remotePaths.length || idx < 5; idx++) {
          final String fileName = "${entryKey}_$idx.jpg";
          final String localPath = p.join(imagesPath, fileName);
          final File localFile = File(localPath);

          try {
            final ref = _storageRef.child(fileName);
            if (localFile.existsSync() && localFile.lengthSync() > 0) {
              localPaths.add(localPath);
            } else {
              final Uint8List? data = await ref.getData(15 * 1024 * 1024).timeout(const Duration(seconds: 10)); 
              if (data != null) {
                await localFile.writeAsBytes(data);
                if (localFile.existsSync()) {
                  localPaths.add(localPath);
                }
              }
            }
          } catch (_) {
             // If idx > remotePaths.length and fails, it means we've reached the end of available images
             if (idx >= (remotePaths.isNotEmpty ? remotePaths.length : 1)) break;
          }
        }

        restoredProduct.imagePaths = localPaths;
        restoredProduct.id = null; 
        restoredProduct.isSynced = true;
        restoredProducts.add(restoredProduct);
      } catch (e) {
        debugPrint("Restore: Error parsing entry: $e");
      } finally {
        processedCount++;
        if (onProgress != null) onProgress(processedCount, total);
      }
    }

    if (restoredProducts.isNotEmpty) {
      await dbService.deleteAll();
      await dbService.batchInsertProducts(restoredProducts);
    }
    
    return restoredProducts.length;
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
