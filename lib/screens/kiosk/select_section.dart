// lib/screens/kiosk/select_section.dart

import 'package:Sentry/screens/kiosk/student_scanner.dart';
import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';

class SectionSelection extends StatefulWidget {
  final String subjectName;

  const SectionSelection({super.key, required this.subjectName});

  @override
  State<SectionSelection> createState() => _SectionSelectionState();
}

class _SectionSelectionState extends State<SectionSelection> {
  // Now stores the full assignment map (has id + section_name)
  Map<String, dynamic>? _selectedAssignment;

  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    // Load all subject-section assignments from DB
    final all = await DatabaseHelper.instance.getSubjectSectionsDetail();

    // Filter only those matching the current subject
    final filtered = all
        .where((a) =>
            a['subject_name'].toString().toLowerCase() ==
            widget.subjectName.toLowerCase())
        .toList();

    // If no match by name, show all (fallback)
    setState(() {
      _assignments = filtered.isNotEmpty ? filtered : all;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox(),
        title: const Text(
          'SENTRY',
          style: TextStyle(
            fontFamily: 'sans',
            fontSize: 28,
            fontStyle: FontStyle.italic,
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress indicator ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProgressDot(true),
                _buildProgressLine(true),
                _buildProgressDot(true),
                _buildProgressLine(true),
                _buildProgressDot(true),
                _buildProgressLine(false),
                _buildProgressDot(false),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Select a Section',
            style: TextStyle(
              fontFamily: 'sans',
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 16),

          // Subject name
          Text(
            widget.subjectName,
            style: const TextStyle(
              fontFamily: 'sans',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 20),

          // ── Sections grid ─────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1E3A8A)))
                : _assignments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.groups_rounded,
                                size: 56,
                                color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'No sections found for\n${widget.subjectName}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ask the admin to assign sections.',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: _assignments.length,
                            itemBuilder: (context, index) {
                              return _buildSectionCard(
                                  _assignments[index]);
                            },
                          ),
                        ),
                      ),
          ),

          const SizedBox(height: 16),

          // ── Next button ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedAssignment != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentScanner(
                              // ✅ Pass the REAL subject_section_id
                              subjectSectionId:
                                  _selectedAssignment!['subject_section_id'],
                              sectionName:
                                  _selectedAssignment!['section_name'],
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  textStyle: const TextStyle(
                    fontFamily: 'sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text("Next"),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Back button ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.grey[300]!),
                  textStyle: const TextStyle(
                    fontFamily: 'sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Back"),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Section card — same design as yours ─────────────────────────────
  Widget _buildSectionCard(Map<String, dynamic> assignment) {
    final isSelected = _selectedAssignment?['subject_section_id'] ==
        assignment['subject_section_id'];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedAssignment = assignment);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9068), Color(0xFFFF6B6B)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 3)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 12,
              right: 12,
              child: Icon(
                Icons.groups_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 40,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section name
                  Text(
                    assignment['section_name'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'sans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Course info
                  if (assignment['course'] != null)
                    Text(
                      assignment['course'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  // Professor
                  if (assignment['professor_name'] != null)
                    Text(
                      assignment['professor_name'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Selected checkmark
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.grey[600] : Colors.grey[300],
      ),
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      color: isActive ? Colors.grey[600] : Colors.grey[300],
    );
  }
}