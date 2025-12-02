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


    // ---------------------------------------------------------------------------
  // PREDICTIONS helper'ları
  // ---------------------------------------------------------------------------

  /// Kullanıcının bir challenge için tahmini varsa günceller,
  /// yoksa yeni kayıt oluşturur.
  static Future<void> upsertPrediction({
    required int userId,
    required String matchId,
    required String playerId,
    required String challengeId,
    required int predPts,
    required int predAst,
    required int predReb,
  }) async {
    final db = await database;

    // Önce bu kullanıcı + challenge için kayıt var mı bak
    final existing = await db.query(
      'predictions',
      where: 'user_id = ? AND challenge_id = ?',
      whereArgs: [userId, challengeId],
      limit: 1,
    );

    final nowIso = DateTime.now().toIso8601String();

    if (existing.isEmpty) {
      // Yeni tahmin ekle
      await db.insert('predictions', {
        'user_id': userId,
        'match_id': matchId,
        'player_id': playerId,
        'challenge_id': challengeId,
        'pred_pts': predPts,
        'pred_ast': predAst,
        'pred_reb': predReb,
        'points': null,          // henüz puan hesaplanmadı
        'created_at': nowIso,
      });
    } else {
      // Var olan tahmini güncelle (puanı sıfırla, tekrar hesaplanacak)
      final id = existing.first['id'] as int;
      await db.update(
        'predictions',
        {
          'match_id': matchId,
          'player_id': playerId,
          'pred_pts': predPts,
          'pred_ast': predAst,
          'pred_reb': predReb,
          'points': null,
          'created_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Belirli bir kullanıcının tüm tahminlerini döndürür.
  /// (UI tarafında PredictionChallenge'a map'leriz)
  static Future<List<Map<String, Object?>>> loadPredictionsForUser(
      int userId) async {
    final db = await database;
    return db.query(
      'predictions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Belirli bir kullanıcının belirli challenge'ı için puanı kaydeder.
  static Future<void> updatePredictionPoints({
    required int userId,
    required String challengeId,
    required int points,
  }) async {
    final db = await database;
    await db.update(
      'predictions',
      {
        'points': points,
      },
      where: 'user_id = ? AND challenge_id = ?',
      whereArgs: [userId, challengeId],
    );
  }


  /// Seçili maçlar için (o günün maçları) TÜM kullanıcıların tahminlerini,
  /// kullanıcı isim / email bilgileriyle birlikte döndürür.
  static Future<List<Map<String, Object?>>> loadPredictionsWithUsersForMatches(
      List<String> matchIds) async {
    if (matchIds.isEmpty) return [];

    final db = await database;

    // IN (?) kısmı için dinamik placeholder üret
    final placeholders = List.filled(matchIds.length, '?').join(',');

    final sql = '''
      SELECT 
        p.*,
        u.name  AS user_name,
        u.email AS user_email
      FROM predictions p
      JOIN users u ON u.id = p.user_id
      WHERE p.match_id IN ($placeholders)
    ''';

    // matchIds liste olarak whereArgs'e gidiyor
    return db.rawQuery(sql, matchIds);
  }

  // ---------------------------------------------------------------------------
  // USERS helper'ı: yeni kullanıcı oluşturma
  // ---------------------------------------------------------------------------

  static Future<int> createUser({
    required String email,
    required String name,
    required String password,
  }) async {
    final db = await database;

    final normalizedEmail = email.trim().toLowerCase();

    // Check if email already exists
    final existing = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception('email-already-exists');
    }

    final id = await db.insert('users', {
      'email': normalizedEmail,
      'name': name.trim(),
      'password': password, // for demo; production would hash
      'role': 'user',
    });

    return id;
  }




}
