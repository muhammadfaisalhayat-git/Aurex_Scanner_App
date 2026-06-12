import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart';
import '../services/locale_provider.dart';
import '../screens/login_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/scanner_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/settings_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context);
    
    const primaryGreen = Color(0xFF388E3C);
    const itemBgColor = Color(0xFFF1F8E9);
    final isAr = localeProvider.locale.languageCode == 'ar';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: primaryGreen,
            padding: const EdgeInsets.only(top: 50, bottom: 30),
            child: Column(
              children: [
                Text(
                  isAr ? "بن عوف الزراعية" : "Bin Awf Agricultural",
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),
                Image.asset(
                  'assets/logos/bin_awf_logo.png',
                  height: 110,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.eco, color: Colors.white, size: 80),
                ),
                const SizedBox(height: 25),
                Text(
                  user?.email ?? "admin@aurex.com",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildDrawerItem(context, Icons.camera_alt_outlined, isAr ? "مسح المنتج" : "Scan Product", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.access_time, isAr ? "قائمة المنتجات" : "Product List", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductListScreen()));
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.lock_outline, isAr ? "لوحة تحكم المسؤول" : "Admin Dashboard", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.save_outlined, isAr ? "نسخ احتياطي للخادم" : "Backup to Server", () async {
                  final fs = Provider.of<FirebaseService>(context, listen: false);
                  final ds = Provider.of<DatabaseService>(context, listen: false);
                  
                  Navigator.pop(context); // Close drawer
                  
                  final products = await ds.getProducts();
                  if (products.isEmpty) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? "لا توجد بيانات للنسخ الاحتياطي" : "No local data to backup")));
                    return;
                  }
                  
                  _showGlobalProgressDialog(context, isAr ? "نسخ احتياطي" : "Backup", isAr ? "جاري النسخ..." : "Backing up...", (onProgressUpdate) async {
                    await fs.backupAll(products, onProgress: (current, total) => onProgressUpdate(current, total));
                    return true;
                  });
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.download_outlined, isAr ? "استعادة من الخادم" : "Restore from Server", () {
                  final fs = Provider.of<FirebaseService>(context, listen: false);
                  Navigator.pop(context); // Close drawer
                  
                  _showGlobalProgressDialog(context, isAr ? "استعادة" : "Restore", isAr ? "جاري الاستعادة..." : "Restoring data...", (onProgressUpdate) async {
                    int? count = await fs.restoreAll(onProgress: (current, total) => onProgressUpdate(current, total));
                    return count;
                  });
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.language, isAr ? "English" : "العربية", () => localeProvider.toggleLocale(), itemBgColor),
                
                _buildDrawerItem(context, Icons.settings_outlined, isAr ? "الإعدادات" : "Settings", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                }, itemBgColor),
                
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, top: 25, bottom: 10),
                  child: Text("Account", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                
                _buildDrawerItem(context, Icons.power_settings_new, isAr ? "تسجيل الخروج" : "Sign Out", () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }, itemBgColor, iconColor: Colors.green),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              isAr ? "v1.0.0 - إصدار بن عوف" : "v1.0.0 - Bin Awf Edition", 
              style: const TextStyle(color: Colors.grey, fontSize: 12)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap, Color bgColor, {Color iconColor = const Color(0xFF388E3C)}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        onTap: onTap,
        dense: false,
      ),
    );
  }

  void _showGlobalProgressDialog(BuildContext context, String actionType, String title, Future<dynamic> Function(Function(int, int)) task) {
    final progressNotifier = ValueNotifier<double>(0);
    final statusNotifier = ValueNotifier<String>("Connecting...");
    bool isDialogVisible = true;
    
    // Capture root navigator BEFORE drawer is closed or context becomes unmounted
    final NavigatorState rootNavigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, value, child) => LinearProgressIndicator(
                  value: (value > 0 && value < 1.0) ? value : (value >= 1.0 ? 1.0 : null),
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (context, status, child) => Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () { 
                   isDialogVisible = false;
                   Navigator.of(dialogContext).pop(); 
                },
                child: const Text("RUN IN BACKGROUND"),
              ),
            ],
          ),
        );
      },
    );

    Future(() async {
      try {
        final result = await task((c, t) {
          if (t > 0) {
            progressNotifier.value = c / t;
            statusNotifier.value = "$c / $t processed";
          }
        });
        
        await Future.delayed(const Duration(milliseconds: 600));

        // 1. Close progress dialog using the CAPTURED root navigator
        if (isDialogVisible) {
          rootNavigator.pop();
          isDialogVisible = false;
        }
        
        // 2. Show Success Popup (Informing the user)
        // Use a small delay to ensure the previous pop finished
        await Future.delayed(const Duration(milliseconds: 200));
        
        showDialog(
          context: rootNavigator.context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                Text("$actionType Complete"),
              ],
            ),
            content: Text(result is int ? "Successfully restored $result products." : "Task completed successfully."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
            ],
          ),
        );
      } catch (e) {
        if (isDialogVisible) {
          rootNavigator.pop();
          isDialogVisible = false;
        }
        showDialog(
          context: rootNavigator.context,
          builder: (ctx) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      }
    });
  }
}
