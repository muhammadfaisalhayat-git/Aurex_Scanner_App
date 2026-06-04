import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedTheme = "System Default";
  bool _biometricsEnabled = false;
  final _biometricService = BiometricService();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await _biometricService.isBiometricsEnabled();
    setState(() { _biometricsEnabled = enabled; });
  }

  Future<void> _showConfirmPassword(VoidCallback onVerified) async {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Identity"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please enter your current password to continue."),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Current Password", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.green))),
          TextButton(
            onPressed: () async {
              try {
                AuthCredential cred = EmailAuthProvider.credential(email: user!.email!, password: passController.text);
                await user!.reauthenticateWithCredential(cred);
                Navigator.pop(ctx);
                onVerified();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid password")));
              }
            },
            child: const Text("VERIFY", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF388E3C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
        leading: const Icon(Icons.grid_view, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Theme", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            RadioListTile(title: const Text("System Default"), value: "System Default", groupValue: _selectedTheme, activeColor: primaryGreen, onChanged: (v) => setState(() => _selectedTheme = v!)),
            RadioListTile(title: const Text("Light"), value: "Light", groupValue: _selectedTheme, activeColor: primaryGreen, onChanged: (v) => setState(() => _selectedTheme = v!)),
            RadioListTile(title: const Text("Dark"), value: "Dark", groupValue: _selectedTheme, activeColor: primaryGreen, onChanged: (v) => setState(() => _selectedTheme = v!)),
            
            const Divider(),
            const Text("Enable Biometric Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Use fingerprint or face recognition for faster access.", style: TextStyle(color: Colors.grey, fontSize: 14)),
            SwitchListTile(
              value: _biometricsEnabled,
              activeColor: primaryGreen,
              onChanged: (bool value) async {
                if (value) {
                  final auth = await _biometricService.authenticate();
                  if (auth) {
                    await _biometricService.setBiometricsEnabled(true);
                    setState(() => _biometricsEnabled = true);
                  }
                } else {
                  await _biometricService.setBiometricsEnabled(false);
                  setState(() => _biometricsEnabled = false);
                }
              },
            ),
            
            const SizedBox(height: 20),
            const Text("Account", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Email", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(user?.email ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    TextButton.icon(onPressed: () => _showConfirmPassword(() {}), icon: const Icon(Icons.edit, color: primaryGreen), label: const Text("CHANGE EMAIL", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
                    const Divider(),
                    TextButton.icon(onPressed: () => _showConfirmPassword(() {}), icon: const Icon(Icons.lock_outline, color: primaryGreen), label: const Text("CHANGE PASSWORD", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionBtn("CLEAN CLOUD BACKUPS", Icons.delete_outline, () {}),
            _buildActionBtn("BACKUP TO CLOUD (RTDB)", Icons.cloud_upload_outlined, () {}),
            _buildActionBtn("RESTORE FROM CLOUD (RTDB)", Icons.settings_backup_restore, () {}),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                onPressed: () => _showConfirmPassword(() {}),
                child: const Text("WIPE SERVER DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 55,
      margin: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFF388E3C)),
        label: Text(label, style: const TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF388E3C))),
      ),
    );
  }
}
