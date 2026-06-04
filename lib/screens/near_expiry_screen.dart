import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../widgets/product_card.dart';
import '../utils/date_utils.dart';
import 'result_screen.dart';

class NearExpiryScreen extends StatefulWidget {
  const NearExpiryScreen({super.key});

  @override
  State<NearExpiryScreen> createState() => _NearExpiryScreenState();
}

class _NearExpiryScreenState extends State<NearExpiryScreen> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadFilteredProducts();
  }

  void _loadFilteredProducts() {
    setState(() {
      _productsFuture = Provider.of<DatabaseService>(context, listen: false).getProducts().then((list) {
        return list.where((p) {
          if (p.expDate == null) return false;
          final days = AppDateUtils.calculateRemainingDays(p.expDate);
          return days <= 30; // Near expiry: 30 days or already expired
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Near Expiry Products"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text("No products expiring soon."));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              return ProductCard(
                product: products[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(product: products[index]),
                    ),
                  ).then((_) => _loadFilteredProducts());
                },
              );
            },
          );
        },
      ),
    );
  }
}
