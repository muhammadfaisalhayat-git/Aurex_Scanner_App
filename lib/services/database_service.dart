import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'aurex_scanner.db');
    return await openDatabase(
      path,
      version: 3, // Incremented to version 3 to add coordinate columns
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, productCode TEXT, name TEXT, mfgDate TEXT, expDate TEXT, quantity TEXT, size TEXT, category TEXT, imagePath TEXT, warehouseName TEXT, barcode TEXT, isSynced INTEGER, mfgBox TEXT, expBox TEXT, groupId TEXT, companyId TEXT)",
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Add missing columns for highlighting coordinates if they don't exist
          try { await db.execute("ALTER TABLE products ADD COLUMN mfgBox TEXT"); } catch (_) {}
          try { await db.execute("ALTER TABLE products ADD COLUMN expBox TEXT"); } catch (_) {}
        }
      },
    );
  }

  Future<void> insertProduct(Product product) async {
    final db = await database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertProducts(List<Product> products) async {
    final db = await database;
    await db.transaction((txn) async {
      var batch = txn.batch();
      for (var product in products) {
        batch.insert(
          'products',
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: "id DESC");
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('products');
  }
}
