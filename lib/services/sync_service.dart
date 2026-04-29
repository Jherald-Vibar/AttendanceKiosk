// lib/services/sync_service.dart

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:Sentry/database/database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _client = Supabase.instance.client;
  bool _isOnline = false;
  final List<RealtimeChannel> _channels = [];

  // ═══════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════

  Future<void> init() async {
    // FIX: connectivity_plus v5+ returns List<ConnectivityResult>
    final results = await Connectivity().checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);

    Connectivity().onConnectivityChanged.listen((results) async {
      final wasOffline = !_isOnline;

      // FIX: results is now List<ConnectivityResult> in newer versions
      _isOnline = !results.contains(ConnectivityResult.none);

      if (wasOffline && _isOnline) {
        print('🌐 Back online — flushing queue + re-seeding...');
        await flushQueue();
        await _seedAll();
      }
    });

    if (_isOnline) await _seedAll();
    _startRealtimeListeners();
  }

  /// Call this from your app's WidgetsBindingObserver.didChangeAppLifecycleState
  /// when AppLifecycleState.resumed — ensures queue is flushed even if the
  /// connectivity stream missed the reconnect event.
  Future<void> syncOnResume() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    if (_isOnline) {
      print('🔄 syncOnResume: online — flushing queue...');
      await flushQueue();
    } else {
      print('🔄 syncOnResume: still offline — skipping flush');
    }
  }

  // ═══════════════════════════════════════════
  // SEED: Supabase → Local SQLite (on every launch)
  // ═══════════════════════════════════════════

  Future<void> _seedAll() async {
    if (!_isOnline) return;

    final db = await DatabaseHelper.instance.database;

    // Order matters — parent tables before child tables (FK constraints)
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

        rows = _sanitize(table, rows);

        print('🌱 Seeding $table → ${rows.length} rows');

        final batch = db.batch();
        for (final row in rows) {
          batch.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      } catch (e) {
        print('❌ Seed error on $table: $e');
        // Continue to next table — do NOT rethrow
      }
    }

    print('✅ Seed complete');
  }

  // ═══════════════════════════════════════════
  // REALTIME: Live listeners for all tables
  // ═══════════════════════════════════════════

  void _startRealtimeListeners() {
    // Unsubscribe existing channels first (safe re-init)
    for (final ch in _channels) {
      _client.removeChannel(ch);
    }
    _channels.clear();

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
      final channel = _client
          .channel('live_$table')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: table,
            callback: (payload) => _handleLiveRow(table, payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            callback: (payload) => _handleLiveRow(table, payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: table,
            callback: (payload) => _handleLiveDelete(table, payload.oldRecord),
          )
          .subscribe((status, [error]) {
            if (error != null) {
              print('❌ Realtime error [$table]: $error');
            } else {
              print('📡 Realtime [$table]: $status');
            }
          });

      _channels.add(channel);
    }
  }

  Future<void> _handleLiveRow(
      String table, Map<String, dynamic> row) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final sanitized = _sanitize(table, [row]).first;
      await db.insert(
        table,
        sanitized,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('⚡ Live upsert → $table');
    } catch (e) {
      print('❌ Live upsert error on $table: $e');
    }
  }

  Future<void> _handleLiveDelete(
      String table, Map<String, dynamic> row) async {
    // Supabase requires REPLICA IDENTITY FULL on the table for oldRecord to be populated
    // Run: ALTER TABLE <table> REPLICA IDENTITY FULL;
    if (row.isEmpty) {
      print(
          '⚠️ Live delete on $table — oldRecord empty. Enable REPLICA IDENTITY FULL.');
      return;
    }
    try {
      final db = await DatabaseHelper.instance.database;
      final id = row['id'];
      if (id != null) {
        await db.delete(table, where: 'id = ?', whereArgs: [id]);
        print('🗑️ Live delete → $table #$id');
      }
    } catch (e) {
      print('❌ Live delete error on $table: $e');
    }
  }

  // ═══════════════════════════════════════════
  // HELPER: Strip fields that shouldn't be stored locally
  // ═══════════════════════════════════════════

  List<Map<String, dynamic>> _sanitize(
      String table, List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final clean = Map<String, dynamic>.from(row);
      switch (table) {
        case 'professors':
          clean.remove('face_embedding');
          clean['password'] ??= '';
          break;
        case 'students':
          clean.remove('face_embedding');
          clean.remove('embedding_path');
          break;
      }
      return clean;
    }).toList();
  }

  // ═══════════════════════════════════════════
  // OFFLINE QUEUE
  // ═══════════════════════════════════════════

  /// Saves a failed sync to local SQLite queue.
  /// FIX: Now returns the inserted row id so callers can confirm it was saved.
  Future<int> _enqueue(String table, Map<String, dynamic> payload) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('sync_queue', {
        'table_name': table,
        'operation': 'upsert',
        'payload': jsonEncode(payload),
      });
      print('📥 Queued offline: $table (queue id=$id)');
      return id;
    } catch (e) {
      // FIX: Surface this error — if sync_queue table doesn't exist,
      // data is silently lost without this log.
      print('❌ CRITICAL: Failed to enqueue $table — data may be lost! Error: $e');
      print('   ↳ Make sure sync_queue table exists in your DatabaseHelper migration.');
      return -1;
    }
  }

  /// Flushes all queued records to Supabase. Called when back online.
  Future<void> flushQueue() async {
    if (!_isOnline) return;
    final db = await DatabaseHelper.instance.database;

    // FIX: Check sync_queue table exists before querying
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_queue'",
    );
    if (tables.isEmpty) {
      print('⚠️ flushQueue: sync_queue table does not exist — skipping.');
      return;
    }

    final queued = await db.query('sync_queue', orderBy: 'id ASC');

    if (queued.isEmpty) {
      print('✅ Offline queue is empty.');
      return;
    }

    print('🔄 Flushing ${queued.length} queued records...');

    for (final item in queued) {
      try {
        final table = item['table_name'] as String;
        final payload =
            Map<String, dynamic>.from(jsonDecode(item['payload'] as String));

        await _client.from(table).upsert(payload);
        await db.delete('sync_queue',
            where: 'id = ?', whereArgs: [item['id']]);
        print('✅ Flushed queued record → $table (queue id=${item['id']})');
      } catch (e) {
        print('❌ Failed to flush queued record (id=${item['id']}): $e');
        // Leave it in the queue to retry next time
      }
    }
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
      print('❌ Upload face embedding error: $e');
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
      final bytes =
          await _client.storage.from('face-embeddings').download(path);
      return utf8.decode(bytes);
    } catch (e) {
      print('❌ Download face embedding error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════
  // PUSH: Local → Supabase (with offline queue)
  // ═══════════════════════════════════════════

  Future<void> pushAttendance(Map<String, dynamic> row) async {
    if (!_isOnline) {
      await _enqueue('attendance', row);
      return;
    }
    try {
      await _client.from('attendance').upsert(row);
    } catch (e) {
      print('❌ Sync attendance error: $e — queuing for retry');
      await _enqueue('attendance', row);
    }
  }

  Future<void> pushStudent(Map<String, dynamic> row) async {
    // FIX: sanitize AFTER confirming we have the full row, before enqueue or upsert
    final sanitized = _sanitize('students', [row]).first;
    if (!_isOnline) {
      await _enqueue('students', sanitized);
      return;
    }
    try {
      await _client.from('students').upsert(sanitized);
    } catch (e) {
      print('❌ Sync student error: $e — queuing for retry');
      await _enqueue('students', sanitized);
    }
  }

  Future<void> pushProfessor(Map<String, dynamic> row) async {
    // FIX: sanitize before enqueue AND before upsert
    final sanitized = _sanitize('professors', [row]).first;
    if (!_isOnline) {
      await _enqueue('professors', sanitized);
      return;
    }
    try {
      await _client.from('professors').upsert(sanitized);
    } catch (e) {
      print('❌ Sync professor error: $e — queuing for retry');
      await _enqueue('professors', sanitized);
    }
  }

  Future<void> pushSubject(Map<String, dynamic> row) async {
    if (!_isOnline) {
      await _enqueue('subjects', row);
      return;
    }
    try {
      await _client.from('subjects').upsert(row);
    } catch (e) {
      print('❌ Sync subject error: $e — queuing for retry');
      await _enqueue('subjects', row);
    }
  }

  Future<void> pushSection(Map<String, dynamic> row) async {
    if (!_isOnline) {
      await _enqueue('sections', row);
      return;
    }
    try {
      await _client.from('sections').upsert(row);
    } catch (e) {
      print('❌ Sync section error: $e — queuing for retry');
      await _enqueue('sections', row);
    }
  }

  Future<void> pushSubjectSection(Map<String, dynamic> row) async {
    if (!_isOnline) {
      await _enqueue('subject_sections', row);
      return;
    }
    try {
      await _client.from('subject_sections').upsert(row);
    } catch (e) {
      print('❌ Sync subject_section error: $e — queuing for retry');
      await _enqueue('subject_sections', row);
    }
  }

  Future<void> pushProfessorSubject(Map<String, dynamic> row) async {
    if (!_isOnline) {
      await _enqueue('professor_subjects', row);
      return;
    }
    try {
      await _client.from('professor_subjects').upsert(row);
    } catch (e) {
      print('❌ Sync professor_subject error: $e — queuing for retry');
      await _enqueue('professor_subjects', row);
    }
  }

  // ═══════════════════════════════════════════
  // REAL-TIME LISTENER (attendance screen specific)
  // ═══════════════════════════════════════════

  /// Listen to live attendance for a specific class session.
  /// Use this in your attendance/scanner screen for filtered updates.
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
  // PULL: Supabase → Local (manual / on-demand)
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
      print('❌ Pull attendance error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullStudents() async {
    try {
      final result = await _client.from('students').select();
      return _sanitize('students', List<Map<String, dynamic>>.from(result));
    } catch (e) {
      print('❌ Pull students error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullProfessors() async {
    try {
      final result = await _client.from('professors').select();
      return _sanitize('professors', List<Map<String, dynamic>>.from(result));
    } catch (e) {
      print('❌ Pull professors error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullSubjects() async {
    try {
      final result = await _client.from('subjects').select();
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Pull subjects error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullSections() async {
    try {
      final result = await _client.from('sections').select();
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Pull sections error: $e');
      return [];
    }
  }

  /// Full pull — seeds local SQLite from Supabase manually.
  /// Prefer letting init() handle this automatically.
  /// Use this only if you need a manual refresh button.
  Future<void> pullAll(
      Function(String table, List<Map<String, dynamic>> rows) onData) async {
    if (!_isOnline) {
      print('pullAll: skipped — device is offline');
      return;
    }

    final session = _client.auth.currentSession;
    print(
        'pullAll: starting — session=${session == null ? 'anon' : 'authenticated'}');

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
        final rows =
            _sanitize(table, List<Map<String, dynamic>>.from(result));
        print('pullAll: $table → ${rows.length} rows fetched');
        onData(table, rows);
      } catch (e) {
        print('pullAll: ERROR on $table → $e');
        // Continue to next table — do NOT rethrow
      }
    }

    print('pullAll: done');
  }
}