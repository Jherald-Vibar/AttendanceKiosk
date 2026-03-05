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

  @override
  Widget build(BuildContext context) {
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
                      // Back button — same pill style
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
                      // Total attendance badge
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
                                if (_selectedRecords.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_selectedRecords.length} present',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ── Attendance list ───────────────────
                            if (_selectedRecords.isEmpty)
                              _AttendanceEmpty(
                                  hasDay: _selectedDay != null)
                            else
                              ..._selectedRecords.map(
                                  (r) => _AttendanceRow(record: r)),
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

  String _dayLabel(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    const wd = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    return '${wd[d.weekday % 7]}, ${m[d.month - 1]} ${d.day}, ${d.year}';
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

    // Build grid rows
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
          // Month navigation
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
          // Day labels
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

// ── Attendance row ────────────────────────────────────────────────────────

class _AttendanceRow extends StatelessWidget {
  final Map<String, dynamic> record;
  const _AttendanceRow({required this.record});

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

  @override
  Widget build(BuildContext context) {
    final isOut = record['status'] == 'time_out';
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
              color: const Color(0xFF82D8FF).withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                record['full_name']
                    .toString()
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF1C2536),
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record['full_name'],
                    style: const TextStyle(
                        color: Color(0xFF1C2536),
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(record['student_number'] ?? '',
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatTime(record['time_in']),
                  style: const TextStyle(
                      color: Color(0xFF1C2536),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isOut
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOut ? 'Time Out' : 'Time In',
                  style: TextStyle(
                      color: isOut
                          ? Colors.orange[800]
                          : Colors.green[700],
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
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