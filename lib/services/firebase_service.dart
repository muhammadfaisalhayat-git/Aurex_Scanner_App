import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/product.dart';
import 'database_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Path: groups/lafi_al_harbi_group/companies/bin_awf/products
  DatabaseReference get _productRef {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _db.ref("users/${user.uid}/products");
  }

  Future<void> backupAll(List<Product> products) async {
    Map<String, dynamic> updates = {};
    for (var product in products) {
      String key = product.productCode.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      if (key.isEmpty) key = "ID_${product.id}";
      updates[key] = product.toMap();
    }
    await _productRef.update(updates);
  }

  Future<int> restoreAll() async {
    final snapshot = await _productRef.get();
    if (!snapshot.exists) return 0;

    final dbService = DatabaseService();
    int count = 0;

    if (snapshot.value is Map) {
      Map<dynamic, dynamic> data = snapshot.value as Map;
      for (var entry in data.entries) {
        Product p = Product.fromMap(entry.value);
        await dbService.insertProduct(p);
        count++;
      }
    }
    return count;
  }
}
