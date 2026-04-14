// lib/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:Sentry/services/sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'sentry.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        face_embedding TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE professors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        email TEXT,
        department TEXT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        face_embedding TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_code TEXT NOT NULL UNIQUE,
        subject_name TEXT NOT NULL,
        units INTEGER DEFAULT 3,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section_name TEXT NOT NULL UNIQUE,
        course TEXT,
        year_level INTEGER,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE professor_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        professor_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        assigned_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (professor_id) REFERENCES professors(id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        UNIQUE(professor_id, subject_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE subject_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        section_id INTEGER NOT NULL,
        professor_id INTEGER,
        schedule TEXT,
        room TEXT,
        assigned_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE,
        FOREIGN KEY (professor_id) REFERENCES professors(id) ON DELETE SET NULL,
        UNIQUE(subject_id, section_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        email TEXT,
        section_id INTEGER,
        face_embedding TEXT,
        registered_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        subject_section_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time_in TEXT NOT NULL,
        time_out TEXT,
        status TEXT DEFAULT 'present',
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
        FOREIGN KEY (subject_section_id) REFERENCES subject_sections(id) ON DELETE CASCADE,
        UNIQUE(student_id, subject_section_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.insert('admins', {
      'username': 'admin',
      'password': hashPassword('admin123'),
      'full_name': 'System Administrator',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE attendance ADD COLUMN time_out TEXT');

      final timeOutRows = await db.rawQuery('''
        SELECT * FROM attendance WHERE status = 'time_out'
      ''');

      for (final row in timeOutRows) {
        final matching = await db.rawQuery('''
          SELECT id FROM attendance
          WHERE student_id = ?
            AND subject_section_id = ?
            AND date = ?
            AND status != 'time_out'
          LIMIT 1
        ''', [row['student_id'], row['subject_section_id'], row['date']]);

        if (matching.isNotEmpty) {
          await db.update(
            'attendance',
            {
              'time_out': row['time_in'],
              'status': 'completed',
            },
            where: 'id = ?',
            whereArgs: [matching.first['id']],
          );
        }
        await db.delete('attendance',
            where: 'id = ?', whereArgs: [row['id']]);
      }

      await db.execute('ALTER TABLE attendance RENAME TO attendance_old');
      await db.execute('''
        CREATE TABLE attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          subject_section_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          time_in TEXT NOT NULL,
          time_out TEXT,
          status TEXT DEFAULT 'present',
          FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
          FOREIGN KEY (subject_section_id) REFERENCES subject_sections(id) ON DELETE CASCADE,
          UNIQUE(student_id, subject_section_id, date)
        )
      ''');
      await db.execute('''
        INSERT INTO attendance
          (id, student_id, subject_section_id, date, time_in, time_out, status)
        SELECT
          id, student_id, subject_section_id, date, time_in, time_out, status
        FROM attendance_old
      ''');
      await db.execute('DROP TABLE attendance_old');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT DEFAULT (datetime('now'))
        )
      ''');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // SEED FROM SUPABASE (new device / first launch)
  // ═══════════════════════════════════════════════════════════════════

  /// Pulls all data from Supabase and inserts into local SQLite.
  /// Uses ConflictAlgorithm.replace so it is safe to call again
  /// if you want to force a full re-sync.
  Future<void> seedFromSupabase() async {
    await SyncService.instance.pullAll((table, rows) async {
      final db = await database;
      for (final row in rows) {
        try {
          switch (table) {
            case 'professors':
              await db.insert('professors', row,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              break;
            case 'subjects':
              await db.insert('subjects', row,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              break;
            case 'sections':
              await db.insert('sections', row,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              break;
            case 'professor_subjects':
              await db.insert('professor_subjects', row,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              break;
            case 'subject_sections':
              await db.insert('subject_sections', row,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              break;
            case 'students':
              await db.insert('students', row,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              break;
            case 'attendance':
              await db.insert('attendance', row,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              break;
          }
        } catch (e) {
          print('Seed error ($table): $e');
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> loginAdmin(
      String username, String password) async {
    final db = await database;
    final result = await db.query('admins',
        where: 'username = ? AND password = ?',
        whereArgs: [username, hashPassword(password)]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    final db = await database;
    return db.query('admins', where: 'face_embedding IS NOT NULL');
  }

  Future<Map<String, dynamic>?> loginProfessor(
      String username, String password) async {
    final db = await database;
    final result = await db.query('professors',
        where: 'username = ? AND password = ?',
        whereArgs: [username, hashPassword(password)]);
    return result.isNotEmpty ? result.first : null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROFESSORS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> insertProfessor(Map<String, dynamic> data) async {
    final db = await database;
    final hashed = Map<String, dynamic>.from(data);
    if (hashed['password'] != null) {
      hashed['password'] = hashPassword(hashed['password']);
    }
    final id = await db.insert('professors', hashed);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(hashed)..['id'] = id;
    await SyncService.instance.pushProfessor(toSync);
    // ────────────────────────────────────────────────────────────────

    return id;
  }

  Future<List<Map<String, dynamic>>> getAllProfessors() async {
    final db = await database;
    return db.query('professors', orderBy: 'full_name ASC');
  }

  Future<Map<String, dynamic>?> getProfessorById(int id) async {
    final db = await database;
    final result =
        await db.query('professors', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateProfessor(int id, Map<String, dynamic> data) async {
    final db = await database;
    final updated = Map<String, dynamic>.from(data);
    if (updated['password'] != null) {
      updated['password'] = hashPassword(updated['password']);
    }
    final count = await db.update('professors', updated,
        where: 'id = ?', whereArgs: [id]);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(updated)..['id'] = id;
    await SyncService.instance.pushProfessor(toSync);
    // ────────────────────────────────────────────────────────────────

    return count;
  }

  Future<int> deleteProfessor(int id) async {
    final db = await database;
    return db.delete('professors', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveProfessorFaceEmbedding(int id, String embedding) async {
    final db = await database;
    return db.update('professors', {'face_embedding': embedding},
        where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUBJECTS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> insertSubject(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('subjects', data);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(data)..['id'] = id;
    await SyncService.instance.pushSubject(toSync);
    // ────────────────────────────────────────────────────────────────

    return id;
  }

  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    final db = await database;
    return db.query('subjects', orderBy: 'subject_name ASC');
  }

  Future<int> updateSubject(int id, Map<String, dynamic> data) async {
    final db = await database;
    final count =
        await db.update('subjects', data, where: 'id = ?', whereArgs: [id]);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(data)..['id'] = id;
    await SyncService.instance.pushSubject(toSync);
    // ────────────────────────────────────────────────────────────────

    return count;
  }

  Future<int> deleteSubject(int id) async {
    final db = await database;
    return db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECTIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> insertSection(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('sections', data);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(data)..['id'] = id;
    await SyncService.instance.pushSection(toSync);
    // ────────────────────────────────────────────────────────────────

    return id;
  }

  Future<List<Map<String, dynamic>>> getAllSections() async {
    final db = await database;
    return db.query('sections', orderBy: 'section_name ASC');
  }

  Future<int> updateSection(int id, Map<String, dynamic> data) async {
    final db = await database;
    final count =
        await db.update('sections', data, where: 'id = ?', whereArgs: [id]);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(data)..['id'] = id;
    await SyncService.instance.pushSection(toSync);
    // ────────────────────────────────────────────────────────────────

    return count;
  }

  Future<int> deleteSection(int id) async {
    final db = await database;
    return db.delete('sections', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROFESSOR ↔ SUBJECT ASSIGNMENTS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> assignSubjectToProfessor(
      int professorId, int subjectId) async {
    final db = await database;
    final id = await db.insert(
      'professor_subjects',
      {'professor_id': professorId, 'subject_id': subjectId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // ── SYNC ────────────────────────────────────────────────────────
    if (id > 0) {
      await SyncService.instance.pushProfessorSubject({
        'id': id,
        'professor_id': professorId,
        'subject_id': subjectId,
      });
    }
    // ────────────────────────────────────────────────────────────────

    return id;
  }

  Future<int> removeSubjectFromProfessor(
      int professorId, int subjectId) async {
    final db = await database;
    return db.delete('professor_subjects',
        where: 'professor_id = ? AND subject_id = ?',
        whereArgs: [professorId, subjectId]);
  }

  Future<List<Map<String, dynamic>>> getSubjectsByProfessor(
      int professorId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        s.id          AS id,
        s.subject_code,
        s.subject_name,
        s.units,
        ps.assigned_at
      FROM subjects s
      JOIN professor_subjects ps ON s.id = ps.subject_id
      WHERE ps.professor_id = ?
      ORDER BY s.subject_name ASC
    ''', [professorId]);
  }

  Future<List<Map<String, dynamic>>> getProfessorsBySubject(
      int subjectId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        p.id          AS id,
        p.employee_id,
        p.full_name,
        p.department,
        ps.assigned_at
      FROM professors p
      JOIN professor_subjects ps ON p.id = ps.professor_id
      WHERE ps.subject_id = ?
      ORDER BY p.full_name ASC
    ''', [subjectId]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUBJECT ↔ SECTION ASSIGNMENTS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> assignSectionToSubject({
    required int subjectId,
    required int sectionId,
    int? professorId,
    String? schedule,
    String? room,
  }) async {
    final db = await database;
    final id = await db.insert(
      'subject_sections',
      {
        'subject_id': subjectId,
        'section_id': sectionId,
        'professor_id': professorId,
        'schedule': schedule,
        'room': room,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // ── SYNC ────────────────────────────────────────────────────────
    await SyncService.instance.pushSubjectSection({
      'id': id,
      'subject_id': subjectId,
      'section_id': sectionId,
      'professor_id': professorId,
      'schedule': schedule,
      'room': room,
    });
    // ────────────────────────────────────────────────────────────────

    return id;
  }

  Future<int> removeSectionFromSubject(
      int subjectId, int sectionId) async {
    final db = await database;
    return db.delete('subject_sections',
        where: 'subject_id = ? AND section_id = ?',
        whereArgs: [subjectId, sectionId]);
  }

  Future<List<Map<String, dynamic>>> getSubjectSectionsDetail() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        ss.id           AS subject_section_id,
        s.id            AS subject_id,
        s.subject_code,
        s.subject_name,
        sec.id          AS section_id,
        sec.section_name,
        sec.course,
        sec.year_level,
        p.id            AS professor_id,
        p.full_name     AS professor_name,
        ss.schedule,
        ss.room
      FROM subject_sections ss
      JOIN subjects s     ON ss.subject_id  = s.id
      JOIN sections sec   ON ss.section_id  = sec.id
      LEFT JOIN professors p ON ss.professor_id = p.id
      ORDER BY s.subject_name ASC, sec.section_name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getSectionsBySubject(
      int subjectId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        ss.id           AS subject_section_id,
        sec.id          AS section_id,
        sec.section_name,
        sec.course,
        sec.year_level,
        ss.schedule,
        ss.room,
        p.id            AS professor_id,
        p.full_name     AS professor_name
      FROM subject_sections ss
      JOIN sections sec   ON ss.section_id  = sec.id
      LEFT JOIN professors p ON ss.professor_id = p.id
      WHERE ss.subject_id = ?
      ORDER BY sec.section_name ASC
    ''', [subjectId]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // STUDENTS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> insertStudent(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('students', data);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(data)..['id'] = id;
    await SyncService.instance.pushStudent(toSync);
    // ────────────────────────────────────────────────────────────────

    return id;
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        st.id           AS id,
        st.student_id,
        st.full_name,
        st.email,
        st.section_id,
        st.face_embedding,
        st.registered_at,
        sec.section_name,
        sec.course
      FROM students st
      LEFT JOIN sections sec ON st.section_id = sec.id
      ORDER BY st.full_name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getStudentsBySection(
      int sectionId) async {
    final db = await database;
    return db.query('students',
        where: 'section_id = ?',
        whereArgs: [sectionId],
        orderBy: 'full_name ASC');
  }

  Future<int> updateStudent(int id, Map<String, dynamic> data) async {
    final db = await database;
    final count =
        await db.update('students', data, where: 'id = ?', whereArgs: [id]);

    // ── SYNC ────────────────────────────────────────────────────────
    final toSync = Map<String, dynamic>.from(data)..['id'] = id;
    await SyncService.instance.pushStudent(toSync);
    // ────────────────────────────────────────────────────────────────

    return count;
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveStudentFaceEmbedding(int id, String embedding) async {
    final db = await database;
    return db.update('students', {'face_embedding': embedding},
        where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // FACE EMBEDDINGS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getEnrolledFacesBySection(
      int sectionId) async {
    final db = await database;
    return db.query('students',
        where: 'section_id = ? AND face_embedding IS NOT NULL',
        whereArgs: [sectionId]);
  }

  Future<List<Map<String, dynamic>>> getEnrolledFacesBySubjectSection(
      int subjectSectionId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        st.id           AS id,
        st.full_name,
        st.face_embedding,
        sec.section_name
      FROM students st
      JOIN sections sec ON st.section_id = sec.id
      JOIN subject_sections ss ON ss.section_id = sec.id
      WHERE ss.id = ? AND st.face_embedding IS NOT NULL
      ORDER BY st.full_name ASC
    ''', [subjectSectionId]);
  }

  Future<List<Map<String, dynamic>>> getAllEnrolledFaces() async {
    final db = await database;
    return db.query('students', where: 'face_embedding IS NOT NULL');
  }

  Future<int> saveAdminFaceEmbedding(int id, String embedding) async {
    final db = await database;
    return db.update('admins', {'face_embedding': embedding},
        where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ATTENDANCE
  // ═══════════════════════════════════════════════════════════════════

  /// Records a time-in. Each student gets ONE row per class day.
  /// UNIQUE(student_id, subject_section_id, date) prevents duplicates.
  Future<int> markAttendance({
    required int studentId,
    required int subjectSectionId,
    required String date,
    required String timeIn,
  }) async {
    final db = await database;
    final id = await db.insert(
      'attendance',
      {
        'student_id': studentId,
        'subject_section_id': subjectSectionId,
        'date': date,
        'time_in': timeIn,
        'status': 'present',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // ── SYNC ────────────────────────────────────────────────────────
    if (id > 0) {
      await SyncService.instance.pushAttendance({
        'id': id,
        'student_id': studentId,
        'subject_section_id': subjectSectionId,
        'date': date,
        'time_in': timeIn,
        'status': 'present',
      });
    }
    // ────────────────────────────────────────────────────────────────

    return id;
  }

  /// Records a time-out by updating the existing attendance row for today.
  /// Returns true if a row was found and updated, false if no time-in exists.
  Future<bool> markTimeOut({
    required int studentId,
    required int subjectSectionId,
    required String date,
    required String timeOut,
  }) async {
    final db = await database;
    final count = await db.update(
      'attendance',
      {
        'time_out': timeOut,
        'status': 'completed',
      },
      where: 'student_id = ? AND subject_section_id = ? AND date = ?',
      whereArgs: [studentId, subjectSectionId, date],
    );

    // ── SYNC ────────────────────────────────────────────────────────
    if (count > 0) {
      final row = await getAttendanceForToday(
        studentId: studentId,
        subjectSectionId: subjectSectionId,
        date: date,
      );
      if (row != null) {
        await SyncService.instance.pushAttendance({
          'id': row['id'],
          'student_id': studentId,
          'subject_section_id': subjectSectionId,
          'date': date,
          'time_in': row['time_in'],
          'time_out': timeOut,
          'status': 'completed',
        });
      }
    }
    // ────────────────────────────────────────────────────────────────

    return count > 0;
  }

  /// Returns the attendance row for a student on a specific day, or null.
  Future<Map<String, dynamic>?> getAttendanceForToday({
    required int studentId,
    required int subjectSectionId,
    required String date,
  }) async {
    final db = await database;
    final result = await db.query(
      'attendance',
      where: 'student_id = ? AND subject_section_id = ? AND date = ?',
      whereArgs: [studentId, subjectSectionId, date],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// True if the student already has a time-in row today.
  Future<bool> alreadyMarkedToday({
    required int studentId,
    required int subjectSectionId,
    required String date,
  }) async {
    final row = await getAttendanceForToday(
      studentId: studentId,
      subjectSectionId: subjectSectionId,
      date: date,
    );
    return row != null;
  }

  /// True if the student has timed in but NOT yet timed out today.
  Future<bool> hasTimedInButNotOut({
    required int studentId,
    required int subjectSectionId,
    required String date,
  }) async {
    final row = await getAttendanceForToday(
      studentId: studentId,
      subjectSectionId: subjectSectionId,
      date: date,
    );
    return row != null && row['time_out'] == null;
  }

  /// Fetch all attendance rows for a subject-section, each row is one
  /// student for one day. Includes time_out and student_id for the scanner.
  Future<List<Map<String, dynamic>>> getAttendanceBySubjectSection(
      int subjectSectionId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        a.id,
        a.student_id,
        a.date,
        a.time_in,
        a.time_out,
        a.status,
        st.full_name,
        st.student_id AS student_number
      FROM attendance a
      JOIN students st ON a.student_id = st.id
      WHERE a.subject_section_id = ?
      ORDER BY a.date DESC, a.time_in ASC
    ''', [subjectSectionId]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // DASHBOARD STATS
  // ═══════════════════════════════════════════════════════════════════

  Future<Map<String, int>> getDashboardStats() async {
    final db = await database;
    final professors = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM professors')) ??
        0;
    final subjects = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM subjects')) ??
        0;
    final sections = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM sections')) ??
        0;
    final students = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM students')) ??
        0;
    return {
      'professors': professors,
      'subjects': subjects,
      'sections': sections,
      'students': students,
    };
  }
}