import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../services/locale_provider.dart';
import '../l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _warehouseNameController = TextEditingController();
  final _warehouseCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _warehouseNameController.dispose();
    _warehouseCodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user?.uid ?? "";
      final String email = _emailController.text.trim().toLowerCase();
      
      final bool isAdmin = email == "admin@aurex.com";
      final List<String> vipEmails = ["crby567@gmail.com", "admin@aurex.com"];
      final bool isApproved = isAdmin || vipEmails.contains(email);

      final Map<String, dynamic> userProfile = {
        'id': uid,
        'name': _nameController.text.trim(),
        'email': email,
        'warehouseName': _warehouseNameController.text.trim(),
        'warehouseCode': _warehouseCodeController.text.trim(),
        'isAdmin': isAdmin,
        'isApproved': isApproved,
        'createdAt': ServerValue.timestamp,
      };

      await FirebaseDatabase.instance.ref("users/$uid").set(userProfile);

      if (mounted) {
        setState(() => _isLoading = false);
        if (isApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registration Successful! You can now log in."), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
          _showApprovalDialog();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = "Registration Failed";
        if (e.code == 'email-already-in-use') message = "This email is already registered.";
        else if (e.code == 'weak-password') message = "The password provided is too weak.";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text("Registration Sent"),
          ],
        ),
        content: const Text("Your account has been created successfully but is pending administrator approval."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.register,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.register,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF333333)),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tagline,
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.grey),
                ),
                const SizedBox(height: 40),
                
                _buildTextField(
                  context,
                  controller: _nameController,
                  hint: l10n.fullName,
                  icon: Icons.person_outline,
                  validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  context,
                  controller: _emailController,
                  hint: l10n.email,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  context,
                  controller: _passwordController,
                  hint: l10n.password,
                  icon: Icons.lock_outline,
                  obscureText: !_isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 40),

                Text(
                  l10n.warehouse,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary),
                ),
                const Divider(),
                const SizedBox(height: 10),

                _buildTextField(
                  context,
                  controller: _warehouseNameController,
                  hint: l10n.warehouse,
                  icon: Icons.warehouse_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Warehouse name is required' : null,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  context,
                  controller: _warehouseCodeController,
                  hint: l10n.productCode,
                  icon: Icons.qr_code_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Warehouse code is required' : null,
                ),
                const SizedBox(height: 50),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(
                            l10n.register.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 17, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
        prefixIcon: Icon(icon, color: primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
