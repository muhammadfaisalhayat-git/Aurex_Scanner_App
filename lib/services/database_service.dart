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
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, productCode TEXT, name TEXT, mfgDate TEXT, expDate TEXT, quantity TEXT, size TEXT, category TEXT, imagePath TEXT, warehouseName TEXT, barcode TEXT, isSynced INTEGER, groupId TEXT, companyId TEXT)",
        );
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
