// lib/screens/admin/manage_subjects.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';

class ManageSubjects extends StatefulWidget {
  const ManageSubjects({super.key});

  @override
  State<ManageSubjects> createState() => _ManageSubjectsState();
}

class _ManageSubjectsState extends State<ManageSubjects> {
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getAllSubjects();
    setState(() { _subjects = data; _loading = false; });
  }

  void _showSubjectDialog({Map<String, dynamic>? subject}) {
    final codeCtrl = TextEditingController(text: subject?['subject_code'] ?? '');
    final nameCtrl = TextEditingController(text: subject?['subject_name'] ?? '');
    final unitsCtrl = TextEditingController(text: subject?['units']?.toString() ?? '3');
    final isEdit = subject != null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C2536),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit Subject' : 'Add Subject',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              _DialogField(ctrl: codeCtrl, label: 'Subject Code',
                  hint: 'e.g. CS101'),
              const SizedBox(height: 12),
              _DialogField(ctrl: nameCtrl, label: 'Subject Name',
                  hint: 'e.g. Programming 1'),
              const SizedBox(height: 12),
              _DialogField(ctrl: unitsCtrl, label: 'Units',
                  hint: '3', keyboardType: TextInputType.number),
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
                        if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
                        final data = {
                          'subject_code': codeCtrl.text.trim(),
                          'subject_name': nameCtrl.text.trim(),
                          'units': int.tryParse(unitsCtrl.text) ?? 3,
                        };
                        if (isEdit) {
                          await DatabaseHelper.instance
                              .updateSubject(subject!['id'], data);
                        } else {
                          await DatabaseHelper.instance.insertSubject(data);
                        }
                        Navigator.pop(ctx);
                        _load();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
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
    );
  }

  void _showAssignDialog(Map<String, dynamic> subject) async {
    final professors = await DatabaseHelper.instance.getAllProfessors();
    final sections = await DatabaseHelper.instance.getAllSections();
    final assigned = await DatabaseHelper.instance
        .getSectionsBySubject(subject['id']);
    final assignedIds = assigned.map((s) => s['id'] as int).toSet();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: const Color(0xFF1C2536),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign Sections',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(subject['subject_name'],
                      style: const TextStyle(color: Color(0xFF00E676),
                          fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('Sections',
                      style: TextStyle(color: Color(0xFF8B9DC3),
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: sections.isEmpty
                        ? const Center(child: Text('No sections available.',
                            style: TextStyle(color: Color(0xFF8B9DC3))))
                        : ListView.builder(
                            itemCount: sections.length,
                            itemBuilder: (_, i) {
                              final sec = sections[i];
                              final isAssigned = assignedIds.contains(sec['id']);
                              return CheckboxListTile(
                                value: isAssigned,
                                onChanged: (val) async {
                                  if (val == true) {
                                    // Show professor picker
                                    int? profId = await _pickProfessor(
                                        context, professors);
                                    await DatabaseHelper.instance
                                        .assignSectionToSubject(
                                      subjectId: subject['id'],
                                      sectionId: sec['id'],
                                      professorId: profId,
                                    );
                                    assignedIds.add(sec['id']);
                                  } else {
                                    await DatabaseHelper.instance
                                        .removeSectionFromSubject(
                                            subject['id'], sec['id']);
                                    assignedIds.remove(sec['id']);
                                  }
                                  setStateDialog(() {});
                                },
                                title: Text(sec['section_name'],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14)),
                                subtitle: Text(
                                    '${sec['course'] ?? ''} ${sec['year_level'] != null ? '- Year ${sec['year_level']}' : ''}',
                                    style: const TextStyle(
                                        color: Color(0xFF8B9DC3), fontSize: 12)),
                                activeColor: const Color(0xFF00E676),
                                checkColor: Colors.black,
                                tileColor: Colors.transparent,
                                contentPadding: EdgeInsets.zero,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Done',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<int?> _pickProfessor(BuildContext context,
      List<Map<String, dynamic>> professors) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C2536),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Professor (optional)',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('No professor yet',
                    style: TextStyle(color: Color(0xFF8B9DC3))),
                onTap: () => Navigator.pop(ctx, null),
                contentPadding: EdgeInsets.zero,
              ),
              ...professors.map((p) => ListTile(
                title: Text(p['full_name'],
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(p['employee_id'],
                    style: const TextStyle(color: Color(0xFF8B9DC3))),
                onTap: () => Navigator.pop(ctx, p['id']),
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(int id) async {
    await DatabaseHelper.instance.deleteSubject(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Subjects',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF00E676), size: 28),
            onPressed: () => _showSubjectDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _subjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 56,
                          color: const Color(0xFF8B9DC3).withOpacity(0.3)),
                      const SizedBox(height: 14),
                      const Text('No subjects yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF8B9DC3))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = _subjects[i];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2D45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF00E676).withOpacity(0.3)),
                                ),
                                child: Text(s['subject_code'],
                                    style: const TextStyle(
                                      color: Color(0xFF00E676),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    )),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(s['subject_name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    )),
                              ),
                              Text('${s['units']} units',
                                  style: const TextStyle(
                                      color: Color(0xFF8B9DC3), fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _ActionBtn2(
                                icon: Icons.edit_rounded,
                                label: 'Edit',
                                color: const Color(0xFF00D4FF),
                                onTap: () => _showSubjectDialog(subject: s),
                              ),
                              const SizedBox(width: 8),
                              _ActionBtn2(
                                icon: Icons.link_rounded,
                                label: 'Assign Sections',
                                color: const Color(0xFF00E676),
                                onTap: () => _showAssignDialog(s),
                              ),
                              const SizedBox(width: 8),
                              _ActionBtn2(
                                icon: Icons.delete_rounded,
                                label: 'Delete',
                                color: Colors.redAccent,
                                onTap: () => _delete(s['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _ActionBtn2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn2({required this.icon, required this.label,
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

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType? keyboardType;
  const _DialogField({required this.ctrl, required this.label,
      required this.hint, this.keyboardType});

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
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF3D4F6B)),
            filled: true,
            fillColor: const Color(0xFF0A0E1A),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF00E676), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}