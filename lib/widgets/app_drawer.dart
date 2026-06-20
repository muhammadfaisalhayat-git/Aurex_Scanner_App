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
import '../l10n/app_localizations.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    final primary = theme.colorScheme.primary;
    final itemBgColor = isDark ? Colors.grey.shade900 : const Color(0xFFF1F8E9);
    final isAr = localeProvider.locale.languageCode == 'ar';

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: isDark ? theme.colorScheme.surface : primary,
            padding: const EdgeInsets.only(top: 50, bottom: 30),
            child: Column(
              children: [
                Text(
                  l10n.companyName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/logos/bin_awf_logo.png',
                    height: 90,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.eco, color: primary, size: 60),
                  ),
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
                _buildDrawerItem(context, Icons.camera_alt_outlined, l10n.scanProduct, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.access_time, l10n.productList, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductListScreen()));
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.lock_outline, l10n.adminDashboard, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.save_outlined, l10n.backupToServer, () async {
                  final ds = Provider.of<DatabaseService>(context, listen: false);
                  Navigator.pop(context); 
                  final products = await ds.getProducts();
                  if (products.isEmpty) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noProductsFound)));
                    return;
                  }
                  _showGlobalProgressDialog(context, l10n.backupToServer, l10n.backupToServer, (onProgressUpdate) async {
                    final fs = Provider.of<FirebaseService>(context, listen: false);
                    await fs.backupAll(products, onProgress: (current, total) => onProgressUpdate(current, total));
                    return true;
                  });
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.download_outlined, l10n.restoreFromCloud, () {
                  Navigator.pop(context); 
                  _showGlobalProgressDialog(context, l10n.restoreFromCloud, l10n.restoreFromCloud, (onProgressUpdate) async {
                    final fs = Provider.of<FirebaseService>(context, listen: false);
                    int? count = await fs.restoreAll(onProgress: (current, total) => onProgressUpdate(current, total));
                    return count;
                  });
                }, itemBgColor),
                
                _buildDrawerItem(context, Icons.language, isAr ? "English" : "العربية", () => localeProvider.toggleLocale(), itemBgColor),
                
                _buildDrawerItem(context, Icons.settings_outlined, l10n.settings, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                }, itemBgColor),
                
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 25, bottom: 10),
                  child: Text(l10n.account, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16)),
                ),
                
                _buildDrawerItem(context, Icons.power_settings_new, l10n.logout, () async {
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
              l10n.versionEdition, 
              style: TextStyle(color: isDark ? Colors.white24 : Colors.grey, fontSize: 12)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap, Color bgColor, {Color iconColor = const Color(0xFF388E3C)}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.transparent),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDark ? theme.colorScheme.primary : iconColor, size: 28),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
        onTap: onTap,
        dense: false,
      ),
    );
  }

  void _showGlobalProgressDialog(BuildContext context, String actionType, String title, Future<dynamic> Function(Function(int, int)) task) {
    final progressNotifier = ValueNotifier<double>(0);
    final statusNotifier = ValueNotifier<String>("Connecting...");
    bool isDialogVisible = true;
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
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (context, status, child) => Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        if (isDialogVisible) { rootNavigator.pop(); isDialogVisible = false; }
        
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
            content: Text(result is int ? "Successfully processed $result items." : "Task completed successfully."),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      } catch (e) {
        if (isDialogVisible) { rootNavigator.pop(); isDialogVisible = false; }
        showDialog(
          context: rootNavigator.context,
          builder: (ctx) => AlertDialog(title: const Text("Error"), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]),
        );
      }
    });
  }
}
