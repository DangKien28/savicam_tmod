/// SaViCam T-Mod — SQLite Database Helper
///
/// Manages the local SQLite database lifecycle including schema creation
/// and migrations for the three edge tables:
/// - `offline_queue`: Buffers SOS/telemetry payloads when offline
/// - `local_macros`: Stores keyword→GPS mappings synced from cloud
/// - `app_settings`: Persists local configuration and stub flags
///
/// See ARCH-06: SQLite via sqflite is the sole local storage engine.
library;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton helper for SQLite database operations.
///
/// Usage:
/// ```dart
/// final db = await SqliteHelper.instance.database;
/// await db.insert('offline_queue', data);
/// ```
class SqliteHelper {
  SqliteHelper._internal();

  static final SqliteHelper instance = SqliteHelper._internal();

  static const String _databaseName = 'savicam_tmod.db';
  static const int _databaseVersion = 1;

  Database? _database;

  /// Returns the singleton database instance, creating it if needed.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates all three edge tables on first launch.
  Future<void> _onCreate(Database db, int version) async {
    // ─── Offline Queue ───
    // Buffers SOS events and telemetry when ConnectivityResult.none.
    // Flushed automatically when connectivity is restored.
    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        synced INTEGER NOT NULL DEFAULT 0,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        last_sync_error TEXT
      )
    ''');

    // ─── Local Macros ───
    // Keyword → GPS coordinate mappings synced from guardian's Relap app.
    // Used by NLP Agent to resolve voice-commanded destinations.
    await db.execute('''
      CREATE TABLE local_macros (
        id TEXT PRIMARY KEY,
        keyword TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ─── App Settings ───
    // Local configuration store. Includes stub model flag per ARCH-07.
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Insert default settings
    await db.insert('app_settings', {
      'key': 'use_stub_models',
      'value': 'true',
    });
    await db.insert('app_settings', {
      'key': 'tts_locale',
      'value': 'vi-VN',
    });
    await db.insert('app_settings', {
      'key': 'safety_audio_enabled',
      'value': 'true',
    });
  }

  /// Handles schema migrations for future versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration strategy: numbered migration files per ARCH-06.
    // Example for version 2:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE offline_queue ADD COLUMN priority INTEGER DEFAULT 0');
    // }
  }

  // ─── Offline Queue Operations ───

  /// Enqueues a payload for later sync.
  /// [eventType] is 'sos' or 'telemetry'.
  Future<int> enqueue({
    required String eventType,
    required String payload,
  }) async {
    final db = await database;
    return db.insert('offline_queue', {
      'event_type': eventType,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
      'sync_attempts': 0,
    });
  }

  /// Returns all unsynced items from the queue, oldest first.
  Future<List<Map<String, dynamic>>> getUnsyncedQueue() async {
    final db = await database;
    return db.query(
      'offline_queue',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
  }

  /// Marks a queue item as synced.
  Future<void> markSynced(int id) async {
    final db = await database;
    await db.update(
      'offline_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increments sync attempt count and records error for a queue item.
  Future<void> recordSyncError(int id, String error) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE offline_queue SET sync_attempts = sync_attempts + 1, last_sync_error = ? WHERE id = ?',
      [error, id],
    );
  }

  /// Removes all synced items from the queue to free space.
  Future<int> purgeSyncedItems() async {
    final db = await database;
    return db.delete('offline_queue', where: 'synced = 1');
  }

  // ─── App Settings Operations ───

  /// Gets a setting value by key, or returns [defaultValue] if not found.
  Future<String?> getSetting(String key, {String? defaultValue}) async {
    final db = await database;
    final results = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return defaultValue;
    return results.first['value'] as String?;
  }

  /// Sets a setting value, inserting or replacing as needed.
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Whether stub models should be used instead of real AI models.
  /// See ARCH-07: Stub-First Mandate.
  Future<bool> get useStubModels async {
    final value = await getSetting('use_stub_models', defaultValue: 'true');
    return value == 'true';
  }

  /// Closes the database connection. Call on app dispose.
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
