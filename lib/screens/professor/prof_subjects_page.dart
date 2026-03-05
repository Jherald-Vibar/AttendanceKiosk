// lib/screens/professor/prof_subjects_page.dart

import 'package:flutter/material.dart';
import 'package:Sentry/main.dart' show HomePage;
import 'package:flutter/services.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/screens/professor/prof_attendance_calendar.dart';
import 'package:Sentry/screens/professor/professor_dashboard.dart'
    show _LogoutDialog;

class ProfSubjectsPage extends StatefulWidget {
  final Map<String, dynamic> professor;
  const ProfSubjectsPage({super.key, required this.professor});

  @override
  State<ProfSubjectsPage> createState() => _ProfSubjectsPageState();
}

class _ProfSubjectsPageState extends State<ProfSubjectsPage> {
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance
        .getSubjectsByProfessor(widget.professor['id']);
    if (mounted) setState(() { _subjects = data; _loading = false; });
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
        // Gradient background — matches homepage exactly
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF82D8FF), Colors.white],
            ),
          ),
        ),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    // Avatar — black square like Login button
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black,
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
                          Text(
                            widget.professor['full_name'],
                            style: const TextStyle(
                              color: Color(0xFF1C2536),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.professor['department'] ??
                                'Professor',
                            style: TextStyle(
                                color: const Color(0xFF1C2536)
                                    .withOpacity(0.5),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Logout pill — same style as homepage "Kiosk Mode"
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.black.withOpacity(0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 14, color: Color(0xFF1C2536)),
                            SizedBox(width: 6),
                            Text('Logout',
                                style: TextStyle(
                                  color: Color(0xFF1C2536),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('My Subjects',
                    style: TextStyle(
                      color: Color(0xFF1C2536),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    )),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF82D8FF)))
                    : _subjects.isEmpty
                        ? _EmptyState(
                            icon: Icons.menu_book_rounded,
                            message:
                                'No subjects assigned yet.\nContact your admin.',
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF82D8FF),
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 24),
                              itemCount: _subjects.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _SubjectCard(
                                subject: _subjects[i],
                                professor: widget.professor,
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Subject Card ──────────────────────────────────────────────────────────

class _SubjectCard extends StatefulWidget {
  final Map<String, dynamic> subject;
  final Map<String, dynamic> professor;
  const _SubjectCard({required this.subject, required this.professor});

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _expanded = false;
  List<Map<String, dynamic>> _sections = [];
  bool _loadingSections = false;

  Future<void> _loadSections() async {
    setState(() => _loadingSections = true);
    final all =
        await DatabaseHelper.instance.getSubjectSectionsDetail();
    final filtered = all
        .where((r) =>
            r['subject_id'].toString() ==
                widget.subject['id'].toString() &&
            r['professor_id'].toString() ==
                widget.professor['id'].toString())
        .toList();
    setState(() {
      _sections = filtered;
      _loadingSections = false;
    });
  }

  void _toggle() {
    if (!_expanded) _loadSections();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Subject header row
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.subject['subject_code'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subject['subject_name'],
                            style: const TextStyle(
                                color: Color(0xFF1C2536),
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text('${widget.subject['units']} units',
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.4),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),

          // Expandable sections
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Colors.black.withOpacity(0.06)))),
              child: _loadingSections
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF82D8FF),
                              strokeWidth: 2)),
                    )
                  : _sections.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No sections assigned for this subject.',
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.4),
                                fontSize: 13),
                          ),
                        )
                      : Column(
                          children: _sections
                              .map((sec) => _SectionTile(
                                    section: sec,
                                    subject: widget.subject,
                                  ))
                              .toList(),
                        ),
            ),
        ],
      ),
    );
  }
}

// ── Section Tile ──────────────────────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  final Map<String, dynamic> section;
  final Map<String, dynamic> subject;
  const _SectionTile({required this.section, required this.subject});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfAttendanceCalendar(
            section: section,
            subject: subject,
          ),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF82D8FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.groups_rounded,
                  color: Color(0xFF1C2536), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section['section_name'],
                      style: const TextStyle(
                          color: Color(0xFF1C2536),
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    '${section['course'] ?? ''}'
                    '${section['year_level'] != null ? ' · Year ${section['year_level']}' : ''}',
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.black.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

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
          Icon(icon, size: 56, color: Colors.black.withOpacity(0.12)),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.4), fontSize: 14)),
        ],
      ),
    );
  }
}