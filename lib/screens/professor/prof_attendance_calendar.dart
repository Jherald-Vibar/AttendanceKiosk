// lib/screens/professor/prof_attendance_calendar.dart

import 'package:flutter/material.dart';
import 'package:Sentry/database/database_helper.dart';

class ProfAttendanceCalendar extends StatefulWidget {
  final Map<String, dynamic> section;
  final Map<String, dynamic> subject;

  const ProfAttendanceCalendar({
    super.key,
    required this.section,
    required this.subject,
  });

  @override
  State<ProfAttendanceCalendar> createState() =>
      _ProfAttendanceCalendarState();
}

class _ProfAttendanceCalendarState
    extends State<ProfAttendanceCalendar> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Map<String, dynamic>>> _byDate = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final id = widget.section['subject_section_id'];
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final records = await DatabaseHelper.instance
        .getAttendanceBySubjectSection(id);
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in records) {
      map.putIfAbsent(r['date'].toString(), () => []).add(r);
    }
    if (mounted) setState(() { _byDate = map; _loading = false; });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> get _selectedRecords =>
      _selectedDay != null ? (_byDate[_fmt(_selectedDay!)] ?? []) : [];

  /// Each student now has ONE row in the DB with time_in + time_out columns.
  /// Just map each row directly — no merging needed.
  List<_StudentAttendance> get _groupedAttendance {
    final map = <dynamic, _StudentAttendance>{};
    for (final r in _selectedRecords) {
      final sid = r['student_id'] ?? r['id'];
      map[sid] = _StudentAttendance(
        studentId: sid,
        fullName: r['full_name'] ?? '',
        studentNumber: r['student_number'] ?? '',
        timeIn: r['time_in'] as String?,
        timeOut: r['time_out'] as String?,   // real column, null if not timed out yet
      );
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedAttendance;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient — matches homepage
          Container(
            height: 200,
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
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    Colors.black.withOpacity(0.12)),
                          ),
                          child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF1C2536),
                              size: 15),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(widget.section['section_name'],
                                style: const TextStyle(
                                    color: Color(0xFF1C2536),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(widget.subject['subject_name'],
                                style: TextStyle(
                                    color: Colors.black
                                        .withOpacity(0.45),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      // Total attendance badge — unique days
                      if (!_loading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    Colors.black.withOpacity(0.12)),
                          ),
                          child: Text(
                            '${_byDate.length} days',
                            style: const TextStyle(
                                color: Color(0xFF1C2536),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF82D8FF)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 32),
                          children: [
                            // ── Calendar card ─────────────────────
                            _CalendarCard(
                              focusedMonth: _focusedMonth,
                              selectedDay: _selectedDay,
                              daysWithData: _byDate.keys.toSet(),
                              onDayTap: (d) =>
                                  setState(() => _selectedDay = d),
                              onPrevMonth: () => setState(() {
                                _focusedMonth = DateTime(
                                    _focusedMonth.year,
                                    _focusedMonth.month - 1);
                              }),
                              onNextMonth: () => setState(() {
                                _focusedMonth = DateTime(
                                    _focusedMonth.year,
                                    _focusedMonth.month + 1);
                              }),
                            ),

                            const SizedBox(height: 20),

                            // ── Day header ────────────────────────
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDay != null
                                      ? _dayLabel(_selectedDay!)
                                      : 'Select a day',
                                  style: const TextStyle(
                                      color: Color(0xFF1C2536),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                                Row(
                                  children: [
                                    if (grouped.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${grouped.length} student${grouped.length == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // 👁 Section preview button
                                      GestureDetector(
                                        onTap: () =>
                                            _showSectionPreview(grouped),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF82D8FF)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: const Color(0xFF82D8FF)
                                                    .withOpacity(0.4)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                  Icons.remove_red_eye_rounded,
                                                  size: 13,
                                                  color: Color(0xFF1565C0)),
                                              SizedBox(width: 5),
                                              Text('Preview',
                                                  style: TextStyle(
                                                      color: Color(0xFF1565C0),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ── Attendance list ───────────────────
                            if (grouped.isEmpty)
                              _AttendanceEmpty(
                                  hasDay: _selectedDay != null)
                            else
                              ...grouped.map(
                                  (s) => _AttendanceRow(student: s)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSectionPreview(List<_StudentAttendance> students) {
    final presentCount = students.where((s) => s.isPresent).length;
    final timeInOnlyCount = students.where((s) => s.isTimeInOnly).length;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C2536),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.groups_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.section['section_name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _selectedDay != null
                                    ? _dayLabel(_selectedDay!)
                                    : '',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogCtx),
                          child: Icon(Icons.close_rounded,
                              color: Colors.white.withOpacity(0.5), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Summary chips
                    Row(
                      children: [
                        _SummaryChip(
                          label: 'Total',
                          count: students.length,
                          color: Colors.white.withOpacity(0.15),
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          label: 'Present',
                          count: presentCount,
                          color: Colors.green.withOpacity(0.25),
                          textColor: Colors.greenAccent,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          label: 'Time In',
                          count: timeInOnlyCount,
                          color: const Color(0xFF82D8FF).withOpacity(0.2),
                          textColor: const Color(0xFF82D8FF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Student list ─────────────────────────────────────
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = students[i];
                    return _SectionPreviewRow(student: s);
                  },
                ),
              ),

              // ── Close button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2536),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    const wd = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    return '${wd[d.weekday % 7]}, ${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Data model for a grouped student attendance entry ─────────────────────

class _StudentAttendance {
  final dynamic studentId;
  final String fullName;
  final String studentNumber;
  final String? timeIn;
  final String? timeOut;

  const _StudentAttendance({
    required this.studentId,
    required this.fullName,
    required this.studentNumber,
    this.timeIn,
    this.timeOut,
  });

  /// Has both time in and time out → fully present
  bool get isPresent => timeIn != null && timeOut != null;

  /// Has only time in → partial / time-in only
  bool get isTimeInOnly => timeIn != null && timeOut == null;

  _StudentAttendance copyWith({String? timeIn, String? timeOut}) {
    return _StudentAttendance(
      studentId: studentId,
      fullName: fullName,
      studentNumber: studentNumber,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
    );
  }
}

// ── Calendar card widget ──────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final Set<String> daysWithData;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _CalendarCard({
    required this.focusedMonth,
    required this.selectedDay,
    required this.daysWithData,
    required this.onDayTap,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime d) {
    const m = ['January','February','March','April','May','June',
                'July','August','September','October','November','December'];
    return '${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) cells.add(const SizedBox());

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(focusedMonth.year, focusedMonth.month, day);
      final dateStr = _fmt(date);
      final hasData = daysWithData.contains(dateStr);
      final isSel = selectedDay != null && _fmt(selectedDay!) == dateStr;
      final isToday = _fmt(today) == dateStr;

      cells.add(GestureDetector(
        onTap: () => onDayTap(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSel
                ? Colors.black
                : isToday
                    ? const Color(0xFF82D8FF).withOpacity(0.25)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isToday && !isSel
                ? Border.all(color: const Color(0xFF82D8FF), width: 1.5)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                    color: isSel ? Colors.white : const Color(0xFF1C2536),
                    fontSize: 13,
                    fontWeight: isSel || isToday
                        ? FontWeight.w800
                        : FontWeight.normal,
                  )),
              if (hasData && !isSel)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      final end = (i + 7 > cells.length) ? cells.length : i + 7;
      final row = List<Widget>.from(cells.sublist(i, end));
      while (row.length < 7) row.add(const SizedBox());
      rows.add(Row(
          children: row
              .map((c) =>
                  Expanded(child: AspectRatio(aspectRatio: 1, child: c)))
              .toList()));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MonthBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPrevMonth),
                Text(_monthLabel(focusedMonth),
                    style: const TextStyle(
                        color: Color(0xFF1C2536),
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                _MonthBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNextMonth),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                  color: Colors.black.withOpacity(0.35),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _MonthBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MonthBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF1C2536), size: 20),
      ),
    );
  }
}

// ── Attendance row — now uses _StudentAttendance ──────────────────────────

class _AttendanceRow extends StatelessWidget {
  final _StudentAttendance student;
  const _AttendanceRow({required this.student});

  String _formatTime(String? raw) {
    if (raw == null) return '--:--';
    try {
      final p = raw.split(':');
      int h = int.parse(p[0]);
      final mn = p[1];
      final ap = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return '$h:$mn $ap';
    } catch (_) {
      return raw;
    }
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: student.isPresent
                        ? [
                            Colors.green.withOpacity(0.15),
                            const Color(0xFF82D8FF).withOpacity(0.10),
                          ]
                        : [
                            const Color(0xFF82D8FF).withOpacity(0.15),
                            Colors.white,
                          ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: student.isPresent
                            ? Colors.green.withOpacity(0.15)
                            : const Color(0xFF82D8FF).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          student.fullName.isNotEmpty
                              ? student.fullName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF1C2536),
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(
                              color: Color(0xFF1C2536),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student.studentNumber,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: student.isPresent
                            ? Colors.green.withOpacity(0.12)
                            : const Color(0xFF82D8FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        student.isPresent ? 'Present' : 'Time In',
                        style: TextStyle(
                          color: student.isPresent
                              ? Colors.green[700]
                              : const Color(0xFF1565C0),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Time details ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Time In row
                    _PreviewTimeRow(
                      icon: Icons.login_rounded,
                      iconColor: Colors.green[600]!,
                      iconBg: Colors.green.withOpacity(0.1),
                      label: 'Time In',
                      time: _formatTime(student.timeIn),
                    ),

                    if (student.isPresent) ...[
                      const SizedBox(height: 1),
                      // Connector line
                      Padding(
                        padding: const EdgeInsets.only(left: 19),
                        child: Row(
                          children: [
                            Container(
                              width: 2,
                              height: 16,
                              color: Colors.black.withOpacity(0.08),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      // Time Out row
                      _PreviewTimeRow(
                        icon: Icons.logout_rounded,
                        iconColor: Colors.orange[700]!,
                        iconBg: Colors.orange.withOpacity(0.1),
                        label: 'Time Out',
                        time: _formatTime(student.timeOut),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14,
                                color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Student has not timed out yet',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C2536),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Close',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final Color badgeTextColor;
    final String badgeLabel;
    final Color avatarBg;

    if (student.isPresent) {
      badgeColor = Colors.green.withOpacity(0.1);
      badgeTextColor = Colors.green[700]!;
      badgeLabel = 'Present';
      avatarBg = Colors.green.withOpacity(0.12);
    } else {
      badgeColor = const Color(0xFF82D8FF).withOpacity(0.2);
      badgeTextColor = const Color(0xFF1565C0);
      badgeLabel = 'Time In';
      avatarBg = const Color(0xFF82D8FF).withOpacity(0.25);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: avatarBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                student.fullName.isNotEmpty
                    ? student.fullName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Color(0xFF1C2536),
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + student number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName,
                    style: const TextStyle(
                        color: Color(0xFF1C2536),
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(student.studentNumber,
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 11)),
              ],
            ),
          ),

          // Time + badge + preview button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (student.isPresent) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(student.timeIn),
                            style: const TextStyle(
                                color: Color(0xFF1C2536),
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 11, color: Color(0xFF8B9DC3)),
                        ),
                        Text(_formatTime(student.timeOut),
                            style: const TextStyle(
                                color: Color(0xFF1C2536),
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ],
                    ),
                  ] else ...[
                    Text(_formatTime(student.timeIn),
                        style: const TextStyle(
                            color: Color(0xFF1C2536),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              // 👁 Preview button
              GestureDetector(
                onTap: () => _showPreview(context),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: Colors.black.withOpacity(0.08)),
                  ),
                  child: const Icon(Icons.remove_red_eye_rounded,
                      size: 16, color: Color(0xFF1C2536)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Summary chip (used in section preview header) ─────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color textColor;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
            color: textColor, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Row used inside the section preview dialog ────────────────────────────

class _SectionPreviewRow extends StatelessWidget {
  final _StudentAttendance student;
  const _SectionPreviewRow({required this.student});

  String _fmt(String? raw) {
    if (raw == null) return '--:--';
    try {
      final p = raw.split(':');
      int h = int.parse(p[0]);
      final mn = p[1];
      final ap = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return '$h:$mn $ap';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPresent = student.isPresent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: isPresent
                  ? Colors.green.withOpacity(0.12)
                  : const Color(0xFF82D8FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                student.fullName.isNotEmpty
                    ? student.fullName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Color(0xFF1C2536),
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName,
                    style: const TextStyle(
                        color: Color(0xFF1C2536),
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text(student.studentNumber,
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.38),
                        fontSize: 11)),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Time in → time out
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Time In
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.login_rounded,
                      size: 11, color: Colors.green[600]),
                  const SizedBox(width: 3),
                  Text(_fmt(student.timeIn),
                      style: const TextStyle(
                          color: Color(0xFF1C2536),
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ],
              ),
              const SizedBox(height: 3),
              // Time Out
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded,
                      size: 11,
                      color: isPresent
                          ? Colors.orange[700]
                          : Colors.black26),
                  const SizedBox(width: 3),
                  Text(
                    isPresent ? _fmt(student.timeOut) : '--:--',
                    style: TextStyle(
                        color: isPresent
                            ? const Color(0xFF1C2536)
                            : Colors.black26,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 10),

          // Status dot
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPresent ? Colors.green : const Color(0xFF82D8FF),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preview time row helper ───────────────────────────────────────────────

class _PreviewTimeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String time;

  const _PreviewTimeRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                  fontSize: 13)),
        ),
        Text(time,
            style: const TextStyle(
                color: Color(0xFF1C2536),
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      ],
    );
  }
}

// ── Empty attendance state ────────────────────────────────────────────────

class _AttendanceEmpty extends StatelessWidget {
  final bool hasDay;
  const _AttendanceEmpty({required this.hasDay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded,
                size: 48, color: Colors.black.withOpacity(0.12)),
            const SizedBox(height: 12),
            Text(
              hasDay
                  ? 'No attendance on this day'
                  : 'Tap a date to view attendance',
              style: TextStyle(
                  color: Colors.black.withOpacity(0.35), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}