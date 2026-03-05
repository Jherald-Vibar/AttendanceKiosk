// lib/screens/kiosk/subject_selection.dart

import 'package:Sentry/screens/kiosk/select_section.dart';
import 'package:flutter/material.dart';

class SubjectSelection extends StatefulWidget {
  final Map<String, dynamic> professor;
  final List<Map<String, dynamic>> subjects;

  const SubjectSelection({
    super.key,
    required this.professor,
    required this.subjects,
  });

  @override
  State<SubjectSelection> createState() => _SubjectSelectionState();
}

class _SubjectSelectionState extends State<SubjectSelection> {
  Map<String, List<Map<String, dynamic>>> _groupByYear() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final subject in widget.subjects) {
      final year = subject['year_level']?.toString() ?? 'Other';
      grouped.putIfAbsent(year, () => []).add(subject);
    }
    return grouped;
  }

  String _yearLabel(String yearKey) {
    const labels = {'1': '1st Year', '2': '2nd Year', '3': '3rd Year', '4': '4th Year'};
    return labels[yearKey] ?? yearKey;
  }

  List<Color> _gradientForIndex(int index) {
    const gradients = [
      [Color(0xFF00D4AA), Color(0xFF00B894)],
      [Color(0xFFFF9068), Color(0xFFFF6B6B)],
      [Color(0xFF4E9FFF), Color(0xFF0080FF)],
      [Color(0xFFB06AB3), Color(0xFF4568DC)],
      [Color(0xFFFFD93D), Color(0xFFFF9A3C)],
      [Color(0xFF6BCB77), Color(0xFF4D96FF)],
    ];
    return gradients[index % gradients.length];
  }

  IconData _iconForSubject(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('math') || lower.contains('calculus')) return Icons.calculate_outlined;
    if (lower.contains('history') || lower.contains('phil')) return Icons.edit_outlined;
    if (lower.contains('program') || lower.contains('data') || lower.contains('algo')) return Icons.memory;
    if (lower.contains('music')) return Icons.music_note_outlined;
    if (lower.contains('science') || lower.contains('physics') || lower.contains('chem')) return Icons.science_outlined;
    if (lower.contains('english') || lower.contains('lit')) return Icons.menu_book_outlined;
    if (lower.contains('network') || lower.contains('web')) return Icons.lan_outlined;
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByYear();
    final sortedYears = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    int cardIndex = 0;

    return PopScope(
      canPop: false, // kiosk — no back
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('SENTRY',
              style: TextStyle(fontFamily: 'sans', fontSize: 28, fontStyle: FontStyle.italic,
                  color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, letterSpacing: 2)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 20, backgroundColor: Colors.grey[300],
                child: Text(
                  (widget.professor['full_name'] as String? ?? 'P').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _buildProgressDot(true), _buildProgressLine(true),
                _buildProgressDot(true), _buildProgressLine(false),
                _buildProgressDot(false), _buildProgressLine(false),
                _buildProgressDot(false),
              ]),
            ),
            const SizedBox(height: 4),
            Text('Prof. ${widget.professor['full_name'] ?? ''}',
                style: const TextStyle(fontFamily: 'sans', fontSize: 13,
                    fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 2),
            Text('Select a Subject', style: TextStyle(fontFamily: 'sans', fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Expanded(
              child: widget.subjects.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No subjects assigned yet.', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                    ]))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final year in sortedYears) ...[
                            Text(_yearLabel(year), style: TextStyle(fontFamily: 'sans', fontSize: 18,
                                fontWeight: FontWeight.w600, color: Colors.grey[700])),
                            const SizedBox(height: 16),
                            ...() {
                              final yearSubjects = grouped[year]!;
                              final rows = <Widget>[];
                              for (int i = 0; i < yearSubjects.length; i += 2) {
                                final left = yearSubjects[i];
                                final right = i + 1 < yearSubjects.length ? yearSubjects[i + 1] : null;
                                rows.add(Row(children: [
                                  Expanded(child: _buildSubjectCard(
                                    left['subject_name'] ?? 'Subject',
                                    _iconForSubject(left['subject_name'] ?? ''),
                                    _gradientForIndex(cardIndex++), left,
                                  )),
                                  const SizedBox(width: 12),
                                  Expanded(child: right != null
                                      ? _buildSubjectCard(right['subject_name'] ?? 'Subject',
                                          _iconForSubject(right['subject_name'] ?? ''),
                                          _gradientForIndex(cardIndex++), right)
                                      : const SizedBox()),
                                ]));
                                if (i + 2 < yearSubjects.length) rows.add(const SizedBox(height: 12));
                              }
                              return rows;
                            }(),
                            const SizedBox(height: 24),
                          ],
                        ]),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    textStyle: const TextStyle(fontFamily: 'sans', fontSize: 18, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0,
                  ),
                  child: const Text('Next'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black, side: BorderSide(color: Colors.grey[300]!),
                    textStyle: const TextStyle(fontFamily: 'sans', fontSize: 18, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Back'),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) => Container(width: 12, height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.grey[600] : Colors.grey[300]));

  Widget _buildProgressLine(bool isActive) => Container(width: 40, height: 2,
      color: isActive ? Colors.grey[600] : Colors.grey[300]);

  Widget _buildSubjectCard(String title, IconData icon, List<Color> gradientColors, Map<String, dynamic> subject) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => SectionSelection(
          subjectName: title,
          subject: subject,
          professor: widget.professor, // ✅ pass professor through
        ),
      )),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(children: [
          Positioned(bottom: 12, right: 12,
              child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 48)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(alignment: Alignment.topLeft,
              child: Text(title, style: const TextStyle(fontFamily: 'sans', fontSize: 14,
                  fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
            ),
          ),
        ]),
      ),
    );
  }
}