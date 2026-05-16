import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'operation_queue.dart';

class OfflineDatabase {
  OfflineDatabase._();

  static final OfflineDatabase instance = OfflineDatabase._();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final path = p.join(await getDatabasesPath(), 'nursery_offline.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache_entries (
            key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE operation_queue (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            method TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            lastError TEXT,
            attemptCount INTEGER NOT NULL DEFAULT 0,
            nextAttemptAt TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX operation_queue_status_idx ON operation_queue(status, nextAttemptAt)',
        );
      },
    );

    _database = db;
    return db;
  }

  Future<void> putCache(String key, Object payload) async {
    final db = await database;
    await db.insert(
      'cache_entries',
      {
        'key': key,
        'payload': jsonEncode(payload),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Object?> getCache(String key) async {
    final db = await database;
    final rows = await db.query(
      'cache_entries',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return jsonDecode(rows.first['payload'] as String);
  }

  Future<void> enqueue(QueuedOperation operation) async {
    final db = await database;
    await db.insert(
      'operation_queue',
      operation.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<QueuedOperation>> listQueuedOperations() async {
    final db = await database;
    final rows = await db.query(
      'operation_queue',
      orderBy: 'createdAt ASC',
    );
    return rows.map(QueuedOperation.fromRow).toList();
  }

  Future<List<QueuedOperation>> listPendingOperations() async {
    final db = await database;
    final rows = await db.query(
      'operation_queue',
      where: 'status = ?',
      whereArgs: [QueuedOperationStatus.pending.name],
      orderBy: 'createdAt ASC',
    );
    return rows.map(QueuedOperation.fromRow).where((op) => op.isReadyForRetry).toList();
  }

  Future<void> updateOperation(QueuedOperation operation) async {
    final db = await database;
    await db.update(
      'operation_queue',
      operation.toRow(),
      where: 'id = ?',
      whereArgs: [operation.id],
    );
  }
}
