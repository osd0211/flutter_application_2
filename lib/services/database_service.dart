// lib/services/database_service.dart

import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _db;

  /// DB'ye erişmek için tek nokta
  static Future<Database> get database async {
    if (_db != null) return _db!;

    _db = await _initDB();
    return _db!;
  }

  /// Fiziksel .db dosyasını oluşturur / açar
  static Future<Database> _initDB() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final String dbPath = join(docs.path, 'euroscore.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Uygulama ilk kez açıldığında tablolar burada oluşturulur
  static Future<void> _onCreate(Database db, int version) async {
    // USERS tablosu
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      );
    ''');

    // PREDICTIONS tablosu
    await db.execute('''
      CREATE TABLE predictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        match_id TEXT NOT NULL,
        player_id TEXT NOT NULL,
        challenge_id TEXT NOT NULL,
        pred_pts INTEGER NOT NULL,
        pred_ast INTEGER NOT NULL,
        pred_reb INTEGER NOT NULL,
        points INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      );
    ''');

    // SETTINGS tablosu
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Demo kullanıcılar (admin + 2 user)
    await db.insert('users', {
      'email': 'admin@euroscore.app',
      'name': 'Admin',
      'password': '123456',
      'role': 'admin',
    });

    await db.insert('users', {
      'email': 'omer@euroscore.app',
      'name': 'Ömer',
      'password': '123456',
      'role': 'user',
    });

    await db.insert('users', {
      'email': 'ahmet@euroscore.app',
      'name': 'Ahmet',
      'password': '123456',
      'role': 'user',
    });
  }

        // ---------------------------------------------------------------------------
  // SETTINGS helper'ları: current_day_date
  // ---------------------------------------------------------------------------

  static const String _currentDayKey = 'current_day_date';

  /// Tarihi 'YYYY-MM-DD' formatına çeviren yardımcı fonksiyon
  static String _fmtDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Seçili günü DB'ye kaydeder (settings.current_day_date)
  static Future<void> saveCurrentDay(DateTime day) async {
    final db = await database;
    final dateStr = _fmtDate(day);

    await db.insert(
      'settings',
      {
        'key': _currentDayKey,
        'value': dateStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// DB'den seçili günü okur. Yoksa null döner.
  static Future<DateTime?> loadCurrentDay() async {
    final db = await database;

    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_currentDayKey],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final String value = rows.first['value'] as String;

    try {
      // 'YYYY-MM-DD' → DateTime (saat 00:00)
      return DateTime.parse('${value}T00:00:00');
    } catch (_) {
      return null;
    }
  }






}
