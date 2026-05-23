import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../widgets/product_card.dart';

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
        final now = DateTime.now();
        final format = DateFormat("dd/MM/yyyy");

        return list.where((p) {
          if (p.expDate == null) return false;
          try {
            final exp = format.parse(p.expDate!);
            final diff = exp.difference(now).inDays;
            return diff <= 30; // Near expiry: 30 days or already expired
          } catch (e) {
            return false;
          }
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
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }
}
