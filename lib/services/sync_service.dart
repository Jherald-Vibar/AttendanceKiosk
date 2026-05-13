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
    final results = await Connectivity().checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);

    Connectivity().onConnectivityChanged.listen((results) async {
      final wasOffline = !_isOnline;
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

  /// Call from WidgetsBindingObserver.didChangeAppLifecycleState on resumed.
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
  // SEED: Supabase → Local SQLite
  // ═══════════════════════════════════════════

  Future<void> _seedAll() async {
    if (!_isOnline) return;

    final db = await DatabaseHelper.instance.database;

    // Parent tables before child tables (FK order)
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

        rows = _sanitizeForSeed(table, rows);

        print('🌱 Seeding $table → ${rows.length} rows');

        final batch = db.batch();
        for (final row in rows) {
          batch.insert(table, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      } catch (e) {
        print('❌ Seed error on $table: $e');
      }
    }

    print('✅ Seed complete');
  }

  // ═══════════════════════════════════════════
  // REALTIME: Live listeners for all tables
  // ═══════════════════════════════════════════

  void _startRealtimeListeners() {
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
            callback: (payload) =>
                _handleLiveRow(table, payload.newRecord, forSeed: true),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            callback: (payload) =>
                _handleLiveRow(table, payload.newRecord, forSeed: true),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: table,
            callback: (payload) =>
                _handleLiveDelete(table, payload.oldRecord),
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
    String table,
    Map<String, dynamic> row, {
    bool forSeed = false,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final sanitized = forSeed
          ? _sanitizeForSeed(table, [row]).first
          : _sanitize(table, [row]).first;
      await db.insert(table, sanitized,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('⚡ Live upsert → $table');
    } catch (e) {
      print('❌ Live upsert error on $table: $e');
    }
  }

  Future<void> _handleLiveDelete(
      String table, Map<String, dynamic> row) async {
    print('📡 _handleLiveDelete called → $table | oldRecord: $row');

    // Requires REPLICA IDENTITY FULL on every table.
    // Run in Supabase SQL Editor:
    //   ALTER TABLE professors         REPLICA IDENTITY FULL;
    //   ALTER TABLE subjects           REPLICA IDENTITY FULL;
    //   ALTER TABLE sections           REPLICA IDENTITY FULL;
    //   ALTER TABLE professor_subjects REPLICA IDENTITY FULL;
    //   ALTER TABLE subject_sections   REPLICA IDENTITY FULL;
    //   ALTER TABLE students           REPLICA IDENTITY FULL;
    //   ALTER TABLE attendance         REPLICA IDENTITY FULL;
    if (row.isEmpty) {
      print('⚠️ Live delete on $table — oldRecord is EMPTY. '
          'Run: ALTER TABLE $table REPLICA IDENTITY FULL;');
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final id = row['id'];
      if (id != null) {
        final affected =
            await db.delete(table, where: 'id = ?', whereArgs: [id]);
        print('🗑️ Live delete → $table #$id (rows affected: $affected)');
      } else {
        print(
            '⚠️ Live delete on $table — oldRecord has no id field: $row');
      }
    } catch (e) {
      print('❌ Live delete error on $table: $e');
    }
  }

  // ═══════════════════════════════════════════
  // SANITIZE HELPERS
  // ═══════════════════════════════════════════

  /// Used for PUSH operations (local → Supabase).
  /// Strips face_embedding (sent separately via pushFaceEmbedding) and
  /// ensures passwords are never accidentally overwritten with plain text.
  List<Map<String, dynamic>> _sanitize(
      String table, List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final clean = Map<String, dynamic>.from(row);
      switch (table) {
        case 'professors':
          clean.remove('face_embedding'); // synced separately
          clean['password'] ??= '';
          break;
        case 'students':
          clean.remove('face_embedding'); // synced separately
          clean.remove('embedding_path');
          break;
      }
      return clean;
    }).toList();
  }

  /// Used for SEED / PULL operations (Supabase → local SQLite).
  /// Keeps face_embedding so a freshly installed device gets all
  /// registered embeddings without needing a separate download step.
  List<Map<String, dynamic>> _sanitizeForSeed(
      String table, List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final clean = Map<String, dynamic>.from(row);
      switch (table) {
        case 'professors':
          // Keep face_embedding; ensure password default exists.
          clean['password'] ??= '';
          break;
        case 'students':
          // Keep face_embedding; remove storage-path field not in local schema.
          clean.remove('embedding_path');
          break;
      }
      return clean;
    }).toList();
  }

  // ═══════════════════════════════════════════
  // OFFLINE QUEUE
  // ═══════════════════════════════════════════

  Future<int> _enqueue(String table, Map<String, dynamic> payload,
      {String operation = 'upsert'}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('sync_queue', {
        'table_name': table,
        'operation': operation,
        'payload': jsonEncode(payload),
      });
      print('📥 Queued offline $operation: $table (queue id=$id)');
      return id;
    } catch (e) {
      print('❌ CRITICAL: Failed to enqueue $operation for $table: $e');
      print(
          '   ↳ Make sure sync_queue table exists in your DatabaseHelper migration.');
      return -1;
    }
  }

  Future<int> _enqueueDelete(String table, int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final queueId = await db.insert('sync_queue', {
        'table_name': table,
        'operation': 'delete',
        'payload': jsonEncode({'id': id}),
      });
      print('📥 Queued offline delete: $table #$id (queue id=$queueId)');
      return queueId;
    } catch (e) {
      print('❌ CRITICAL: Failed to enqueue delete for $table #$id: $e');
      print(
          '   ↳ Make sure sync_queue table exists in your DatabaseHelper migration.');
      return -1;
    }
  }

  /// Flushes all queued operations to Supabase. Called when back online.
  Future<void> flushQueue() async {
    if (!_isOnline) return;
    final db = await DatabaseHelper.instance.database;

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
        final operation = item['operation'] as String;
        final payload = Map<String, dynamic>.from(
            jsonDecode(item['payload'] as String));

        if (operation == 'delete') {
          final id = payload['id'];
          if (id != null) {
            final response = await _client
                .from(table)
                .delete()
                .eq('id', id)
                .select();
            print('✅ Flushed queued DELETE → $table #$id '
                '(affected: ${response.length}, queue id=${item['id']})');
            if (response.isEmpty) {
              print('⚠️ WARNING: Supabase deleted 0 rows for $table #$id '
                  '— row may already be gone or RLS is blocking.');
            }
          }
        } else if (operation == 'face_update') {
          // FIX: face embeddings must use UPDATE, not upsert, to avoid
          // triggering an INSERT that violates NOT NULL constraints on
          // other required columns (e.g. employee_id).
          final id = payload['id'];
          final embedding = payload['face_embedding'];
          final updatedAt = payload['updated_at'];
          if (id != null && embedding != null) {
            await _client.from(table).update({
              'face_embedding': embedding,
              'updated_at': updatedAt,
            }).eq('id', id);
            print(
                '✅ Flushed queued face_update → $table #$id (queue id=${item['id']})');
          }
        } else {
          // Generic upsert for all other operations.
          await _client.from(table).upsert(payload);
          print(
              '✅ Flushed queued UPSERT → $table (queue id=${item['id']})');
        }

        await db.delete('sync_queue',
            where: 'id = ?', whereArgs: [item['id']]);
      } catch (e) {
        print('❌ Failed to flush queued record (id=${item['id']}): $e');
        // Leave it in the queue to retry next time.
      }
    }

    print('✅ Queue flush complete.');
  }

  // ═══════════════════════════════════════════
  // FACE EMBEDDINGS → Supabase (column on user row)
  // ═══════════════════════════════════════════

  /// Pushes the face_embedding column update for a professor or student
  /// directly to the matching Supabase row.
  ///
  /// [table]     — 'professors' or 'students'
  /// [id]        — the row's primary key
  /// [embedding] — the encoded embedding string
  ///
  /// Offline-safe: enqueues the update when the device has no connection
  /// and flushes it automatically on the next online reconnect.
  ///
  /// Uses UPDATE (not upsert) to avoid triggering an INSERT that would
  /// violate NOT NULL constraints on columns like employee_id.
  Future<void> pushFaceEmbedding({
    required String table,
    required int id,
    required String embedding,
  }) async {
    assert(
      table == 'professors' || table == 'students',
      'pushFaceEmbedding only supports professors and students tables. '
      'Admin embeddings are device-local.',
    );

    final updatedAt = DateTime.now().toUtc().toIso8601String();

    // FIX: queue as 'face_update' so flushQueue routes it to .update(),
    // not .upsert(), which would attempt an INSERT and fail on NOT NULL cols.
    if (!_isOnline) {
      print('📥 Offline — queuing face_embedding update for $table #$id');
      await _enqueue(
        table,
        {'id': id, 'face_embedding': embedding, 'updated_at': updatedAt},
        operation: 'face_update',
      );
      return;
    }

    try {
      // FIX: use .update().eq() instead of .upsert() to prevent Supabase
      // from attempting an INSERT when the conflict resolution falls through.
      await _client
          .from(table)
          .update({
            'face_embedding': embedding,
            'updated_at': updatedAt,
          })
          .eq('id', id);
      print('✅ Face embedding synced → $table #$id');
    } catch (e) {
      print(
          '❌ Face embedding sync error for $table #$id: $e — queuing for retry');
      await _enqueue(
        table,
        {'id': id, 'face_embedding': embedding, 'updated_at': updatedAt},
        operation: 'face_update',
      );
    }
  }

  // ═══════════════════════════════════════════
  // FACE EMBEDDINGS → Supabase Storage (optional / legacy)
  // ═══════════════════════════════════════════

  Future<String?> uploadFaceEmbedding({
    required String type,
    required int id,
    required String embeddingJson,
  }) async {
    if (!_isOnline) return null;
    try {
      final path = 'embeddings/$type/$id.json';
      final bytes = utf8.encode(embeddingJson);
      await _client.storage.from('face-embeddings').uploadBinary(
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
  // PUSH: Local → Supabase (upserts with offline queue)
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
  // DELETE: Supabase hard delete (with offline queue)
  // ═══════════════════════════════════════════

  Future<void> _pushDelete(String table, int id) async {
    if (!_isOnline) {
      print('📥 Offline — queuing delete for $table #$id');
      await _enqueueDelete(table, id);
      return;
    }
    try {
      print('🌐 Attempting remote delete → $table #$id');
      final response = await _client
          .from(table)
          .delete()
          .eq('id', id)
          .select();

      if (response.isEmpty) {
        print('⚠️ WARNING: Supabase deleted 0 rows for $table #$id '
            '— check RLS policies or if row exists.');
      } else {
        print('✅ Remote delete confirmed → $table #$id '
            '(deleted ${response.length} row(s))');
      }
    } catch (e) {
      print(
          '❌ Remote delete error on $table #$id: $e — queuing for retry');
      await _enqueueDelete(table, id);
    }
  }

  Future<void> deleteAttendance(int id) => _pushDelete('attendance', id);
  Future<void> deleteStudent(int id) => _pushDelete('students', id);
  Future<void> deleteProfessor(int id) => _pushDelete('professors', id);
  Future<void> deleteSubject(int id) => _pushDelete('subjects', id);
  Future<void> deleteSection(int id) => _pushDelete('sections', id);
  Future<void> deleteSubjectSection(int id) =>
      _pushDelete('subject_sections', id);
  Future<void> deleteProfessorSubject(int id) =>
      _pushDelete('professor_subjects', id);

  // ═══════════════════════════════════════════
  // REAL-TIME LISTENER (attendance screen specific)
  // ═══════════════════════════════════════════

  RealtimeChannel listenToAttendance({
    required int subjectSectionId,
    required String date,
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function(Map<String, dynamic> row) onUpdate,
    void Function(int id)? onDelete,
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
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'attendance',
          callback: (payload) {
            final old = payload.oldRecord;
            if (old.isEmpty) return;
            if (old['subject_section_id'] == subjectSectionId &&
                old['date'] == date) {
              onDelete?.call(old['id'] as int);
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
      return _sanitizeForSeed(
          'students', List<Map<String, dynamic>>.from(result));
    } catch (e) {
      print('❌ Pull students error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullProfessors() async {
    try {
      final result = await _client.from('professors').select();
      return _sanitizeForSeed(
          'professors', List<Map<String, dynamic>>.from(result));
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
  Future<void> pullAll(
      Function(String table, List<Map<String, dynamic>> rows)
          onData) async {
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
        final rows = _sanitizeForSeed(
            table, List<Map<String, dynamic>>.from(result));
        print('pullAll: $table → ${rows.length} rows fetched');
        onData(table, rows);
      } catch (e) {
        print('pullAll: ERROR on $table → $e');
      }
    }

    print('pullAll: done');
  }
}