import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/biometric_service.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart';
import '../services/theme_provider.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricsEnabled = false;
  final _biometricService = BiometricService();
  final _audioPlayer = AudioPlayer();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await _biometricService.isBiometricsEnabled();
    if (mounted) {
      setState(() { _biometricsEnabled = enabled; });
    }
  }

  Future<void> _testSound() async {
    try {
      await _audioPlayer.stop(); // Ensure any previous play is stopped
      await _audioPlayer.setSource(AssetSource('sounds/shutter_v2.wav'));
      await _audioPlayer.play(AssetSource('sounds/shutter_v2.wav'), mode: PlayerMode.lowLatency);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playing camera shutter sound...")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sound failed: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF388E3C);
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.settings, style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.configuration, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            _buildActionBtn(l10n.testScanBeep, Icons.volume_up, _testSound),
            
            const Divider(height: 40),
            Text(l10n.theme, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            RadioListTile<ThemeMode>(
              title: Text(l10n.systemDefault), 
              value: ThemeMode.system, 
              groupValue: themeProvider.themeMode, 
              activeColor: primaryGreen, 
              onChanged: (v) => themeProvider.setThemeMode(v!)
            ),
            RadioListTile<ThemeMode>(
              title: Text(l10n.light), 
              value: ThemeMode.light, 
              groupValue: themeProvider.themeMode, 
              activeColor: primaryGreen, 
              onChanged: (v) => themeProvider.setThemeMode(v!)
            ),
            RadioListTile<ThemeMode>(
              title: Text(l10n.dark), 
              value: ThemeMode.dark, 
              groupValue: themeProvider.themeMode, 
              activeColor: primaryGreen, 
              onChanged: (v) => themeProvider.setThemeMode(v!)
            ),
            
            const Divider(),
            Text(l10n.enableBiometric, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            Text(l10n.account, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(user?.email ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionBtn(l10n.cleanCloudBackups, Icons.delete_outline, () {
               _showConfirmDialog(context, "Clear Cloud Data", "Are you sure you want to delete all cloud backups? This cannot be undone.", () async {
                  final fs = Provider.of<FirebaseService>(context, listen: false);
                  await fs.wipeDataFromServer();
               });
            }),
            _buildActionBtn(l10n.backupToCloud, Icons.cloud_upload_outlined, () async {
              final ds = Provider.of<DatabaseService>(context, listen: false);
              final products = await ds.getProducts();
              if (products.isEmpty) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No local data to backup")));
                return;
              }
              _runCloudTask(context, l10n.backupToServer, (progress) async {
                final fs = Provider.of<FirebaseService>(context, listen: false);
                await fs.backupAll(products, onProgress: (c, t) => progress(c, t));
                return true;
              });
            }),
            _buildActionBtn(l10n.restoreFromCloudRTDB, Icons.settings_backup_restore, () {
              _runCloudTask(context, l10n.restoreFromCloud, (progress) async {
                final fs = Provider.of<FirebaseService>(context, listen: false);
                return await fs.restoreAll(onProgress: (c, t) => progress(c, t));
              });
            }),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String msg, Future<void> Function() onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
               Navigator.pop(ctx);
               await onConfirm();
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cloud data cleared successfully.")));
            }, 
            child: const Text("DELETE ALL", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  void _runCloudTask(BuildContext context, String title, Future<dynamic> Function(Function(int, int)) task) {
    final progressNotifier = ValueNotifier<double>(0);
    final statusNotifier = ValueNotifier<String>("Initializing...");
    bool isDialogVisible = true;
    final NavigatorState rootNavigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
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
          ],
        ),
      ),
    );

    Future(() async {
      try {
        final result = await task((c, t) {
          if (t > 0) {
            progressNotifier.value = c / t;
            statusNotifier.value = "$c / $t processed";
          }
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (isDialogVisible) { rootNavigator.pop(); isDialogVisible = false; }
        
        showDialog(
          context: rootNavigator.context,
          builder: (ctx) => AlertDialog(
            title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Complete")]),
            content: Text(result is int ? "Restored $result products." : "Operation completed successfully."),
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

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onTap) {
    const primaryGreen = Color(0xFF388E3C);
    return Container(
      width: double.infinity,
      height: 55,
      margin: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: primaryGreen),
        label: Text(label, style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: primaryGreen)),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
