// lib/screens/admin/admin_account_settings.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/screens/admin/face_registration_screen.dart';

class AdminAccountSettings extends StatefulWidget {
  final Map<String, dynamic> admin;
  const AdminAccountSettings({super.key, required this.admin});

  @override
  State<AdminAccountSettings> createState() => _AdminAccountSettingsState();
}

class _AdminAccountSettingsState extends State<AdminAccountSettings> {
  late Map<String, dynamic> _admin;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _admin = Map<String, dynamic>.from(widget.admin);
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_currentPassCtrl.text.isEmpty || _newPassCtrl.text.isEmpty) {
      _showSnack('All password fields are required.', isError: true);
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _showSnack('New passwords do not match.', isError: true);
      return;
    }

    // Verify current password
    final verify = await DatabaseHelper.instance
        .loginAdmin(_admin['username'], _currentPassCtrl.text);
    if (verify == null) {
      _showSnack('Current password is incorrect.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'admins',
        {'password': DatabaseHelper.hashPassword(_newPassCtrl.text)},
        where: 'id = ?',
        whereArgs: [_admin['id']],
      );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _showSnack('Password updated successfully!');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF00E676),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasFace = _admin['face_embedding'] != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Account Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Profile Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF0066CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.4),
                    blurRadius: 20, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _admin['full_name'].toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_admin['full_name'],
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w800, fontSize: 18)),
                        Text('@${_admin['username']}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7),
                                fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('SYSTEM ADMIN',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 10, fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Face ID Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E2D45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Face ID',
                      style: TextStyle(color: Color(0xFFFF6B6B),
                          fontSize: 13, fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: hasFace
                              ? const Color(0xFF00E676).withOpacity(0.1)
                              : const Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasFace
                                ? const Color(0xFF00E676).withOpacity(0.3)
                                : const Color(0xFFFF6B6B).withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          hasFace
                              ? Icons.face_rounded
                              : Icons.face_retouching_off_rounded,
                          color: hasFace
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF6B6B),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasFace
                                  ? 'Face ID Registered'
                                  : 'Face ID Not Registered',
                              style: TextStyle(
                                color: hasFace
                                    ? const Color(0xFF00E676)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              hasFace
                                  ? 'Your face is enrolled for kiosk verification'
                                  : 'Register your face for kiosk admin verification',
                              style: const TextStyle(
                                  color: Color(0xFF8B9DC3), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          FaceRegistrationScreen(
                            personId: _admin['id'],
                            personName: _admin['full_name'],
                            type: FaceRegType.admin,
                          )))
                        .then((_) async {
                          // Reload admin data
                          final db = await DatabaseHelper.instance.database;
                          final result = await db.query('admins',
                              where: 'id = ?', whereArgs: [_admin['id']]);
                          if (result.isNotEmpty && mounted) {
                            setState(() => _admin = result.first);
                          }
                        }),
                      icon: const Icon(
                          Icons.face_retouching_natural_rounded, size: 18),
                      label: Text(hasFace ? 'Update Face ID' : 'Register Face ID',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Change Password ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E2D45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Change Password',
                      style: TextStyle(color: Color(0xFFFF6B6B),
                          fontSize: 13, fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 16),
                  _PassField(
                    ctrl: _currentPassCtrl,
                    label: 'Current Password',
                    obscure: _obscureCurrent,
                    onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  const SizedBox(height: 12),
                  _PassField(
                    ctrl: _newPassCtrl,
                    label: 'New Password',
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  const SizedBox(height: 12),
                  _PassField(
                    ctrl: _confirmPassCtrl,
                    label: 'Confirm New Password',
                    obscure: _obscureConfirm,
                    onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        foregroundColor: const Color(0xFF0A0E1A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0A0E1A)))
                          : const Text('Update Password',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PassField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PassField({required this.ctrl, required this.label,
      required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8B9DC3),
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: const TextStyle(color: Color(0xFF3D4F6B)),
            prefixIcon: const Icon(Icons.lock_rounded,
                color: Color(0xFF8B9DC3), size: 18),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: const Color(0xFF8B9DC3), size: 18,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFF1C2536),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF00D4FF), width: 1.5)),
          ),
        ),
      ],
    );
  }
}