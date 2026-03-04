// lib/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  // ── Hash password ─────────────────────────────────────────────────
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ── Init DB ───────────────────────────────────────────────────────
  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'sentry.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Admins ──────────────────────────────────────────────────────
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

    // ── Professors ───────────────────────────────────────────────────
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

    // ── Subjects ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_code TEXT NOT NULL UNIQUE,
        subject_name TEXT NOT NULL,
        units INTEGER DEFAULT 3,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // ── Sections ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section_name TEXT NOT NULL UNIQUE,
        course TEXT,
        year_level INTEGER,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // ── Professor ↔ Subject Assignment ───────────────────────────────
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

    // ── Subject ↔ Section Assignment ─────────────────────────────────
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

    // ── Students ─────────────────────────────────────────────────────
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

    // ── Attendance ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        subject_section_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time_in TEXT NOT NULL,
        status TEXT DEFAULT 'present',
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
        FOREIGN KEY (subject_section_id) REFERENCES subject_sections(id) ON DELETE CASCADE
      )
    ''');

    // ── Pre-seed Admin account ────────────────────────────────────────
    await db.insert('admins', {
      'username': 'admin',
      'password': hashPassword('admin123'),
      'full_name': 'System Administrator',
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════

  /// Returns admin map if credentials match, else null
  Future<Map<String, dynamic>?> loginAdmin(
      String username, String password) async {
    final db = await database;
    final result = await db.query(
      'admins',
      where: 'username = ? AND password = ?',
      whereArgs: [username, hashPassword(password)],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Returns professor map if credentials match, else null
  Future<Map<String, dynamic>?> loginProfessor(
      String username, String password) async {
    final db = await database;
    final result = await db.query(
      'professors',
      where: 'username = ? AND password = ?',
      whereArgs: [username, hashPassword(password)],
    );
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
    return db.insert('professors', hashed);
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
    return db.update('professors', updated, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProfessor(int id) async {
    final db = await database;
    return db.delete('professors', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveProfessorFaceEmbedding(int id, String embedding) async {
    final db = await database;
    return db.update(
      'professors',
      {'face_embedding': embedding},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUBJECTS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> insertSubject(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('subjects', data);
  }

  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    final db = await database;
    return db.query('subjects', orderBy: 'subject_name ASC');
  }

  Future<int> updateSubject(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('subjects', data, where: 'id = ?', whereArgs: [id]);
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
    return db.insert('sections', data);
  }

  Future<List<Map<String, dynamic>>> getAllSections() async {
    final db = await database;
    return db.query('sections', orderBy: 'section_name ASC');
  }

  Future<int> updateSection(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('sections', data, where: 'id = ?', whereArgs: [id]);
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
    return db.insert(
      'professor_subjects',
      {'professor_id': professorId, 'subject_id': subjectId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> removeSubjectFromProfessor(
      int professorId, int subjectId) async {
    final db = await database;
    return db.delete(
      'professor_subjects',
      where: 'professor_id = ? AND subject_id = ?',
      whereArgs: [professorId, subjectId],
    );
  }

  /// Get all subjects assigned to a professor
  Future<List<Map<String, dynamic>>> getSubjectsByProfessor(
      int professorId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.*, ps.assigned_at
      FROM subjects s
      JOIN professor_subjects ps ON s.id = ps.subject_id
      WHERE ps.professor_id = ?
      ORDER BY s.subject_name ASC
    ''', [professorId]);
  }

  /// Get all professors assigned to a subject
  Future<List<Map<String, dynamic>>> getProfessorsBySubject(
      int subjectId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT p.*, ps.assigned_at
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
    return db.insert(
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
  }

  Future<int> removeSectionFromSubject(
      int subjectId, int sectionId) async {
    final db = await database;
    return db.delete(
      'subject_sections',
      where: 'subject_id = ? AND section_id = ?',
      whereArgs: [subjectId, sectionId],
    );
  }

  /// Get all sections with their subject and professor info
  Future<List<Map<String, dynamic>>> getSubjectSectionsDetail() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        ss.id as subject_section_id,
        s.subject_code,
        s.subject_name,
        sec.section_name,
        sec.course,
        sec.year_level,
        p.full_name as professor_name,
        ss.schedule,
        ss.room
      FROM subject_sections ss
      JOIN subjects s ON ss.subject_id = s.id
      JOIN sections sec ON ss.section_id = sec.id
      LEFT JOIN professors p ON ss.professor_id = p.id
      ORDER BY s.subject_name ASC
    ''');
  }

  /// Get sections assigned to a subject
  Future<List<Map<String, dynamic>>> getSectionsBySubject(
      int subjectId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT sec.*, ss.schedule, ss.room, ss.professor_id,
             p.full_name as professor_name
      FROM sections sec
      JOIN subject_sections ss ON sec.id = ss.section_id
      LEFT JOIN professors p ON ss.professor_id = p.id
      WHERE ss.subject_id = ?
    ''', [subjectId]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // STUDENTS
  // ═══════════════════════════════════════════════════════════════════

  Future<int> insertStudent(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('students', data);
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    final db = await database;
    return db.rawQuery('''
      SELECT st.*, sec.section_name, sec.course
      FROM students st
      LEFT JOIN sections sec ON st.section_id = sec.id
      ORDER BY st.full_name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getStudentsBySection(
      int sectionId) async {
    final db = await database;
    return db.query(
      'students',
      where: 'section_id = ?',
      whereArgs: [sectionId],
      orderBy: 'full_name ASC',
    );
  }

  Future<int> updateStudent(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('students', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveStudentFaceEmbedding(int id, String embedding) async {
    final db = await database;
    return db.update(
      'students',
      {'face_embedding': embedding},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FACE EMBEDDINGS — get all for recognition
  // ═══════════════════════════════════════════════════════════════════

  /// Get all enrolled faces (students) for a section
  Future<List<Map<String, dynamic>>> getEnrolledFacesBySection(
      int sectionId) async {
    final db = await database;
    final result = await db.query(
      'students',
      where: 'section_id = ? AND face_embedding IS NOT NULL',
      whereArgs: [sectionId],
    );
    return result;
  }

  /// Get all enrolled faces (all students with face)
  Future<List<Map<String, dynamic>>> getAllEnrolledFaces() async {
    final db = await database;
    return db.query(
      'students',
      where: 'face_embedding IS NOT NULL',
    );
  }

  /// Save admin face embedding
  Future<int> saveAdminFaceEmbedding(int id, String embedding) async {
    final db = await database;
    return db.update(
      'admins',
      {'face_embedding': embedding},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ATTENDANCE
  // ═══════════════════════════════════════════════════════════════════

  Future<int> markAttendance({
    required int studentId,
    required int subjectSectionId,
    required String date,
    required String timeIn,
    String status = 'present',
  }) async {
    final db = await database;
    return db.insert('attendance', {
      'student_id': studentId,
      'subject_section_id': subjectSectionId,
      'date': date,
      'time_in': timeIn,
      'status': status,
    });
  }

  Future<bool> alreadyMarkedToday({
    required int studentId,
    required int subjectSectionId,
    required String date,
  }) async {
    final db = await database;
    final result = await db.query(
      'attendance',
      where:
          'student_id = ? AND subject_section_id = ? AND date = ?',
      whereArgs: [studentId, subjectSectionId, date],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAttendanceBySubjectSection(
      int subjectSectionId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.*, st.full_name, st.student_id as student_number
      FROM attendance a
      JOIN students st ON a.student_id = st.id
      WHERE a.subject_section_id = ?
      ORDER BY a.date DESC, a.time_in DESC
    ''', [subjectSectionId]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // DASHBOARD STATS
  // ═══════════════════════════════════════════════════════════════════

  Future<Map<String, int>> getDashboardStats() async {
    final db = await database;
    final professors =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM professors')) ?? 0;
    final subjects =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM subjects')) ?? 0;
    final sections =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sections')) ?? 0;
    final students =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM students')) ?? 0;
    return {
      'professors': professors,
      'subjects': subjects,
      'sections': sections,
      'students': students,
    };
  }
}