import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import '../widgets/premium_card.dart';
import '../widgets/product_card.dart';
import '../utils/date_utils.dart';
import 'result_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _totalProducts = 0;
  int _expiredCount = 0;
  int _nearExpiryCount = 0;
  List<Product> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final products = await db.getProducts();
    
    int expired = 0, nearExpiry = 0;

    for (var p in products) {
      if (p.expDate != null) {
        final days = AppDateUtils.calculateRemainingDays(p.expDate);
        if (days < 0) expired++; else if (days <= 30) nearExpiry++;
      }
    }
    if (mounted) setState(() { _allProducts = products; _totalProducts = products.length; _expiredCount = expired; _nearExpiryCount = nearExpiry; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF388E3C);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
        leading: const Icon(Icons.grid_view, color: Colors.white),
        actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, color: Colors.white))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(color: Colors.white, child: TabBar(controller: _tabController, labelColor: primaryGreen, unselectedLabelColor: Colors.grey, indicatorColor: primaryGreen, tabs: const [Tab(text: "MANAGE PRODUCTS"), Tab(text: "MANAGE USERS")])),
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_buildManageProductsTab(), _buildManageUsersTab()]),
    );
  }

  Widget _buildManageProductsTab() {
    return _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: _buildStatCard(_totalProducts.toString(), "TOTAL ITEMS", const Color(0xFF2E7D32))),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard(_expiredCount.toString(), "EXPIRED", const Color(0xFFE57373))),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard(_nearExpiryCount.toString(), "NEAR EXPIRY", const Color(0xFFFFB74D))),
          ]),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: PremiumCard(title: "Premium Insights"),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true, 
          physics: const NeverScrollableScrollPhysics(), 
          itemCount: _allProducts.length, 
          itemBuilder: (c, i) => ProductCard(
            product: _allProducts[i], 
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => ResultScreen(product: _allProducts[i]))).then((_) => _loadData());
            }
          ),
        ),
      ]),
    );
  }

  Widget _buildStatCard(String val, String lbl, Color col) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(val, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), Text(lbl, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]));
  }

  Widget _buildManageUsersTab() {
    return Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Expanded(child: Container(height: 45, decoration: BoxDecoration(color: const Color(0xFF9C27B0), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: const Text("0 PENDING APPROVALS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 15),
      const Icon(Icons.add_circle_outline, color: Color(0xFF388E3C), size: 30),
      const Text(" ADD USER", style: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.bold)),
    ]));
  }
}
