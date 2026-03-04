// lib/screens/admin/manage_students.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/screens/admin/face_registration_screen.dart';

class ManageStudents extends StatefulWidget {
  const ManageStudents({super.key});

  @override
  State<ManageStudents> createState() => _ManageStudentsState();
}

class _ManageStudentsState extends State<ManageStudents> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _sections = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final students = await DatabaseHelper.instance.getAllStudents();
    final sections = await DatabaseHelper.instance.getAllSections();
    setState(() {
      _students = students; _filtered = students;
      _sections = sections; _loading = false;
    });
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _students.where((s) =>
        s['full_name'].toString().toLowerCase().contains(q) ||
        s['student_id'].toString().toLowerCase().contains(q) ||
        (s['section_name'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    });
  }

  void _showStudentDialog({Map<String, dynamic>? student}) {
    final idCtrl = TextEditingController(text: student?['student_id'] ?? '');
    final nameCtrl = TextEditingController(text: student?['full_name'] ?? '');
    final emailCtrl = TextEditingController(text: student?['email'] ?? '');
    int? sectionId = student?['section_id'];
    final isEdit = student != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: const Color(0xFF1C2536),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit Student' : 'Add Student',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 20),
                _DialogField3(ctrl: idCtrl, label: 'Student ID *',
                    hint: 'e.g. 2024-00001'),
                const SizedBox(height: 12),
                _DialogField3(ctrl: nameCtrl, label: 'Full Name *',
                    hint: 'e.g. Maria Santos'),
                const SizedBox(height: 12),
                _DialogField3(ctrl: emailCtrl, label: 'Email',
                    hint: 'e.g. maria@school.edu'),
                const SizedBox(height: 12),
                const Text('Section',
                    style: TextStyle(color: Color(0xFF8B9DC3),
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: sectionId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1C2536),
                      hint: const Text('Select section',
                          style: TextStyle(color: Color(0xFF3D4F6B))),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('No section',
                              style: TextStyle(color: Color(0xFF8B9DC3))),
                        ),
                        ..._sections.map((s) => DropdownMenuItem<int>(
                          value: s['id'],
                          child: Text(s['section_name']),
                        )),
                      ],
                      onChanged: (val) => setStateDialog(() => sectionId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF8B9DC3))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (idCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
                          final data = {
                            'student_id': idCtrl.text.trim(),
                            'full_name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'section_id': sectionId,
                          };
                          if (isEdit) {
                            await DatabaseHelper.instance
                                .updateStudent(student!['id'], data);
                          } else {
                            await DatabaseHelper.instance.insertStudent(data);
                          }
                          Navigator.pop(ctx);
                          _load();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB06EFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(isEdit ? 'Update' : 'Add',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2536),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Student',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Remove $name and all their attendance records?',
            style: const TextStyle(color: Color(0xFF8B9DC3))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B9DC3)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteStudent(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final withFace = _students.where((s) => s['face_embedding'] != null).length;
    final total = _students.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Students',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFFB06EFF), size: 28),
            onPressed: () => _showStudentDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Face registration progress bar
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2D45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Face Registration',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('$withFace / $total',
                            style: const TextStyle(color: Color(0xFFB06EFF),
                                fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? withFace / total : 0,
                        backgroundColor: const Color(0xFF1C2536),
                        color: const Color(0xFFB06EFF),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search students...',
                hintStyle: const TextStyle(color: Color(0xFF8B9DC3)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF8B9DC3)),
                filled: true,
                fillColor: const Color(0xFF1C2536),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFFB06EFF)))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_rounded, size: 56,
                                color: const Color(0xFF8B9DC3).withOpacity(0.3)),
                            const SizedBox(height: 14),
                            const Text('No students yet.\nTap + to add one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF8B9DC3))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = _filtered[i];
                          final hasFace = s['face_embedding'] != null;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF1E2D45)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46, height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB06EFF).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Center(
                                        child: Text(
                                          s['full_name'].toString().substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFFB06EFF),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s['full_name'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              )),
                                          Text(s['student_id'],
                                              style: const TextStyle(
                                                  color: Color(0xFFB06EFF),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600)),
                                          if (s['section_name'] != null)
                                            Text(s['section_name'],
                                                style: const TextStyle(
                                                    color: Color(0xFF8B9DC3),
                                                    fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: hasFace
                                            ? const Color(0xFF00E676).withOpacity(0.1)
                                            : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: hasFace
                                              ? const Color(0xFF00E676).withOpacity(0.3)
                                              : Colors.orange.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        hasFace ? 'Face ✓' : 'No Face',
                                        style: TextStyle(
                                          color: hasFace
                                              ? const Color(0xFF00E676)
                                              : Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _Btn(icon: Icons.edit_rounded, label: 'Edit',
                                        color: const Color(0xFF00D4FF),
                                        onTap: () => _showStudentDialog(student: s)),
                                    const SizedBox(width: 8),
                                    _Btn(
                                      icon: Icons.face_retouching_natural_rounded,
                                      label: hasFace ? 'Re-scan' : 'Register Face',
                                      color: const Color(0xFFB06EFF),
                                      onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) =>
                                          FaceRegistrationScreen(
                                            personId: s['id'],
                                            personName: s['full_name'],
                                            type: FaceRegType.student,
                                          )))
                                        .then((_) => _load()),
                                    ),
                                    const SizedBox(width: 8),
                                    _Btn(icon: Icons.delete_rounded, label: 'Delete',
                                        color: Colors.redAccent,
                                        onTap: () => _delete(s['id'], s['full_name'])),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const _Btn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color,
                  fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogField3 extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  const _DialogField3({required this.ctrl, required this.label, required this.hint});

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
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF3D4F6B)),
            filled: true,
            fillColor: const Color(0xFF0A0E1A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFB06EFF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}