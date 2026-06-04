import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/biometric_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final _auth = FirebaseAuth.instance;
  late DatabaseReference _userRef;
  final _biometricService = BiometricService();
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = _auth.currentUser?.email ?? "";
    _nameController.text = _auth.currentUser?.displayName ?? "Bin Awf operator";
    _userRef = FirebaseDatabase.instance.ref("users/${_auth.currentUser?.uid}/profile");
    _loadProfile();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await _biometricService.isBiometricsEnabled();
    setState(() {
      _biometricsEnabled = enabled;
    });
  }

  Future<void> _loadProfile() async {
    final snapshot = await _userRef.get();
    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map;
      if (mounted) {
        setState(() {
          _nameController.text = data['name'] ?? _nameController.text;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _auth.currentUser?.updateDisplayName(_nameController.text);
      await _userRef.update({
        'name': _nameController.text,
        'email': _emailController.text,
        'lastUpdated': ServerValue.timestamp,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating profile: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF5E7D6A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF5E7D6A),
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Enable Biometric Login"),
              subtitle: const Text("Use fingerprint to log in next time"),
              value: _biometricsEnabled,
              onChanged: (bool value) async {
                if (value) {
                  final authenticated = await _biometricService.authenticate();
                  if (authenticated) {
                    await _biometricService.setBiometricsEnabled(true);
                    setState(() => _biometricsEnabled = true);
                  }
                } else {
                  await _biometricService.setBiometricsEnabled(false);
                  setState(() => _biometricsEnabled = false);
                }
              },
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: "Email Address",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Enable Biometric Login"),
              subtitle: const Text("Use fingerprint to log in next time"),
              value: _biometricsEnabled,
              onChanged: (bool value) async {
                if (value) {
                  final authenticated = await _biometricService.authenticate();
                  if (authenticated) {
                    await _biometricService.setBiometricsEnabled(true);
                    setState(() => _biometricsEnabled = true);
                  }
                } else {
                  await _biometricService.setBiometricsEnabled(false);
                  setState(() => _biometricsEnabled = false);
                }
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E7D6A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
