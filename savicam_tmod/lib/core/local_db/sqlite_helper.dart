import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'entities/app_settings.dart';
import 'entities/local_macro.dart';
import 'entities/offline_queue_item.dart';

class SqliteHelper {
  static final SqliteHelper instance = SqliteHelper._();
  Database? _db;

  SqliteHelper._();

  /// @visibleForTesting — cho phép subclass trong test (FakeSqliteHelper).
  SqliteHelper.internal();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'savicam_tmod.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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

    // v2: lat/lng là float riêng biệt, không phải payload string
    await db.execute('''
      CREATE TABLE local_macros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL UNIQUE,
        actionType TEXT NOT NULL DEFAULT 'navigate',
        lat REAL NOT NULL DEFAULT 0.0,
        lng REAL NOT NULL DEFAULT 0.0
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

  /// Migration v1 → v2: tái tạo local_macros với schema lat/lng float.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS local_macros');
      await db.execute('''
        CREATE TABLE local_macros (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          keyword TEXT NOT NULL UNIQUE,
          actionType TEXT NOT NULL DEFAULT 'navigate',
          lat REAL NOT NULL DEFAULT 0.0,
          lng REAL NOT NULL DEFAULT 0.0
        )
      ''');
    }
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

  /// Tìm macro theo keyword (case-insensitive exact match).
  /// Hiệu quả hơn getMacros() khi chỉ cần 1 kết quả.
  Future<LocalMacro?> getMacroByKeyword(String keyword) async {
    final db = await database;
    final rows = await db.query(
      'local_macros',
      where: 'keyword = ? COLLATE NOCASE',
      whereArgs: [keyword.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalMacro.fromMap(rows.first);
  }

  Future<void> deleteMacro(int id) async {
    final db = await database;
    await db.delete('local_macros', where: 'id = ?', whereArgs: [id]);
  }

  /// Chèn dữ liệu mẫu cho development/testing.
  /// Tọa độ thực tế khu vực Đà Nẵng (khuôn viên ĐH Bách Khoa).
  Future<void> seedSampleMacros() async {
    const samples = [
      LocalMacro(keyword: 'nhà', actionType: 'navigate', lat: 16.0544, lng: 108.2022),
      LocalMacro(keyword: 'trường', actionType: 'navigate', lat: 16.0740, lng: 108.1499),
      LocalMacro(keyword: 'bệnh viện', actionType: 'navigate', lat: 16.0678, lng: 108.2120),
      LocalMacro(keyword: 'chợ', actionType: 'navigate', lat: 16.0680, lng: 108.2240),
      LocalMacro(keyword: 'công viên', actionType: 'navigate', lat: 16.0616, lng: 108.2280),
    ];
    for (final m in samples) {
      await upsertMacro(m);
    }
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
