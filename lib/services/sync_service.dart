// lib/services/sync_service.dart

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _client = Supabase.instance.client;
  bool _isOnline = false;

  Future<void> init() async {
    final current = await Connectivity().checkConnectivity();
    _isOnline = current != ConnectivityResult.none;
    Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  // ═══════════════════════════════════════════
  // FACE EMBEDDINGS → Supabase Storage
  // ═══════════════════════════════════════════

  Future<String?> uploadFaceEmbedding({
    required String type, // 'students' or 'professors'
    required int id,
    required String embeddingJson,
  }) async {
    if (!_isOnline) return null;
    try {
      final path = 'embeddings/$type/$id.json';
      final bytes = utf8.encode(embeddingJson);
      await _client.storage
          .from('face-embeddings')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return path;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<String?> downloadFaceEmbedding({
    required String type,
    required int id,
  }) async {
    if (!_isOnline) return null;
    try {
      final path = 'embeddings/$type/$id.json';
      final bytes = await _client.storage
          .from('face-embeddings')
          .download(path);
      return utf8.decode(bytes);
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════
  // PUSH: Local → Supabase
  // ═══════════════════════════════════════════

  Future<void> pushAttendance(Map<String, dynamic> row) async {
    if (!_isOnline) return;
    try {
      await _client.from('attendance').upsert(row);
    } catch (e) {
      print('Sync attendance error: $e');
    }
  }

  Future<void> pushStudent(Map<String, dynamic> row) async {
    if (!_isOnline) return;
    try {
      final sanitized = Map<String, dynamic>.from(row)
        ..remove('face_embedding')
        ..remove('embedding_path');
      await _client.from('students').upsert(sanitized);
    } catch (e) {
      print('Sync student error: $e');
    }
  }

  Future<void> pushProfessor(Map<String, dynamic> row) async {
    if (!_isOnline) return;
    try {
      final sanitized = Map<String, dynamic>.from(row)
        ..remove('face_embedding');
      // password is sha256 hashed — safe to sync
      await _client.from('professors').upsert(sanitized);
    } catch (e) {
      print('Sync professor error: $e');
    }
  }

  Future<void> pushSubject(Map<String, dynamic> row) async {
    if (!_isOnline) return;
    try {
      await _client.from('subjects').upsert(row);
    } catch (e) {
      print('Sync subject error: $e');
    }
  }

  Future<void> pushSection(Map<String, dynamic> row) async {
    if (!_isOnline) return;
    try {
      await _client.from('sections').upsert(row);
    } catch (e) {
      print('Sync section error: $e');
    }
  }

  Future<void> pushSubjectSection(Map<String, dynamic> row) async {
    if (!_isOnline) return;
    try {
      await _client.from('subject_sections').upsert(row);
    } catch (e) {
      print('Sync subject_section error: $e');
    }
  }

  Future<void> pushProfessorSubject(Map<String, dynamic> row) async {
    if (!_isOnline) return;
    try {
      await _client.from('professor_subjects').upsert(row);
    } catch (e) {
      print('Sync professor_subject error: $e');
    }
  }

  // ═══════════════════════════════════════════
  // REAL-TIME LISTENER
  // ═══════════════════════════════════════════

  /// Listen to live attendance for a specific class session.
  /// Use this in your attendance/scanner screen.
  RealtimeChannel listenToAttendance({
    required int subjectSectionId,
    required String date,
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function(Map<String, dynamic> row) onUpdate,
  }) {
    return _client
        .channel('attendance_${subjectSectionId}_$date')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'attendance',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['subject_section_id'] == subjectSectionId &&
                row['date'] == date) {
              onInsert(row);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'attendance',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['subject_section_id'] == subjectSectionId &&
                row['date'] == date) {
              onUpdate(row);
            }
          },
        )
        .subscribe();
  }

  // ═══════════════════════════════════════════
  // PULL: Supabase → Local (new device setup)
  // ═══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> pullAttendance(
      int subjectSectionId) async {
    try {
      final result = await _client
          .from('attendance')
          .select()
          .eq('subject_section_id', subjectSectionId);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Pull attendance error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullStudents() async {
    try {
      final result = await _client.from('students').select();
      return List<Map<String, dynamic>>.from(result).map((row) {
        return Map<String, dynamic>.from(row)
          ..remove('face_embedding')
          ..remove('embedding_path');
      }).toList();
    } catch (e) {
      print('Pull students error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullProfessors() async {
    try {
      final result = await _client.from('professors').select();
      return List<Map<String, dynamic>>.from(result).map((row) {
        final clean = Map<String, dynamic>.from(row)
          ..remove('face_embedding');
        if (clean['password'] == null) clean['password'] = '';
        return clean;
      }).toList();
    } catch (e) {
      print('Pull professors error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullSubjects() async {
    try {
      final result = await _client.from('subjects').select();
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Pull subjects error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullSections() async {
    try {
      final result = await _client.from('sections').select();
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Pull sections error: $e');
      return [];
    }
  }

  /// Full pull — seeds local SQLite from Supabase.
  /// Call this on first launch or when setting up a new device.
  /// Each table is wrapped in its own try/catch so one failure
  /// does not abort the remaining tables.
  Future<void> pullAll(
      Function(String table, List<Map<String, dynamic>> rows) onData) async {
    if (!_isOnline) {
      print('pullAll: skipped — device is offline');
      return;
    }

    final session = _client.auth.currentSession;
    print('pullAll: starting — session=${session == null ? 'anon' : 'authenticated'}');

    // Order matters: parent tables before child tables (FK constraints).
    final tables = [
      'professors',
      'subjects',
      'sections',
      'professor_subjects',
      'subject_sections',
      'students',
      'attendance',
    ];

    for (final table in tables) {
      try {
        final result = await _client.from(table).select();
        var rows = List<Map<String, dynamic>>.from(result);

        print('pullAll: $table → ${rows.length} rows fetched');

        switch (table) {
          case 'professors':
            rows = rows.map((row) {
              final clean = Map<String, dynamic>.from(row)
                ..remove('face_embedding');
              // Replace NULL password to satisfy SQLite NOT NULL constraint.
              // Permanent fix: run in Supabase SQL editor:
              // UPDATE professors SET password = '' WHERE password IS NULL;
              if (clean['password'] == null) clean['password'] = '';
              return clean;
            }).toList();
            break;

          case 'students':
            rows = rows.map((row) {
              return Map<String, dynamic>.from(row)
                ..remove('face_embedding')
                ..remove('embedding_path'); // Supabase-only column, not in local SQLite schema
            }).toList();
            break;
        }

        onData(table, rows);
      } catch (e) {
        print('pullAll: ERROR on $table → $e');
        // Continue to next table — do NOT rethrow.
      }
    }

    print('pullAll: done');
  }
}