// lib/screens/admin/manage_professors.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/screens/admin/professor_form.dart';
import 'package:Sentry/screens/admin/face_registration_screen.dart';

class ManageProfessors extends StatefulWidget {
  const ManageProfessors({super.key});

  @override
  State<ManageProfessors> createState() => _ManageProfessorsState();
}

class _ManageProfessorsState extends State<ManageProfessors> {
  List<Map<String, dynamic>> _professors = [];
  List<Map<String, dynamic>> _filtered = [];
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
    final data = await DatabaseHelper.instance.getAllProfessors();
    setState(() {
      _professors = data;
      _filtered = data;
      _loading = false;
    });
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _professors.where((p) =>
        p['full_name'].toString().toLowerCase().contains(q) ||
        p['employee_id'].toString().toLowerCase().contains(q) ||
        (p['department'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    });
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2536),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Professor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Remove $name? This will also remove their assignments.',
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
      await DatabaseHelper.instance.deleteProfessor(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Professors',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF00D4FF), size: 28),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfessorForm()))
              .then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search professors...',
                hintStyle: const TextStyle(color: Color(0xFF8B9DC3)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B9DC3)),
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
                : _filtered.isEmpty
                    ? const _EmptyState(
                        icon: Icons.school_rounded,
                        message: 'No professors yet.\nTap + to add one.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = _filtered[i];
                          final hasFace = p['face_embedding'] != null;
                          return _ProfessorTile(
                            professor: p,
                            hasFace: hasFace,
                            onEdit: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ProfessorForm(professor: p)))
                              .then((_) => _load()),
                            onDelete: () => _delete(p['id'], p['full_name']),
                            onFaceRegister: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => FaceRegistrationScreen(
                                personId: p['id'],
                                personName: p['full_name'],
                                type: FaceRegType.professor,
                              )))
                              .then((_) => _load()),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Professor Tile ─────────────────────────────────────────────────────────

class _ProfessorTile extends StatefulWidget {
  final Map<String, dynamic> professor;
  final bool hasFace;
  final VoidCallback onEdit, onDelete, onFaceRegister;

  const _ProfessorTile({
    required this.professor,
    required this.hasFace,
    required this.onEdit,
    required this.onDelete,
    required this.onFaceRegister,
  });

  @override
  State<_ProfessorTile> createState() => _ProfessorTileState();
}

class _ProfessorTileState extends State<_ProfessorTile> {
  bool _showSubjects = false;
  List<Map<String, dynamic>> _assignedSubjects = [];
  List<Map<String, dynamic>> _allSubjects = [];
  bool _loadingSubjects = false;

  Future<void> _loadSubjects() async {
    setState(() => _loadingSubjects = true);
    final assigned = await DatabaseHelper.instance
        .getSubjectsByProfessor(widget.professor['id']);
    final all = await DatabaseHelper.instance.getAllSubjects();
    setState(() {
      _assignedSubjects = assigned;
      _allSubjects = all;
      _loadingSubjects = false;
    });
  }

  void _toggleSubjectsPanel() {
    if (!_showSubjects) _loadSubjects();
    setState(() => _showSubjects = !_showSubjects);
  }

  Future<void> _addSubject(Map<String, dynamic> subject) async {
    await DatabaseHelper.instance.assignSubjectToProfessor(
      widget.professor['id'],
      subject['id'],
    );
    await _loadSubjects();
  }

  Future<void> _removeSubject(Map<String, dynamic> subject) async {
    await DatabaseHelper.instance.removeSubjectFromProfessor(
      widget.professor['id'],
      subject['id'],
    );
    await _loadSubjects();
  }

  void _showAddSubjectSheet() {
    // Subjects not yet assigned
    final assignedIds = _assignedSubjects.map((s) => s['id']).toSet();
    final available = _allSubjects
        .where((s) => !assignedIds.contains(s['id']))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2536),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8B9DC3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assign Subject',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'All subjects are already assigned.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final s = available[i];
                    return ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.book_outlined,
                            color: Color(0xFF00D4FF), size: 18),
                      ),
                      title: Text(
                        s['subject_name'],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        s['subject_code'],
                        style: const TextStyle(color: Color(0xFF8B9DC3), fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add_circle_outline_rounded,
                          color: Color(0xFF00D4FF)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _addSubject(s);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2D45)),
      ),
      child: Column(
        children: [
          // ── Main professor info ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          widget.professor['full_name']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.professor['full_name'],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text(widget.professor['employee_id'],
                              style: const TextStyle(
                                  color: Color(0xFF00D4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          if (widget.professor['department'] != null)
                            Text(widget.professor['department'],
                                style: const TextStyle(
                                    color: Color(0xFF8B9DC3), fontSize: 12)),
                        ],
                      ),
                    ),
                    // Face badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.hasFace
                            ? const Color(0xFF00E676).withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.hasFace
                              ? const Color(0xFF00E676).withOpacity(0.4)
                              : Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.hasFace
                                ? Icons.face_rounded
                                : Icons.face_retouching_off_rounded,
                            color: widget.hasFace
                                ? const Color(0xFF00E676)
                                : Colors.orange,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.hasFace ? 'Face ✓' : 'No Face',
                            style: TextStyle(
                              color: widget.hasFace
                                  ? const Color(0xFF00E676)
                                  : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Action buttons ──────────────────────────────────
                Row(
                  children: [
                    _ActionBtn(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: const Color(0xFF00D4FF),
                        onTap: widget.onEdit),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.face_retouching_natural_rounded,
                      label: widget.hasFace ? 'Re-scan' : 'Face',
                      color: const Color(0xFFFFB800),
                      onTap: widget.onFaceRegister,
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                        icon: Icons.delete_rounded,
                        label: 'Delete',
                        color: Colors.redAccent,
                        onTap: widget.onDelete),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Subjects toggle button ──────────────────────────
                GestureDetector(
                  onTap: _toggleSubjectsPanel,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF7C3AED).withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.book_rounded,
                            color: Color(0xFF7C3AED), size: 14),
                        const SizedBox(width: 6),
                        const Text(
                          'Subjects',
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _showSubjects
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF7C3AED),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Subjects Panel (inline, collapsible) ──────────────────
          if (_showSubjects)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF1E2D45)),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: _loadingSubjects
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            color: Color(0xFF00D4FF), strokeWidth: 2),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Assigned Subjects (${_assignedSubjects.length})',
                              style: const TextStyle(
                                color: Color(0xFF8B9DC3),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            GestureDetector(
                              onTap: _showAddSubjectSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D4FF)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF00D4FF)
                                          .withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        color: Color(0xFF00D4FF), size: 13),
                                    SizedBox(width: 4),
                                    Text('Add',
                                        style: TextStyle(
                                          color: Color(0xFF00D4FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Assigned subject chips
                        if (_assignedSubjects.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No subjects assigned yet.\nTap Add to assign one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _assignedSubjects.map((subject) {
                              return _SubjectChip(
                                subject: subject,
                                onRemove: () => _removeSubject(subject),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Subject Chip ───────────────────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onRemove;

  const _SubjectChip({required this.subject, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.book_outlined, color: Color(0xFF7C3AED), size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              subject['subject_name'],
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD8B4FE),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF7C3AED), size: 13),
          ),
        ],
      ),
    );
  }
}

// ── Action Button ──────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
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
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 56,
              color: const Color(0xFF8B9DC3).withOpacity(0.3)),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF8B9DC3), fontSize: 14)),
        ],
      ),
    );
  }
}