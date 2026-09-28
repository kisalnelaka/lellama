import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lellama_mobile/data/models/pfz_model.dart';
import 'package:lellama_mobile/data/models/weather_model.dart';
import 'package:lellama_mobile/data/models/alert_model.dart';

/// Embedded SQLite database manager for offline maritime persistence.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lellama_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_pfz (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sst_celsius REAL NOT NULL,
        sst_gradient REAL NOT NULL,
        chlorophyll REAL NOT NULL,
        confidence REAL NOT NULL,
        detection_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_weather (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        location_name TEXT NOT NULL,
        valid_for_time TEXT NOT NULL,
        wave_height REAL NOT NULL,
        wave_direction REAL NOT NULL,
        wind_wave_height REAL NOT NULL,
        swell_wave_height REAL NOT NULL,
        ocean_current_velocity REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_alerts (
        id TEXT PRIMARY KEY,
        alert_level TEXT NOT NULL,
        message_sinhala TEXT NOT NULL,
        message_tamil TEXT NOT NULL,
        message_english TEXT NOT NULL,
        trigger_cause TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // --- PFZ Transactions ---
  Future<void> replacePFZs(List<PFZModel> pfzs) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('offline_pfz');
      for (final pfz in pfzs) {
        await txn.insert('offline_pfz', pfz.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<PFZModel>> getPFZs() async {
    final db = await database;
    final maps = await db.query('offline_pfz', orderBy: 'confidence DESC');
    return maps.map((m) => PFZModel.fromDbMap(m)).toList();
  }

  // --- Weather Transactions ---
  Future<void> replaceWeather(List<WeatherModel> weatherList) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('offline_weather');
      for (final w in weatherList) {
        await txn.insert('offline_weather', w.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<WeatherModel>> getWeatherForecasts() async {
    final db = await database;
    final maps = await db.query('offline_weather', orderBy: 'valid_for_time ASC');
    return maps.map((m) => WeatherModel.fromDbMap(m)).toList();
  }

  // --- Alerts Transactions ---
  Future<void> replaceAlerts(List<AlertModel> alerts) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('offline_alerts');
      for (final a in alerts) {
        await txn.insert('offline_alerts', a.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<AlertModel>> getAlerts() async {
    final db = await database;
    final maps = await db.query('offline_alerts', orderBy: 'created_at DESC');
    return maps.map((m) => AlertModel.fromDbMap(m)).toList();
  }

  // --- Key-Value Settings ---
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }
}
