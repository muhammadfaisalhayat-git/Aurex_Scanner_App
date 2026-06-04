import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../widgets/action_button.dart';
import '../widgets/app_drawer.dart';
import 'product_list_screen.dart';
import 'scanner_screen.dart';
import 'near_expiry_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import '../widgets/premium_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<int> _getNearExpiryCount(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final products = await db.getProducts();
    final now = DateTime.now();
    final format = DateFormat('dd/MM/yyyy');
    
    return products.where((p) {
      if (p.expDate == null) return false;
      try {
        final exp = format.parse(p.expDate!);
        return exp.difference(now).inDays <= 30;
      } catch (_) {
        return false;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF388E3C);
    const secondaryGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Aurex Scanner", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400)),
        backgroundColor: primaryGreen,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.home, color: Colors.white),
          ),
          FutureBuilder<int>(
            future: _getNearExpiryCount(context),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NearExpiryScreen()),
                      );
                    },
                    icon: const Icon(Icons.notifications, color: Colors.white),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              "Bin Awf Agricultural",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Search name, date, cat...",
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                    prefixIcon: Icon(Icons.search, color: Colors.grey, size: 28),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Image.asset(
              'assets/logos/bin_awf_logo.png',
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.eco,
                size: 150,
                color: secondaryGreen,
              ),
            ),
            const SizedBox(height: 60),
            
            ActionButton(
              text: "SCAN PRODUCT",
              color: secondaryGreen,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );
              },
            ),
            ActionButton(
              text: "ADMIN DASHBOARD",
              color: const Color(0xFF607D8B),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                );
              },
            ),
            ActionButton(
              text: "NEAR EXPIRY PRODUCTS",
              color: const Color(0xFFFFA000),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NearExpiryScreen()),
                );
              },
            ),
            
            // Custom style for Product List button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProductListScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: secondaryGreen, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "PRODUCT LIST",
                    style: TextStyle(
                      color: secondaryGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              "A Project of Aurex ERP",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
