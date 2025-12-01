import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class OfflineStorage {
  static Database? _database;
  static const String _dbName = 'driver_app_offline.db';
  static const int _dbVersion = 1;

  // Table names
  static const String _tableLocations = 'locations';
  static const String _tablePendingCalls = 'pending_calls';
  static const String _tableTripCache = 'trip_cache';

  /// Initialize database
  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Locations table
    await db.execute('''
      CREATE TABLE $_tableLocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        speed REAL,
        accuracy REAL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Pending API calls table
    await db.execute('''
      CREATE TABLE $_tablePendingCalls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        body TEXT,
        headers TEXT,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Trip cache table
    await db.execute('''
      CREATE TABLE $_tableTripCache (
        trip_id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_locations_trip ON $_tableLocations(trip_id)');
    await db.execute('CREATE INDEX idx_locations_synced ON $_tableLocations(synced)');
    await db.execute('CREATE INDEX idx_pending_created ON $_tablePendingCalls(created_at)');
  }

  // Location methods
  static Future<int> saveLocation({
    required String? tripId,
    required double lat,
    required double lng,
    required DateTime timestamp,
    double? speed,
    double? accuracy,
  }) async {
    final db = await database;
    return await db.insert(
      _tableLocations,
      {
        'trip_id': tripId,
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'speed': speed,
        'accuracy': accuracy,
        'synced': 0,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedLocations({String? tripId}) async {
    final db = await database;
    if (tripId != null) {
      return await db.query(
        _tableLocations,
        where: 'synced = 0 AND trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'timestamp ASC',
      );
    }
    return await db.query(
      _tableLocations,
      where: 'synced = 0',
      orderBy: 'timestamp ASC',
    );
  }

  static Future<void> markLocationsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE $_tableLocations SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  static Future<void> deleteSyncedLocations({int? olderThanDays}) async {
    final db = await database;
    if (olderThanDays != null) {
      final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
      await db.delete(
        _tableLocations,
        where: 'synced = 1 AND timestamp < ?',
        whereArgs: [cutoff.millisecondsSinceEpoch],
      );
    } else {
      await db.delete(_tableLocations, where: 'synced = 1');
    }
  }

  // Pending API calls methods
  static Future<int> savePendingCall({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final db = await database;
    return await db.insert(
      _tablePendingCalls,
      {
        'endpoint': endpoint,
        'method': method,
        'body': body != null ? jsonEncode(body) : null,
        'headers': headers != null ? jsonEncode(headers) : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getPendingCalls({int limit = 50}) async {
    final db = await database;
    return await db.query(
      _tablePendingCalls,
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  static Future<void> deletePendingCall(int id) async {
    final db = await database;
    await db.delete(_tablePendingCalls, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> incrementRetryCount(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $_tablePendingCalls SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  // Trip cache methods
  static Future<void> cacheTripData(String tripId, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      _tableTripCache,
      {
        'trip_id': tripId,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getCachedTripData(String tripId) async {
    final db = await database;
    final result = await db.query(
      _tableTripCache,
      where: 'trip_id = ?',
      whereArgs: [tripId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return jsonDecode(result.first['data'] as String) as Map<String, dynamic>;
  }

  static Future<void> clearCache() async {
    final db = await database;
    await db.delete(_tableTripCache);
    await db.delete(_tableLocations, where: 'synced = 1');
    await db.delete(_tablePendingCalls);
  }

  // Statistics
  static Future<Map<String, int>> getStorageStats() async {
    final db = await database;
    final locationsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableLocations'),
    ) ?? 0;
    final unsyncedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableLocations WHERE synced = 0'),
    ) ?? 0;
    final pendingCallsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tablePendingCalls'),
    ) ?? 0;

    return {
      'total_locations': locationsCount,
      'unsynced_locations': unsyncedCount,
      'pending_calls': pendingCallsCount,
    };
  }
}

