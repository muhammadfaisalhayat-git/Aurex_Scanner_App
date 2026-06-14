import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import '../services/locale_provider.dart';
import '../services/biometric_service.dart';
import '../l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  final _biometricService = BiometricService();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    final isEnabled = await _biometricService.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _canCheckBiometrics = isAvailable && isEnabled;
      });
    }
  }

  Future<void> _loginWithBiometrics() async {
    final l10n = AppLocalizations.of(context)!;
    final authenticated = await _biometricService.authenticate();
    if (authenticated && mounted) {
      if (FirebaseAuth.instance.currentUser != null) {
        unawaited(Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.biometricLoginError)),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        unawaited(Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        ));
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login Failed";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password provided.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    const primaryGreen = Color(0xFF5EBA61); // Bright green from the screenshot

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Top Arabic/English Toggle
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => localeProvider.toggleLocale(),
                    child: Text(
                      localeProvider.locale.languageCode == 'ar' ? "English" : "العربية",
                      style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Red/Blue 'A' App Icon
                Image.asset(
                  'assets/logos/app_icon.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.change_history, size: 100, color: Colors.red),
                ),
                const SizedBox(height: 20),
                
                // Brand Name
                Text(
                  l10n.appTitle,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF333333)),
                ),
                Text(
                  l10n.tagline,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 50),
                
                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: l10n.email,
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryGreen, width: 2)),
                  ),
                  validator: (value) => (value == null || !value.contains('@')) ? 'Invalid email' : null,
                ),
                const SizedBox(height: 20),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: l10n.password,
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryGreen, width: 2)),
                  ),
                  validator: (value) => (value == null || value.length < 6) ? 'Password too short' : null,
                ),
                const SizedBox(height: 20),
                
                // Remember Me
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: primaryGreen,
                      onChanged: (val) => setState(() => _rememberMe = val!),
                    ),
                    Text(l10n.rememberMe, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 30),
                
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      elevation: 2,
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(l10n.login, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 25),
                
                // Biometric Icon
                if (_canCheckBiometrics)
                  GestureDetector(
                    onTap: _loginWithBiometrics,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.face, color: Colors.white, size: 40), // Or Icons.fingerprint
                    ),
                  )
                else
                   Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.face, color: Colors.white, size: 40),
                  ),
                
                const SizedBox(height: 30),
                
                // Register & Forgot Password
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                  },
                  child: Text(l10n.register, style: const TextStyle(color: Color(0xFF4C8C4A), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(l10n.forgotPassword, style: const TextStyle(color: primaryGreen, fontSize: 16)),
                ),
                
                const SizedBox(height: 20),
                const Divider(color: Colors.grey),
                const SizedBox(height: 20),
                
                // Google Login
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    child: Text(
                      l10n.continueWithGoogle,
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
}
