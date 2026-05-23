import 'package:flutter/material.dart';
import '../widgets/premium_card.dart';
import '../widgets/action_button.dart';
import '../widgets/app_drawer.dart';
import 'product_list_screen.dart';
import 'scanner_screen.dart';
import 'near_expiry_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aurex Scanner", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E7D6A),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications, color: Colors.white)),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Bin Awf Agricultural",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search name, date, category...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.business, size: 100, color: Color(0xFF5E7D6A)),
            const SizedBox(height: 24),

            const PremiumCard(
              title: "Premium Insights",
              child: Column(
                children: [
                  Text("Stocks Health - Active"),
                ],
              ),
            ),

            const SizedBox(height: 24),
            ActionButton(
              text: "SCAN PRODUCT",
              color: const Color(0xFF2E7D32),
              icon: Icons.camera_alt,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );
              },
            ),
            ActionButton(
              text: "ADMIN DASHBOARD",
              color: const Color(0xFF455A64),
              icon: Icons.admin_panel_settings,
              onPressed: () {
                // Future implementation for Admin
              },
            ),
            ActionButton(
              text: "NEAR EXPIRY PRODUCTS",
              color: const Color(0xFFC67100),
              icon: Icons.history,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NearExpiryScreen()),
                );
              },
            ),
            ActionButton(
              text: "PRODUCT LIST",
              color: const Color(0xFFEEEEEE),
              textColor: Colors.black,
              icon: Icons.list,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProductListScreen()),
                );
              },
            ),

            const SizedBox(height: 40),
            const Text("A Project of Aurex ERP", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
