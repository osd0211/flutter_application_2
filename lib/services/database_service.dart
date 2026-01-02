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
      version: 5, // ✅ artırdık (migration fix)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ------------------------------------------------------------
  // ✅ Helpers: column var mı?
  // ------------------------------------------------------------
  static Future<bool> _hasColumn(Database db, String table, String column) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    for (final r in rows) {
      if ((r['name'] as String).toLowerCase() == column.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String typeSql,
  ) async {
    final exists = await _hasColumn(db, table, column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $typeSql;');
    }
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
        role TEXT NOT NULL,
        username TEXT,
        favorite_team_code TEXT,
        favorite_team_name TEXT,
        favorite_player_id TEXT,
        favorite_player_name TEXT,
        xp INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1
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
      'username': 'admin',
      'xp': 0,
      'level': 99,
    });

    await db.insert('users', {
      'email': 'omer@euroscore.app',
      'name': 'Ömer',
      'password': '123456',
      'role': 'user',
      'username': null,
      'xp': 0,
      'level': 1,
    });

    await db.insert('users', {
      'email': 'ahmet@euroscore.app',
      'name': 'Ahmet',
      'password': '123456',
      'role': 'user',
      'username': null,
      'xp': 0,
      'level': 1,
    });
  }

  /// ✅ Migration: eski db'lerde kolonları güvenli ekle
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // En güvenlisi: version’a bakmadan kolonları "varsa geç" mantığıyla eklemek
    await _addColumnIfMissing(db, 'users', 'username', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'xp', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'level', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(db, 'users', 'favorite_team_code', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'favorite_team_name', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'favorite_player_id', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'favorite_player_name', 'TEXT');
  }

  /// ✅ Username NULL olanlara otomatik üret (1 kere çağırman yeter)
  static Future<void> generateUsernamesIfMissing() async {
    final db = await database;

    final users = await db.query(
      'users',
      where: 'username IS NULL',
    );

    for (final user in users) {
      final int id = user['id'] as int;

      final String rawName = (user['name'] as String).trim();
      final String safeName = rawName
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('ö', 'o')
          .replaceAll('ü', 'u')
          .replaceAll('ç', 'c')
          .replaceAll('ş', 's')
          .replaceAll('ğ', 'g')
          .replaceAll('ı', 'i');

      final int random = (1000 + (id * 37) % 9000); // deterministic
      final String username = '${safeName}_$random';

      await db.update(
        'users',
        {'username': username},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// 🔍 SADECE TEST İÇİN: users tablosunu yazdırır
  static Future<void> debugPrintUsers() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT id, name, username, email, role, level, xp, favorite_team_code, favorite_team_name, favorite_player_id, favorite_player_name FROM users',
    );
    for (final r in rows) {
      // ignore: avoid_print
      print(r);
    }
  }

  // ---------------------------------------------------------------------------
  // SETTINGS helper'ları: current_day_date
  // ---------------------------------------------------------------------------

  static const String _currentDayKey = 'current_day_date';

  static String _fmtDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static Future<void> saveCurrentDay(DateTime day) async {
    final db = await database;
    final dateStr = _fmtDate(day);

    await db.insert(
      'settings',
      {'key': _currentDayKey, 'value': dateStr},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
      return DateTime.parse('${value}T00:00:00');
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PREDICTIONS helper'ları
  // ---------------------------------------------------------------------------

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

    final existing = await db.query(
      'predictions',
      where: 'user_id = ? AND challenge_id = ?',
      whereArgs: [userId, challengeId],
      limit: 1,
    );

    final nowIso = DateTime.now().toIso8601String();

    if (existing.isEmpty) {
      await db.insert('predictions', {
        'user_id': userId,
        'match_id': matchId,
        'player_id': playerId,
        'challenge_id': challengeId,
        'pred_pts': predPts,
        'pred_ast': predAst,
        'pred_reb': predReb,
        'points': null,
        'created_at': nowIso,
      });
    } else {
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

  static Future<List<Map<String, Object?>>> loadPredictionsForUser(int userId) async {
    final db = await database;
    return db.query(
      'predictions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  static Future<void> updatePredictionPoints({
    required int userId,
    required String challengeId,
    required int points,
  }) async {
    final db = await database;
    await db.update(
      'predictions',
      {'points': points},
      where: 'user_id = ? AND challenge_id = ?',
      whereArgs: [userId, challengeId],
    );
  }

  static Future<List<Map<String, Object?>>> loadPredictionsWithUsersForMatches(
    List<String> matchIds,
  ) async {
    if (matchIds.isEmpty) return [];

    final db = await database;
    final placeholders = List.filled(matchIds.length, '?').join(',');

    final sql = '''
      SELECT 
        p.*,
        u.name  AS user_name,
        u.email AS user_email,
        u.username AS user_username
      FROM predictions p
      JOIN users u ON u.id = p.user_id
      WHERE p.match_id IN ($placeholders)
    ''';

    return db.rawQuery(sql, matchIds);
  }

  // ---------------------------------------------------------------------------
  // USERS helper'ı: yeni kullanıcı oluşturma
  // ---------------------------------------------------------------------------

  static Future<int> createUser({
    required String email,
    required String name,
    required String username,
    required String password,
  }) async {
    final db = await database;

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = username.trim().toLowerCase();

    final existingEmail = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (existingEmail.isNotEmpty) {
      throw Exception('email-already-exists');
    }

    final existingUsername = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [normalizedUsername],
      limit: 1,
    );
    if (existingUsername.isNotEmpty) {
      throw Exception('username-already-exists');
    }

    final id = await db.insert('users', {
      'email': normalizedEmail,
      'name': name.trim(),
      'username': normalizedUsername,
      'password': password,
      'role': 'user',
      'xp': 0,
      'level': 1,
    });

    return id;
  }

  // ---------------------------------------------------------------------------
  // ADMIN HELPERS (test için)
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, Object?>>> adminLoadAllUsers() async {
    final db = await database;
    return db.query(
      'users',
      columns: [
        'id',
        'name',
        'email',
        'role',
        'username',
        'level',
        'xp',
        'favorite_team_code',
        'favorite_team_name',
        'favorite_player_id',
        'favorite_player_name',
      ],
      orderBy: 'id ASC',
    );
  }

  static Future<void> adminUpdateUsername({
    required int userId,
    required String newUsername,
  }) async {
    final db = await database;

    final normalized = newUsername.trim().toLowerCase();
    if (normalized.isEmpty) throw Exception('username-empty');

    final existing = await db.query(
      'users',
      columns: ['id'],
      where: 'LOWER(username) = ? AND id != ?',
      whereArgs: [normalized, userId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception('username-already-exists');
    }

    await db.update(
      'users',
      {'username': normalized},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  static Future<void> adminSetLevel({
    required int userId,
    required int level,
  }) async {
    final db = await database;
    final safeLevel = level < 1 ? 1 : level;

    await db.update(
      'users',
      {'level': safeLevel},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  static Future<void> adminSetXp({
    required int userId,
    required int xp,
  }) async {
    final db = await database;
    final safeXp = xp < 0 ? 0 : xp;

    await db.update(
      'users',
      {'xp': safeXp},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ Profil için user çek
  // ---------------------------------------------------------------------------
  static Future<Map<String, Object?>?> getUserById(int userId) async {
    final db = await database;

    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ---------------------------------------------------------------------------
  // ✅ Favori takım kaydet
  // ---------------------------------------------------------------------------
  static Future<void> updateFavoriteTeam({
    required int userId,
    required String? teamCode,
    required String? teamName,
  }) async {
    final db = await database;

    await db.update(
      'users',
      {
        'favorite_team_code': teamCode,
        'favorite_team_name': teamName,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ Favori oyuncu kaydet
  // ---------------------------------------------------------------------------
  static Future<void> updateFavoritePlayer({
    required int userId,
    required String? playerId,
    required String? playerName,
  }) async {
    final db = await database;

    await db.update(
      'users',
      {
        'favorite_player_id': playerId,
        'favorite_player_name': playerName,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
