// lib/screens/professor/prof_account_page.dart

import 'package:flutter/material.dart';
import 'package:Sentry/main.dart' show HomePage;
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/screens/professor/professor_dashboard.dart'
    show _LogoutDialog;

class ProfAccountPage extends StatefulWidget {
  final Map<String, dynamic> professor;
  const ProfAccountPage({super.key, required this.professor});

  @override
  State<ProfAccountPage> createState() => _ProfAccountPageState();
}

class _ProfAccountPageState extends State<ProfAccountPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _snack('All fields are required.', Colors.orange);
      return;
    }
    if (newPass != confirm) {
      _snack('New passwords do not match.', Colors.red);
      return;
    }
    if (newPass.length < 6) {
      _snack('Password must be at least 6 characters.', Colors.orange);
      return;
    }

    setState(() => _saving = true);

    final match = await DatabaseHelper.instance
        .loginProfessor(widget.professor['username'], current);

    if (match == null) {
      _snack('Current password is incorrect.', Colors.red);
      setState(() => _saving = false);
      return;
    }

    await DatabaseHelper.instance.updateProfessor(
        widget.professor['id'], {'password': newPass});

    _currentCtrl.clear();
    _newCtrl.clear();
    _confirmCtrl.clear();
    setState(() => _saving = false);
    _snack('Password updated successfully!', Colors.green);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => _LogoutDialog(
        onConfirm: () =>
            Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient — matches homepage
        Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF82D8FF), Colors.white],
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Page title ──────────────────────────────────
                const Text('Account Settings',
                    style: TextStyle(
                        color: Color(0xFF1C2536),
                        fontWeight: FontWeight.w800,
                        fontSize: 22)),

                const SizedBox(height: 20),

                // ── Profile card ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.black.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar — black square
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Text(
                            widget.professor['full_name']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(widget.professor['full_name'],
                                style: const TextStyle(
                                    color: Color(0xFF1C2536),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            Text(
                              widget.professor['employee_id'],
                              style: const TextStyle(
                                  color: Color(0xFF82D8FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (widget.professor['department'] !=
                                null)
                              Text(widget.professor['department'],
                                  style: TextStyle(
                                      color: Colors.black
                                          .withOpacity(0.4),
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Change password ─────────────────────────────
                const Text('Change Password',
                    style: TextStyle(
                        color: Color(0xFF1C2536),
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.black.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    children: [
                      _PassField(
                        ctrl: _currentCtrl,
                        label: 'Current Password',
                        obscure: _obscureCurrent,
                        onToggle: () => setState(() =>
                            _obscureCurrent = !_obscureCurrent),
                      ),
                      const SizedBox(height: 14),
                      _PassField(
                        ctrl: _newCtrl,
                        label: 'New Password',
                        obscure: _obscureNew,
                        onToggle: () => setState(
                            () => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 14),
                      _PassField(
                        ctrl: _confirmCtrl,
                        label: 'Confirm New Password',
                        obscure: _obscureConfirm,
                        onToggle: () => setState(() =>
                            _obscureConfirm = !_obscureConfirm),
                      ),
                      const SizedBox(height: 22),
                      // Update password button — black like Login
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                Colors.black.withOpacity(0.25),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                              : const Text('Update Password',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Logout button ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1C2536),
                      side: BorderSide(
                          color: Colors.black.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Password field ────────────────────────────────────────────────────────

class _PassField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PassField({
    required this.ctrl,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(
              color: Color(0xFF1C2536), fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withOpacity(0.04),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF82D8FF), width: 1.5),
            ),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.black.withOpacity(0.3),
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}