// lib/screens/admin/professor_form.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';

class ProfessorForm extends StatefulWidget {
  final Map<String, dynamic>? professor; // null = create, non-null = edit
  const ProfessorForm({super.key, this.professor});

  @override
  State<ProfessorForm> createState() => _ProfessorFormState();
}

class _ProfessorFormState extends State<ProfessorForm> {
  final _fullNameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _usernameCtrl   = TextEditingController();
  final _passwordCtrl   = TextEditingController();

  String _generatedEmployeeId = '';
  bool _obscurePass = true;
  bool _isLoading   = false;

  bool get _isEdit => widget.professor != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.professor!;
      _generatedEmployeeId  = p['employee_id'] ?? '';
      _fullNameCtrl.text    = p['full_name']   ?? '';
      _emailCtrl.text       = p['email']       ?? '';
      _departmentCtrl.text  = p['department']  ?? '';
      _usernameCtrl.text    = p['username']    ?? '';
    } else {
      _generateEmployeeId();
    }
  }

  /// Queries the DB for the highest existing EMP-XXX number and
  /// returns the next one, e.g. if EMP-003 exists → EMP-004.
  Future<void> _generateEmployeeId() async {
    try {
      final professors = await DatabaseHelper.instance.getAllProfessors();

      int maxNumber = 0;
      for (final p in professors) {
        final empId = p['employee_id'] as String? ?? '';
        // Match EMP-followed by digits
        final match = RegExp(r'^EMP-(\d+)$').firstMatch(empId);
        if (match != null) {
          final num = int.tryParse(match.group(1)!) ?? 0;
          if (num > maxNumber) maxNumber = num;
        }
      }

      final nextId = 'EMP-${(maxNumber + 1).toString().padLeft(3, '0')}';
      if (mounted) setState(() => _generatedEmployeeId = nextId);
    } catch (e) {
      // Fallback: use timestamp-based ID so the form never gets stuck
      if (mounted) {
        setState(() =>
            _generatedEmployeeId = 'EMP-${DateTime.now().millisecondsSinceEpoch % 1000}');
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _departmentCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_fullNameCtrl.text.trim().isEmpty ||
        _usernameCtrl.text.trim().isEmpty) {
      _showError('Full Name and Username are required.');
      return;
    }
    if (!_isEdit && _passwordCtrl.text.trim().isEmpty) {
      _showError('Password is required for new professors.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'employee_id': _generatedEmployeeId,
        'full_name':   _fullNameCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'department':  _departmentCtrl.text.trim(),
        'username':    _usernameCtrl.text.trim(),
        if (_passwordCtrl.text.isNotEmpty)
          'password': _passwordCtrl.text.trim(),
      };

      if (_isEdit) {
        await DatabaseHelper.instance
            .updateProfessor(widget.professor!['id'], data);
      } else {
        await DatabaseHelper.instance.insertProfessor(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit
              ? '${_fullNameCtrl.text} updated successfully!'
              : '${_fullNameCtrl.text} added successfully!'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Error: Username already exists.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
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
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          _isEdit ? 'Edit Professor' : 'Add Professor',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Basic Information ────────────────────────────────
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
                  const _SectionLabel('Basic Information'),
                  const SizedBox(height: 16),

                  // ── Auto-generated Employee ID (read-only) ───────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Employee ID',
                          style: TextStyle(
                            color: Color(0xFF8B9DC3),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2536),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2A3A55), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_rounded,
                                color: Color(0xFF8B9DC3), size: 18),
                            const SizedBox(width: 12),
                            // Show spinner while ID is being generated
                            if (_generatedEmployeeId.isEmpty)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00D4FF)),
                              )
                            else
                              Text(
                                _generatedEmployeeId,
                                style: const TextStyle(
                                  color: Color(0xFF00D4FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            const Spacer(),
                            // Lock icon to signal it's auto-assigned
                            const Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFF3D4F6B), size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Auto-generated — cannot be changed',
                        style: TextStyle(
                            color: Color(0xFF3D4F6B), fontSize: 11),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  _FormField(
                      controller: _fullNameCtrl,
                      label: 'Full Name *',
                      hint: 'e.g. Juan dela Cruz',
                      icon: Icons.person_rounded),
                  const SizedBox(height: 14),
                  _FormField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'e.g. juan@school.edu',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _FormField(
                      controller: _departmentCtrl,
                      label: 'Department',
                      hint: 'e.g. Computer Science',
                      icon: Icons.business_rounded),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Login Credentials ────────────────────────────────
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
                  const _SectionLabel('Login Credentials'),
                  const SizedBox(height: 16),
                  _FormField(
                      controller: _usernameCtrl,
                      label: 'Username *',
                      hint: 'e.g. jdelacruz',
                      icon: Icons.alternate_email_rounded),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _passwordCtrl,
                    label: _isEdit
                        ? 'New Password (leave blank to keep)'
                        : 'Password *',
                    hint: '••••••••',
                    icon: Icons.lock_rounded,
                    obscure: _obscurePass,
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePass = !_obscurePass),
                      child: Icon(
                        _obscurePass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: const Color(0xFF8B9DC3),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Save button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: const Color(0xFF0A0E1A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF0A0E1A)))
                    : Text(
                        _isEdit ? 'Update Professor' : 'Add Professor',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          color: Color(0xFF00D4FF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ));
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B9DC3),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: Color(0xFF3D4F6B), fontSize: 14),
            prefixIcon:
                Icon(icon, color: const Color(0xFF8B9DC3), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF1C2536),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF00D4FF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}