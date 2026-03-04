// lib/screens/admin/manage_sections.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';

class ManageSections extends StatefulWidget {
  const ManageSections({super.key});

  @override
  State<ManageSections> createState() => _ManageSectionsState();
}

class _ManageSectionsState extends State<ManageSections>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sections = await DatabaseHelper.instance.getAllSections();
    final assignments =
        await DatabaseHelper.instance.getSubjectSectionsDetail();
    setState(() {
      _sections = sections;
      _assignments = assignments;
      _loading = false;
    });
  }

  void _showSectionDialog({Map<String, dynamic>? section}) {
    final nameCtrl = TextEditingController(text: section?['section_name'] ?? '');
    final courseCtrl = TextEditingController(text: section?['course'] ?? '');
    int? yearLevel = section?['year_level'];
    final isEdit = section != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: const Color(0xFF1C2536),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit Section' : 'Add Section',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 20),
                _DialogField2(ctrl: nameCtrl, label: 'Section Name *',
                    hint: 'e.g. BSCS-3A'),
                const SizedBox(height: 12),
                _DialogField2(ctrl: courseCtrl, label: 'Course',
                    hint: 'e.g. BSCS'),
                const SizedBox(height: 12),
                const Text('Year Level',
                    style: TextStyle(color: Color(0xFF8B9DC3),
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2, 3, 4].map((y) {
                    final selected = yearLevel == y;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setStateDialog(() => yearLevel = y),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFB800)
                                : const Color(0xFF0A0E1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFFB800)
                                  : const Color(0xFF1E2D45),
                            ),
                          ),
                          child: Center(
                            child: Text('$y',
                                style: TextStyle(
                                  color: selected
                                      ? Colors.black
                                      : const Color(0xFF8B9DC3),
                                  fontWeight: FontWeight.w800,
                                )),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
                          if (nameCtrl.text.isEmpty) return;
                          final data = {
                            'section_name': nameCtrl.text.trim(),
                            'course': courseCtrl.text.trim(),
                            'year_level': yearLevel,
                          };
                          if (isEdit) {
                            await DatabaseHelper.instance
                                .updateSection(section!['id'], data);
                          } else {
                            await DatabaseHelper.instance.insertSection(data);
                          }
                          Navigator.pop(ctx);
                          _load();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB800),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Sections',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFFFFB800), size: 28),
            onPressed: () => _showSectionDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFB800),
          labelColor: const Color(0xFFFFB800),
          unselectedLabelColor: const Color(0xFF8B9DC3),
          tabs: const [
            Tab(text: 'Sections'),
            Tab(text: 'Assignments'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFFFFB800)))
          : TabBarView(
              controller: _tabController,
              children: [
                // ── Sections Tab ──────────────────────────────────
                _sections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.groups_rounded, size: 56,
                                color: const Color(0xFF8B9DC3).withOpacity(0.3)),
                            const SizedBox(height: 14),
                            const Text('No sections yet.\nTap + to add one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF8B9DC3))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = _sections[i];
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF1E2D45)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB800).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                        color: const Color(0xFFFFB800).withOpacity(0.3)),
                                  ),
                                  child: const Icon(Icons.groups_rounded,
                                      color: Color(0xFFFFB800), size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['section_name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          )),
                                      if (s['course'] != null)
                                        Text(
                                          '${s['course']}${s['year_level'] != null ? ' · Year ${s['year_level']}' : ''}',
                                          style: const TextStyle(
                                              color: Color(0xFF8B9DC3),
                                              fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showSectionDialog(section: s),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00D4FF).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.edit_rounded,
                                            color: Color(0xFF00D4FF), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        await DatabaseHelper.instance
                                            .deleteSection(s['id']);
                                        _load();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.delete_rounded,
                                            color: Colors.redAccent, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // ── Assignments Tab ───────────────────────────────
                _assignments.isEmpty
                    ? const Center(
                        child: Text('No assignments yet.',
                            style: TextStyle(color: Color(0xFF8B9DC3))))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final a = _assignments[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
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
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(a['subject_code'],
                                          style: const TextStyle(
                                            color: Color(0xFF00E676),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          )),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(a['subject_name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          )),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.groups_rounded,
                                        color: Color(0xFFFFB800), size: 14),
                                    const SizedBox(width: 6),
                                    Text(a['section_name'],
                                        style: const TextStyle(
                                            color: Color(0xFFFFB800),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    if (a['professor_name'] != null) ...[
                                      const SizedBox(width: 12),
                                      const Icon(Icons.person_rounded,
                                          color: Color(0xFF8B9DC3), size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(a['professor_name'],
                                            style: const TextStyle(
                                                color: Color(0xFF8B9DC3),
                                                fontSize: 12)),
                                      ),
                                    ],
                                  ],
                                ),
                                if (a['schedule'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text('📅 ${a['schedule']}',
                                      style: const TextStyle(
                                          color: Color(0xFF8B9DC3), fontSize: 12)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}

class _DialogField2 extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  const _DialogField2({required this.ctrl, required this.label, required this.hint});

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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFFFB800), width: 1.5)),
          ),
        ),
      ],
    );
  }
}