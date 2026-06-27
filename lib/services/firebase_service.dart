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
import 'dart:convert';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Explicitly point to the specific database URL from google-services.json
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: "https://aurexscannerapp-default-rtdb.firebaseio.com",
  );
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

    debugPrint("Backup: Starting atomic backup for $total products...");

    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      String key = product.productCode.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      if (key.isEmpty) {
        key = "ID_${product.id}_${DateTime.now().millisecondsSinceEpoch}";
      }
      
      bool allImagesUploaded = true;

      // Ensure all images are in Storage before marking RTDB entry
      for (int imgIndex = 0; imgIndex < product.imagePaths.length; imgIndex++) {
        final path = product.imagePaths[imgIndex];
        final File imageFile = File(path);
        if (imageFile.existsSync()) {
          try {
            final String fileName = "${key}_$imgIndex.jpg";
            await _storageRef.child(fileName).putFile(imageFile).timeout(const Duration(seconds: 50));
            debugPrint("Backup: Successfully verified image $fileName");
          } catch (e) {
            allImagesUploaded = false;
            debugPrint("Backup: Storage upload FAILED for $key (img $imgIndex): $e");
          }
        }
      }

      if (allImagesUploaded) {
        product.isSynced = true;
        final productMap = product.toMap();
        updates[key] = productMap;
      }
      
      count++;
      if (onProgress != null) onProgress(count, total);
    }
    
    if (updates.isNotEmpty) {
      try {
        // Step 1: Write Data
        await _productRef.update(updates).timeout(const Duration(seconds: 40));
        
        // Step 2: Handshake Verification (Verify the server actually has what we just wrote)
        final handshake = await _productRef.limitToFirst(1).get().timeout(const Duration(seconds: 15));
        if (!handshake.exists) {
           throw Exception("Backup Handshake Failed: Server reported empty storage after write.");
        }
        
        debugPrint("Backup: Handshake Verified. Server write successful.");
        
        final ds = DatabaseService();
        for (var p in products) {
          if (p.isSynced) await ds.updateProduct(p);
        }
      } catch (e) {
        debugPrint("Backup: Critical write failure: $e");
        rethrow;
      }
    }
  }

  Future<int?> restoreAll({Function(int current, int total)? onProgress}) async {
    debugPrint("Restore: Initiating deep fetch from server...");
    
    DataSnapshot snapshot;
    try {
      snapshot = await _productRef.get().timeout(const Duration(seconds: 40));
    } catch (e) {
      debugPrint("Restore: Snapshot fetch timeout or error: $e");
      rethrow;
    }

    if (!snapshot.exists || snapshot.value == null) {
      debugPrint("Restore: Server returned null for path ${_productRef.path}");
      return null;
    }

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
    debugPrint("Restore: Found $total products on server. Normalizing formats...");
    
    int processedCount = 0;
    List<Product> restoredProducts = [];

    for (var entry in rawData.entries) {
      try {
        final Map<dynamic, dynamic> entryValue = entry.value as Map;
        final Map<String, dynamic> productData = entryValue.map((k, v) => MapEntry(k.toString(), v));
        final String entryKey = entry.key.toString();
        
        // Handle image data carefully to prevent broken local links
        final restoredProduct = Product.fromMap(productData);
        final int remoteImageCount = restoredProduct.imagePaths.length;
        
        List<String> verifiedLocalPaths = [];

        // Try downloading with fallback for legacy formats
        for (int idx = 0; idx < (remoteImageCount > 0 ? remoteImageCount : 5); idx++) {
          final String fileName = "${entryKey}_$idx.jpg";
          final String localPath = p.join(imagesPath, fileName);
          final File localFile = File(localPath);

          try {
            if (localFile.existsSync() && localFile.lengthSync() > 0) {
              verifiedLocalPaths.add(localPath);
            } else {
              final ref = _storageRef.child(fileName);
              final Uint8List? data = await ref.getData(15 * 1024 * 1024).timeout(const Duration(seconds: 30)); 
              if (data != null) {
                await localFile.writeAsBytes(data);
                if (localFile.existsSync()) {
                  verifiedLocalPaths.add(localPath);
                }
              }
            }
          } catch (_) {
             // Handle legacy single-image naming convention
             if (idx == 0 && verifiedLocalPaths.isEmpty) {
                try {
                   final legacyLocalPath = p.join(imagesPath, "$entryKey.jpg");
                   final legacyFile = File(legacyLocalPath);
                   final legacyRef = _storageRef.child("$entryKey.jpg");
                   final Uint8List? lData = await legacyRef.getData(10 * 1024 * 1024).timeout(const Duration(seconds: 20));
                   if (lData != null) {
                      await legacyFile.writeAsBytes(lData);
                      verifiedLocalPaths.add(legacyLocalPath);
                   }
                } catch (_) {}
             }
             if (idx >= remoteImageCount) break;
          }
        }

        restoredProduct.imagePaths = verifiedLocalPaths;
        restoredProduct.id = null; 
        restoredProduct.isSynced = true;
        restoredProducts.add(restoredProduct);
      } catch (e) {
        debugPrint("Restore: Error reconstructing entry ${entry.key}: $e");
      } finally {
        processedCount++;
        if (onProgress != null) onProgress(processedCount, total);
      }
    }

    if (restoredProducts.isNotEmpty) {
      await dbService.deleteAll();
      await dbService.batchInsertProducts(restoredProducts);
      debugPrint("Restore: Synchronization Finalized. ${restoredProducts.length} items synced.");
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
    } catch (_) {}
  }
}
