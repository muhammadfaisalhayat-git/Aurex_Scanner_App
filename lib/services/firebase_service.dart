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
      
      bool imageUploaded = true;

      if (product.imagePath != null) {
        final File imageFile = File(product.imagePath!);
        if (imageFile.existsSync()) {
          try {
            final String fileName = "$key.jpg";
            await _storageRef.child(fileName).putFile(imageFile).timeout(const Duration(seconds: 30));
            debugPrint("Backup: Successfully uploaded image $fileName");
          } catch (e) {
            imageUploaded = false;
            debugPrint("Backup: Storage upload FAILED for $key: $e");
          }
        } else {
           debugPrint("Backup: Image file not found locally at ${product.imagePath}");
           // We don't mark as failed if the file literally doesn't exist anymore, 
           // but we should probably update the DB to null.
        }
      }

      if (imageUploaded) {
        product.isSynced = true;
        final productMap = product.toMap();
        // Don't store absolute local paths in the cloud
        productMap['imagePath'] = null; 
        updates[key] = productMap;
      }
      
      count++;
      if (onProgress != null) onProgress(count, total);
    }
    
    if (updates.isNotEmpty) {
      await _productRef.update(updates).timeout(const Duration(seconds: 20));
      // Update local isSynced status
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
        final String localImagePath = p.join(imagesPath, "$entryKey.jpg");
        final File localFile = File(localImagePath);

        productData['imagePath'] = null; 

        try {
          final ref = _storageRef.child("$entryKey.jpg");
          
          // Check if we already have it
          if (localFile.existsSync() && localFile.lengthSync() > 0) {
            productData['imagePath'] = localImagePath;
          } else {
            // Attempt download
            try {
              final Uint8List? data = await ref.getData(15 * 1024 * 1024).timeout(const Duration(seconds: 15)); 
              if (data != null) {
                await localFile.writeAsBytes(data);
                if (localFile.existsSync()) {
                  productData['imagePath'] = localImagePath;
                }
              }
            } catch (e) {
              debugPrint("Restore: No image found or download failed for $entryKey: $e");
            }
          }
        } catch (e) {
          debugPrint("Restore: Storage ref error for $entryKey: $e");
        }

        productData['id'] = null; 
        productData['isSynced'] = 1;
        restoredProducts.add(Product.fromMap(productData));
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
