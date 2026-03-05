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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getAllSubjects();
    setState(() {
      _subjects = data;
      _loading = false;
    });
  }

  void _showSubjectDialog({Map<String, dynamic>? subject}) {
    final codeCtrl = TextEditingController(text: subject?['subject_code'] ?? '');
    final nameCtrl = TextEditingController(text: subject?['subject_name'] ?? '');
    final unitsCtrl = TextEditingController(
        text: subject?['units']?.toString() ?? '3');
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 20),
              _DialogField(ctrl: codeCtrl, label: 'Subject Code', hint: 'e.g. CS101'),
              const SizedBox(height: 12),
              _DialogField(ctrl: nameCtrl, label: 'Subject Name', hint: 'e.g. Programming 1'),
              const SizedBox(height: 12),
              _DialogField(
                  ctrl: unitsCtrl,
                  label: 'Units',
                  hint: '3',
                  keyboardType: TextInputType.number),
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

  // ── Assign Sections Dialog ─────────────────────────────────────────
  // Fixed: reloads assigned sections from DB after every change
  // Fixed: professor is now REQUIRED when assigning a section
  void _showAssignDialog(Map<String, dynamic> subject) async {
    // ✅ Only load professors assigned to THIS subject
    final assignedProfessors = await DatabaseHelper.instance
        .getProfessorsBySubject(subject['id']);
    final sections = await DatabaseHelper.instance.getAllSections();

    if (!mounted) return;

    if (assignedProfessors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No professor assigned to this subject yet.\nGo to Manage Professors → assign this subject first.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _AssignSectionsDialog(
        subject: subject,
        professors: assignedProfessors,
        sections: sections,
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _subjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 56,
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
                                      color: const Color(0xFF00E676)
                                          .withOpacity(0.3)),
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

// ── Assign Sections Dialog (stateful widget so it can reload from DB) ──────

class _AssignSectionsDialog extends StatefulWidget {
  final Map<String, dynamic> subject;
  final List<Map<String, dynamic>> professors;
  final List<Map<String, dynamic>> sections;

  const _AssignSectionsDialog({
    required this.subject,
    required this.professors,
    required this.sections,
  });

  @override
  State<_AssignSectionsDialog> createState() => _AssignSectionsDialogState();
}

class _AssignSectionsDialogState extends State<_AssignSectionsDialog> {
  // Maps section_id → assigned professor name (for display)
  Map<int, String> _assignedSections = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reloadAssigned();
  }

  // ✅ Always reload from DB — no stale local state
  Future<void> _reloadAssigned() async {
    setState(() => _loading = true);
    final rows = await DatabaseHelper.instance
        .getSectionsBySubject(widget.subject['id']);
    final map = <int, String>{};
    for (final r in rows) {
      // DB query aliases sections.id as 'section_id' to avoid collisions
      final rawId = r['section_id'];
      if (rawId == null) continue;
      final sectionId = rawId is int ? rawId : int.tryParse(rawId.toString());
      if (sectionId == null) continue;
      map[sectionId] = r['professor_name']?.toString() ?? 'No professor';
    }
    setState(() {
      _assignedSections = map;
      _loading = false;
    });
  }

  // ✅ Professor is now REQUIRED — no "skip" option
  Future<int?> _pickProfessor() async {
    if (widget.professors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No professors available. Add a professor first.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return null;
    }

    return showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C2536),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Professor',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'A professor is required to assign a section.',
                style: TextStyle(color: Color(0xFF8B9DC3), fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF1E2D45)),
              ...widget.professors.map((p) => ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          p['full_name'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    title: Text(p['full_name'],
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    subtitle: Text(p['employee_id'],
                        style: const TextStyle(
                            color: Color(0xFF8B9DC3), fontSize: 12)),
                    onTap: () => Navigator.pop(ctx, p['id'] as int),
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  int _toInt(dynamic v) => v is int ? v : int.parse(v.toString());

  Future<void> _assign(Map<String, dynamic> section) async {
    int? profId;

    if (widget.professors.length == 1) {
      // ✅ Only one professor assigned to this subject — auto-select, no dialog
      profId = _toInt(widget.professors.first['id']);
    } else {
      // Multiple professors — let user pick
      profId = await _pickProfessor();
      if (profId == null) return; // cancelled
    }

    await DatabaseHelper.instance.assignSectionToSubject(
      subjectId: _toInt(widget.subject['id']),
      sectionId: _toInt(section['id']),
      professorId: profId,
    );
    await _reloadAssigned();
  }

  Future<void> _unassign(Map<String, dynamic> section) async {
    await DatabaseHelper.instance.removeSectionFromSubject(
      _toInt(widget.subject['id']),
      _toInt(section['id']),
    );
    await _reloadAssigned();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              // Header
              const Text('Assign Sections',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              Text(widget.subject['subject_name'],
                  style: const TextStyle(
                      color: Color(0xFF00E676), fontSize: 13)),
              const SizedBox(height: 16),

              const Text('Sections',
                  style: TextStyle(
                      color: Color(0xFF8B9DC3),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              // Section list
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00E676), strokeWidth: 2))
                    : widget.sections.isEmpty
                        ? const Center(
                            child: Text('No sections available.',
                                style: TextStyle(color: Color(0xFF8B9DC3))))
                        : ListView.builder(
                            itemCount: widget.sections.length,
                            itemBuilder: (_, i) {
                              final sec = widget.sections[i];
                              final rawSecId = sec['id']; // getAllSections uses direct query — column is 'id'
                              final sectionId = rawSecId is int ? rawSecId : int.parse(rawSecId.toString());
                              final isAssigned =
                                  _assignedSections.containsKey(sectionId);
                              final profName =
                                  _assignedSections[sectionId] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isAssigned
                                      ? const Color(0xFF00E676).withOpacity(0.05)
                                      : const Color(0xFF0A0E1A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAssigned
                                        ? const Color(0xFF00E676).withOpacity(0.3)
                                        : const Color(0xFF1E2D45),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                  leading: Icon(
                                    isAssigned
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isAssigned
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFF3D4F6B),
                                    size: 22,
                                  ),
                                  title: Text(
                                    sec['section_name'],
                                    style: TextStyle(
                                      color: isAssigned
                                          ? Colors.white
                                          : const Color(0xFF8B9DC3),
                                      fontSize: 14,
                                      fontWeight: isAssigned
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${sec['course'] ?? ''}'
                                        '${sec['year_level'] != null ? ' · Year ${sec['year_level']}' : ''}',
                                        style: const TextStyle(
                                            color: Color(0xFF8B9DC3),
                                            fontSize: 11),
                                      ),
                                      if (isAssigned)
                                        Text(
                                          '👤 $profName',
                                          style: const TextStyle(
                                            color: Color(0xFF00D4FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: isAssigned
                                      ? GestureDetector(
                                          onTap: () => _unassign(sec),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.redAccent
                                                      .withOpacity(0.3)),
                                            ),
                                            child: const Text('Remove',
                                                style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: () => _assign(sec),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E676)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: const Color(0xFF00E676)
                                                      .withOpacity(0.3)),
                                            ),
                                            child: const Text('Assign',
                                                style: TextStyle(
                                                    color: Color(0xFF00E676),
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────

class _ActionBtn2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn2({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

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
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
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

  const _DialogField({
    required this.ctrl,
    required this.label,
    required this.hint,
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
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF3D4F6B)),
            filled: true,
            fillColor: const Color(0xFF0A0E1A),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF00E676), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}