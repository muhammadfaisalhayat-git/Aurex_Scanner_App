import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF5E7D6A)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF5E7D6A), size: 40),
            ),
            accountName: const Text("Bin Awf operator", style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(user?.email ?? "no-email@aurexerp.com"),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Color(0xFF5E7D6A)),
            title: const Text("Backup to Server"),
            onTap: () async {
              Navigator.pop(context);
              _showProgressDialog(context, "Backing up...");
              try {
                final products = await dbService.getProducts();
                await firebaseService.backupAll(products);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup Successful")));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Backup Failed: $e")));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download, color: Color(0xFF5E7D6A)),
            title: const Text("Restore from Cloud"),
            onTap: () async {
              Navigator.pop(context);
              _showProgressDialog(context, "Restoring data...");
              try {
                int count = await firebaseService.restoreAll();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restored $count products")));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restore Failed: $e")));
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("v1.0.0 - Bin Awf Edition", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }
}
