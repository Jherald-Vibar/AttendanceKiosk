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
    setState(() { _professors = data; _filtered = data; _loading = false; });
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
                    color: Color(0xFF00D4FF)))
                : _filtered.isEmpty
                    ? _EmptyState(
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
                              MaterialPageRoute(builder: (_) =>
                                ProfessorForm(professor: p)))
                              .then((_) => _load()),
                            onDelete: () => _delete(p['id'], p['full_name']),
                            onFaceRegister: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                FaceRegistrationScreen(
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

class _ProfessorTile extends StatelessWidget {
  final Map<String, dynamic> professor;
  final bool hasFace;
  final VoidCallback onEdit, onDelete, onFaceRegister;

  const _ProfessorTile({
    required this.professor, required this.hasFace,
    required this.onEdit, required this.onDelete,
    required this.onFaceRegister,
  });

  @override
  Widget build(BuildContext context) {
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
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    professor['full_name'].toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(professor['full_name'],
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(professor['employee_id'],
                        style: const TextStyle(color: Color(0xFF00D4FF),
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    if (professor['department'] != null)
                      Text(professor['department'],
                          style: const TextStyle(color: Color(0xFF8B9DC3),
                              fontSize: 12)),
                  ],
                ),
              ),
              // Face badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasFace
                      ? const Color(0xFF00E676).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFace
                        ? const Color(0xFF00E676).withOpacity(0.4)
                        : Colors.orange.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasFace ? Icons.face_rounded : Icons.face_retouching_off_rounded,
                      color: hasFace ? const Color(0xFF00E676) : Colors.orange,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasFace ? 'Face ✓' : 'No Face',
                      style: TextStyle(
                        color: hasFace ? const Color(0xFF00E676) : Colors.orange,
                        fontSize: 10, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              _ActionBtn(icon: Icons.edit_rounded, label: 'Edit',
                  color: const Color(0xFF00D4FF), onTap: onEdit),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.face_retouching_natural_rounded,
                label: hasFace ? 'Re-scan Face' : 'Register Face',
                color: const Color(0xFFFFB800), onTap: onFaceRegister,
              ),
              const SizedBox(width: 8),
              _ActionBtn(icon: Icons.delete_rounded, label: 'Delete',
                  color: Colors.redAccent, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
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
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

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
          Icon(icon, size: 56, color: const Color(0xFF8B9DC3).withOpacity(0.3)),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8B9DC3), fontSize: 14)),
        ],
      ),
    );
  }
}