import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../widgets/product_card.dart';
import '../utils/date_utils.dart';
import 'result_screen.dart';
import '../l10n/app_localizations.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();
  
  // Filter states
  String? _selectedCategory;
  String? _selectedWarehouse;
  bool _isExpiryFilterActive = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await Provider.of<DatabaseService>(context, listen: false).getProducts();
    setState(() {
      _allProducts = products;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        // 1. Search filter
        final matchesSearch = p.name.toLowerCase().contains(query) || 
                             p.productCode.toLowerCase().contains(query) ||
                             (p.category?.toLowerCase().contains(query) ?? false);
        
        // 2. Category filter
        final matchesCategory = _selectedCategory == null || p.category == _selectedCategory;
        
        // 3. Warehouse filter
        final matchesWarehouse = _selectedWarehouse == null || p.warehouseName == _selectedWarehouse;
        
        // 4. Expiry filter (Items expiring in next 30 days or already expired)
        bool matchesExpiry = true;
        if (_isExpiryFilterActive) {
          if (p.expDate == null) {
            matchesExpiry = false;
          } else {
            final days = AppDateUtils.calculateRemainingDays(p.expDate);
            matchesExpiry = days <= 30;
          }
        }

        return matchesSearch && matchesCategory && matchesWarehouse && matchesExpiry;
      }).toList();
    });
  }

  void _showCategoryPicker() {
    final l10n = AppLocalizations.of(context)!;
    final categories = _allProducts
        .map((p) => p.category ?? "General")
        .toSet()
        .toList();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(l10n.allCategories, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              setState(() => _selectedCategory = null);
              _applyFilters();
              Navigator.pop(context);
            },
          ),
          ...categories.map((c) => ListTile(
            title: Text(c),
            onTap: () {
              setState(() => _selectedCategory = c);
              _applyFilters();
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }

  void _showWarehousePicker() {
    final l10n = AppLocalizations.of(context)!;
    final warehouses = _allProducts
        .where((p) => p.warehouseName != null && p.warehouseName!.isNotEmpty)
        .map((p) => p.warehouseName!)
        .toSet()
        .toList();
    
    if (warehouses.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No warehouse data found")));
       return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(l10n.allWarehouses, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              setState(() => _selectedWarehouse = null);
              _applyFilters();
              Navigator.pop(context);
            },
          ),
          ...warehouses.map((w) => ListTile(
            title: Text(w),
            onTap: () {
              setState(() => _selectedWarehouse = w);
              _applyFilters();
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF388E3C);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryGreen, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadProducts, 
            icon: const Icon(Icons.refresh, color: primaryGreen)
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildFilters(),
          const SizedBox(height: 10),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filteredProducts.isEmpty)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text(l10n.noProductsMatch, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                TextButton(onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                    _selectedWarehouse = null;
                    _isExpiryFilterActive = false;
                    _searchController.clear();
                  });
                  _applyFilters();
                }, child: Text(l10n.clearAllFilters))
              ],
            )))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  return ProductCard(
                    product: _filteredProducts[index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ResultScreen(product: _filteredProducts[index])),
                      ).then((_) => _loadProducts());
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(l10n.filter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: _selectedCategory ?? l10n.category, 
              icon: Icons.grid_view,
              isActive: _selectedCategory != null,
              onTap: _showCategoryPicker,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: _selectedWarehouse ?? l10n.warehouse, 
              icon: Icons.warehouse,
              isActive: _selectedWarehouse != null,
              onTap: _showWarehousePicker,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: l10n.nearExpiry,
              icon: Icons.timer_outlined,
              isActive: _isExpiryFilterActive,
              onTap: () {
                setState(() => _isExpiryFilterActive = !_isExpiryFilterActive);
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label, 
    required IconData icon, 
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final primaryGreen = const Color(0xFF388E3C);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primaryGreen.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? primaryGreen : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? primaryGreen : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              label, 
              style: TextStyle(
                fontSize: 13, 
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? primaryGreen : Colors.black87,
              )
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF388E3C)),
            ]
          ],
        ),
      ),
    );
  }
}
