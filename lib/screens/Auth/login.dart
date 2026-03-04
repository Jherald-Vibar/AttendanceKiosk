// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/screens/admin/admin_dashboard.dart';
import 'package:Sentry/screens/kiosk/welcome.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String _selectedRole = 'Professor';
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter username and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedRole == 'Admin') {
        final admin = await DatabaseHelper.instance
            .loginAdmin(username, password);
        if (admin == null) {
          _showError('Invalid admin credentials.');
          return;
        }
        if (mounted) {
          Navigator.pushReplacement(context,
            MaterialPageRoute(
              builder: (_) => AdminDashboard(admin: admin)));
        }
      } else {
        final professor = await DatabaseHelper.instance
            .loginProfessor(username, password);
        if (professor == null) {
          _showError('Invalid professor credentials.');
          return;
        }
        if (mounted) {
          // Navigate to professor's welcome/dashboard
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const Welcome()));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF82D8FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Back button
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 16, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Image.asset('assets/images/logo.png', width: 90),
                  const SizedBox(height: 10),
                  const Text('SENTRY',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 30,
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      )),
                  const SizedBox(height: 4),
                  const Text('Secure Attendance Tracking',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 36),

                  // Login card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF82D8FF).withOpacity(0.3),
                          blurRadius: 30, offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome Back',
                            style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        const Text('Sign in to continue',
                            style: TextStyle(fontSize: 13,
                                color: Color(0xFF94A3B8))),
                        const SizedBox(height: 24),

                        // Role selector
                        const Text('Login as',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _RoleChip(
                              label: 'Professor',
                              icon: Icons.school_rounded,
                              selected: _selectedRole == 'Professor',
                              onTap: () => setState(
                                  () => _selectedRole = 'Professor'),
                            ),
                            const SizedBox(width: 12),
                            _RoleChip(
                              label: 'Admin',
                              icon: Icons.admin_panel_settings_rounded,
                              selected: _selectedRole == 'Admin',
                              onTap: () => setState(
                                  () => _selectedRole = 'Admin'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Username
                        const Text('Username',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569))),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _usernameCtrl,
                          hint: 'Enter your username',
                          icon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 18),

                        // Password
                        const Text('Password',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569))),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _passwordCtrl,
                          hint: 'Enter your password',
                          icon: Icons.lock_rounded,
                          obscure: _obscurePass,
                          suffix: GestureDetector(
                            onTap: () => setState(
                                () => _obscurePass = !_obscurePass),
                            child: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: const Color(0xFF94A3B8), size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF1E3A8A).withOpacity(0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Text('Login as $_selectedRole',
                                    style: const TextStyle(fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text('Facial Recognition System v1.0',
                      style: TextStyle(fontSize: 12,
                          color: Colors.black.withOpacity(0.3))),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label; final IconData icon;
  final bool selected; final VoidCallback onTap;
  const _RoleChip({required this.label, required this.icon,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18,
                  color: selected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF64748B),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint; final IconData icon;
  final bool obscure; final Widget? suffix;
  const _InputField({required this.controller, required this.hint,
      required this.icon, this.obscure = false, this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5)),
      ),
    );
  }
}