import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ErpService {
  static const String _baseUrl = "https://aurexerp.com/api/v1"; // Replace with actual ERP API URL
  final String _apiKey = "YOUR_API_KEY"; // Replace with your secure API key

  /// Fetches live product data from Aurex ERP using a scanned code.
  Future<Product?> fetchProductFromErp(String code) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/products/$code"),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
          "Tenant-ID": "lafi_al_harbi_group", // Tenant context
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Product(
          productCode: code,
          name: data['name'] ?? "ERP Product",
          category: data['category'],
          warehouseName: data['default_warehouse'],
          companyId: "bin_awf",
        );
      }
    } catch (e) {
      print("ERP Connection Error: $e");
    }
    return null;
  }

  /// Pushes scanned data directly to the main ERP website.
  Future<bool> pushToErp(Product product) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/scans/sync"),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode(product.toMap()),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
