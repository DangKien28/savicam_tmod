import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'entities/app_settings.dart';
import 'entities/local_macro.dart';
import 'entities/offline_queue_item.dart';

class SqliteHelper {
  static final SqliteHelper instance = SqliteHelper._();
  Database? _db;

  SqliteHelper._();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'savicam_tmod.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY,
        enableTts INTEGER NOT NULL DEFAULT 1,
        enableVibration INTEGER NOT NULL DEFAULT 1,
        voiceSpeed REAL NOT NULL DEFAULT 0.85,
        isHighContrast INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.insert('app_settings', const AppSettings().toMap());

    await db.execute('''
      CREATE TABLE local_macros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL UNIQUE,
        actionType TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // --- Settings ---
  Future<AppSettings> getSettings() async {
    final db = await database;
    final rows = await db.query('app_settings', where: 'id = ?', whereArgs: [1]);
    return rows.isNotEmpty ? AppSettings.fromMap(rows.first) : const AppSettings();
  }

  Future<void> updateSettings(AppSettings s) async {
    final db = await database;
    await db.update('app_settings', s.toMap(), where: 'id = ?', whereArgs: [1]);
  }

  // --- Macros ---
  Future<void> upsertMacro(LocalMacro m) async {
    final db = await database;
    await db.insert('local_macros', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LocalMacro>> getMacros() async {
    final db = await database;
    return (await db.query('local_macros')).map(LocalMacro.fromMap).toList();
  }

  // --- Offline Queue ---
  Future<void> enqueue(OfflineQueueItem item) async {
    final db = await database;
    await db.insert('offline_queue', item.toMap());
  }

  Future<List<OfflineQueueItem>> getQueue() async {
    final db = await database;
    return (await db.query('offline_queue')).map(OfflineQueueItem.fromMap).toList();
  }

  Future<void> dequeue(int id) async {
    final db = await database;
    await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }
}
