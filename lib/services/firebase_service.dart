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

  // Base storage reference for products
  Reference get _baseStorageRef => _storage.ref().child("products");

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

    debugPrint("Backup: Starting atomic hierarchical backup for $total products...");

    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      String safeProductCode = product.productCode.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      if (safeProductCode.isEmpty) {
        safeProductCode = "ID_${product.id}_${DateTime.now().millisecondsSinceEpoch}";
      }
      
      bool allImagesUploaded = true;
      List<String> cloudRelativePaths = [];

      // Organize images in nested folders: products/{productId}/images/{index}.jpg
      for (int imgIndex = 0; imgIndex < product.imagePaths.length; imgIndex++) {
        final path = product.imagePaths[imgIndex];
        final File imageFile = File(path);
        
        if (imageFile.existsSync()) {
          try {
            final String cloudPath = "$safeProductCode/images/$imgIndex.jpg";
            await _baseStorageRef.child(cloudPath).putFile(imageFile).timeout(const Duration(seconds: 50));
            cloudRelativePaths.add(cloudPath);
            debugPrint("Backup: Verified hierarchical image $cloudPath");
          } catch (e) {
            allImagesUploaded = false;
            debugPrint("Backup: Storage upload FAILED for $safeProductCode (img $imgIndex): $e");
          }
        }
      }

      if (allImagesUploaded) {
        product.isSynced = true;
        final productMap = product.toMap();
        
        // We store the RELATIVE paths from the 'products' root in the DB for portability
        // This replaces the local absolute paths used on the device.
        productMap['imagePath'] = json.encode(cloudRelativePaths);
        
        updates[safeProductCode] = productMap;
      }
      
      count++;
      if (onProgress != null) onProgress(count, total);
    }
    
    if (updates.isNotEmpty) {
      try {
        await _productRef.update(updates).timeout(const Duration(seconds: 40));
        
        // Handshake Verification
        final handshake = await _productRef.limitToFirst(1).get().timeout(const Duration(seconds: 15));
        if (!handshake.exists) {
           throw Exception("Backup Handshake Failed: Server reported empty storage after write.");
        }
        
        debugPrint("Backup: Hierarchical Handshake Verified.");
        
        final ds = DatabaseService();
        for (var p in products) {
          if (p.isSynced) await ds.updateProduct(p);
        }
      } catch (e) {
        debugPrint("Backup: Critical hierarchical write failure: $e");
        rethrow;
      }
    }
  }

  Future<int?> restoreAll({Function(int current, int total)? onProgress}) async {
    debugPrint("Restore: Initiating deep hierarchical fetch from server...");
    
    DataSnapshot snapshot;
    try {
      snapshot = await _productRef.get().timeout(const Duration(seconds: 45));
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
    debugPrint("Restore: Found $total products. Reconstructing hierarchy...");
    
    int processedCount = 0;
    List<Product> restoredProducts = [];

    for (var entry in rawData.entries) {
      try {
        final Map<dynamic, dynamic> entryValue = entry.value as Map;
        final Map<String, dynamic> productData = entryValue.map((k, v) => MapEntry(k.toString(), v));
        final String entryKey = entry.key.toString();
        
        final restoredProduct = Product.fromMap(productData);
        final List<String> remotePaths = restoredProduct.imagePaths;
        
        List<String> verifiedLocalPaths = [];

        // HIERARCHICAL RESTORATION
        for (int idx = 0; idx < remotePaths.length; idx++) {
          final String remoteRelativePath = remotePaths[idx];
          
          // Determine local filename - we use the entry key and index to keep it unique
          final String localFileName = "${entryKey}_$idx.jpg";
          final String localPath = p.join(imagesPath, localFileName);
          final File localFile = File(localPath);

          try {
            if (localFile.existsSync() && localFile.lengthSync() > 0) {
              verifiedLocalPaths.add(localPath);
            } else {
              // Try downloading from the relative path stored in the DB
              Reference imgRef;
              if (remoteRelativePath.contains('/')) {
                // New Hierarchical format: "prod_123/images/0.jpg"
                imgRef = _baseStorageRef.child(remoteRelativePath);
              } else {
                // Legacy Fallback: "old_image_name.jpg" or the key itself
                imgRef = _storage.ref().child("users/${_auth.currentUser?.uid}/images/$remoteRelativePath");
              }

              final Uint8List? data = await imgRef.getData(15 * 1024 * 1024).timeout(const Duration(seconds: 30)); 
              if (data != null) {
                await localFile.writeAsBytes(data);
                if (localFile.existsSync()) {
                  verifiedLocalPaths.add(localPath);
                  debugPrint("Restore: Downloaded $localFileName from hierarchical path");
                }
              }
            }
          } catch (e) {
            debugPrint("Restore: Failed to fetch image $idx for $entryKey: $e");
          }
        }

        // Final local verification
        restoredProduct.imagePaths = verifiedLocalPaths;
        restoredProduct.id = null; 
        restoredProduct.isSynced = true;
        restoredProducts.add(restoredProduct);
      } catch (e) {
        debugPrint("Restore: Error reconstructing hierarchical entry ${entry.key}: $e");
      } finally {
        processedCount++;
        if (onProgress != null) onProgress(processedCount, total);
      }
    }

    if (restoredProducts.isNotEmpty) {
      await dbService.deleteAll();
      await dbService.batchInsertProducts(restoredProducts);
      debugPrint("Restore: Hierarchical Sync Finalized. ${restoredProducts.length} items synced.");
    }
    
    return restoredProducts.length;
  }

  Future<void> wipeDataFromServer() async {
    debugPrint("Wipe: Deleting all user data and hierarchical images...");
    await _productRef.remove();
    // Note: We don't wipe the entire 'products' root because it might contain data for other users
    // In a production app, we would list only the subfolders belonging to this user's products.
  }
}
