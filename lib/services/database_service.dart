// lib/services/database_service.dart

import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models.dart';


class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final String dbPath = join(docs.path, 'euroscore.db');

    return openDatabase(
      dbPath,
      version: 8, // ✅ badges + prediction meta
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ------------------------------------------------------------
  // Helpers: column var mı?
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

  // ------------------------------------------------------------
  // Badges: table create + helpers
  // ------------------------------------------------------------

  static Future<void> _ensureBadgesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_badges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        badge_key TEXT NOT NULL,
        earned_at TEXT NOT NULL,
        UNIQUE(user_id, badge_key)
      );
    ''');
  }

  static int xpForBadge(String badgeKey) {
    switch (badgeKey) {
      // favorites
      case 'fav_team_set':
        return 100;
      case 'fav_player_set':
        return 100;

      // prediction activity
      case 'first_prediction':
        return 50;
      case 'day_5_predictions':
        return 100;

      // accuracy (finalize after match)
      case 'exact_1':
        return 50;
      case 'exact_2':
        return 100;
      case 'perfect_3':
        return 250;

      // level milestones
      case 'level_5':
        return 25;
      case 'level_10':
        return 50;
      case 'level_25':
        return 100;
      case 'level_50':
        return 200;
      case 'level_100':
        return 500;

      default:
        return 0;
    }
  }

  static Future<bool> awardBadgeOnce({
    required int userId,
    required String badgeKey,
  }) async {
    final db = await database;
    await _ensureBadgesTable(db);

    final nowIso = DateTime.now().toIso8601String();

    // insert ignore
    final inserted = await db.rawInsert(
      'INSERT OR IGNORE INTO user_badges (user_id, badge_key, earned_at) VALUES (?, ?, ?)',
      [userId, badgeKey, nowIso],
    );

    // SQLite: inserted rowId > 0 => yeni badge
    if (inserted > 0) {
      final xp = xpForBadge(badgeKey);
      if (xp > 0) {
        await addXp(userId: userId, gainedXp: xp);
      }
      return true;
    }
    return false;
  }

  static Future<List<Map<String, Object?>>> loadBadgesForUser(int userId) async {
    final db = await database;
    await _ensureBadgesTable(db);
    return db.query(
      'user_badges',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'earned_at DESC',
    );
  }

  // ------------------------------------------------------------
  // onCreate
  // ------------------------------------------------------------
  static Future<void> _onCreate(Database db, int version) async {
    // USERS
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

    // PREDICTIONS
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

        -- ✅ badge/finalize metadata (opsiyonel)
        exact_count INTEGER,
        badges_awarded INTEGER NOT NULL DEFAULT 0,
        scored_at TEXT,

        FOREIGN KEY (user_id) REFERENCES users(id)
      );
    ''');

    // SETTINGS
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // ✅ Badges
    await _ensureBadgesTable(db);

    // Demo users
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

  // ------------------------------------------------------------
  // onUpgrade
  // ------------------------------------------------------------
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // users columns
    await _addColumnIfMissing(db, 'users', 'username', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'xp', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'level', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(db, 'users', 'favorite_team_code', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'favorite_team_name', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'favorite_player_id', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'favorite_player_name', 'TEXT');

    // predictions meta columns
    await _addColumnIfMissing(db, 'predictions', 'exact_count', 'INTEGER');
    await _addColumnIfMissing(db, 'predictions', 'badges_awarded', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'predictions', 'scored_at', 'TEXT');

    // badges table
    await _ensureBadgesTable(db);
    // ✅ v8 fix: some devices have exact_count as NOT NULL, so never leave it null
    if (oldVersion < 8) {
  await db.execute('UPDATE predictions SET exact_count = 0 WHERE exact_count IS NULL');
}

  }

  // ------------------------------------------------------------
  // XP + LEVEL helpers
  // ------------------------------------------------------------

  /// Level 1->2: 100, sonra +25
  static int _requiredXpForLevel(int level) {
    return 100 + (level - 1) * 25;
  }

  static int _computeLevelFromTotalXp(int totalXp) {
    int level = 1;
    int remaining = totalXp;

    while (remaining >= _requiredXpForLevel(level)) {
      remaining -= _requiredXpForLevel(level);
      level += 1;
    }
    return level;
  }

  /// ✅ Belirli bir level'a ulaşmak için gereken MIN total XP
/// level=1 => 0
/// level=2 => req(1)
/// level=5 => req(1)+req(2)+req(3)+req(4)
static int _minTotalXpForLevel(int level) {
  final safeLevel = level < 1 ? 1 : level;
  int total = 0;
  for (int l = 1; l < safeLevel; l++) {
    total += _requiredXpForLevel(l);
  }
  return total;
}


  static Future<void> _awardLevelMilestonesIfNeeded({
    required int userId,
    required int oldLevel,
    required int newLevel,
  }) async {
    const thresholds = [5, 10, 25, 50, 100];
    for (final t in thresholds) {
      if (oldLevel < t && newLevel >= t) {
        await awardBadgeOnce(userId: userId, badgeKey: 'level_$t');
      }
    }
  }

  static Future<void> addXp({
    required int userId,
    required int gainedXp,
  }) async {
    if (gainedXp <= 0) return;

    final db = await database;

    final rows = await db.query(
      'users',
      columns: ['xp', 'level'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final int oldXp = (rows.first['xp'] as int?) ?? 0;
    final int oldLevel = (rows.first['level'] as int?) ?? 1;

    final int newXp = oldXp + gainedXp;
    final int newLevel = _computeLevelFromTotalXp(newXp);

    await db.update(
      'users',
      {'xp': newXp, 'level': newLevel},
      where: 'id = ?',
      whereArgs: [userId],
    );

    // ✅ level milestone badges
    if (newLevel > oldLevel) {
      await _awardLevelMilestonesIfNeeded(
        userId: userId,
        oldLevel: oldLevel,
        newLevel: newLevel,
      );
    }
  }

  static bool canChangeUsername(int level) => level >= 5;
  static int totalPredictionLimit(int level) => 5 + (level ~/ 5);

  // ------------------------------------------------------------
  // Prediction activity badges (first + day 5)
  // ------------------------------------------------------------
  static String _todayPrefix() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d'; // ISO prefix
  }

  static Future<void> onNewPredictionCreated(int userId) async {
    final db = await database;

    // total count
    final totalRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM predictions WHERE user_id = ?',
      [userId],
    );
    final int totalCount = (totalRows.first['c'] as int?) ?? 0;

    if (totalCount == 1) {
      await awardBadgeOnce(userId: userId, badgeKey: 'first_prediction');
    }

    // today count
    final prefix = _todayPrefix();
    final todayRows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM predictions WHERE user_id = ? AND created_at LIKE ?",
      [userId, '$prefix%'],
    );
    final int todayCount = (todayRows.first['c'] as int?) ?? 0;

    if (todayCount >= 5) {
      await awardBadgeOnce(userId: userId, badgeKey: 'day_5_predictions');
    }
  }

  // ------------------------------------------------------------
  // Username NULL => generate
  // ------------------------------------------------------------
  static Future<void> generateUsernamesIfMissing() async {
    final db = await database;

    final users = await db.query('users', where: 'username IS NULL');

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

      final int random = (1000 + (id * 37) % 9000);
      final String username = '${safeName}_$random';

      await db.update(
        'users',
        {'username': username},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

   // ------------------------------------------------------------
  // SETTINGS: current_day_date
  // ------------------------------------------------------------
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
    whereArgs: [_currentDayKey], // ✅ BURASI whereArgs
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


  // ------------------------------------------------------------
  // SETTINGS: simulation_phase (restart bug fix)
  // ------------------------------------------------------------
  static const String _simulationPhaseKey = 'simulation_phase';

  static Future<void> saveSimulationPhase(SimulationPhase phase) async {
    final db = await database;

    final value =
        (phase == SimulationPhase.finished) ? 'finished' : 'notStarted';

    await db.insert(
      'settings',
      {'key': _simulationPhaseKey, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<SimulationPhase?> loadSimulationPhase() async {
    final db = await database;

    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_simulationPhaseKey],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final String value = rows.first['value'] as String;
    if (value == 'finished') return SimulationPhase.finished;
    return SimulationPhase.notStarted;
  }




  // ------------------------------------------------------------
  // PREDICTIONS
  // ------------------------------------------------------------
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
        'exact_count': 0,
        'badges_awarded': 0,
        'scored_at': null,
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
          // update olunca outcome meta reset:
          'exact_count': 0,
          'badges_awarded': 0,
          'scored_at': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<List<Map<String, Object?>>> loadPredictionsForUser(int userId) async {
    final db = await database;
    return db.query('predictions', where: 'user_id = ?', whereArgs: [userId]);
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

  // ------------------------------------------------------------
  // USERS: create / admin helpers / getUser
  // ------------------------------------------------------------
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

  // ✅ old xp + old level oku (milestone için oldLevel lazım)
  final rows = await db.query(
    'users',
    columns: ['xp', 'level'],
    where: 'id = ?',
    whereArgs: [userId],
    limit: 1,
  );
  if (rows.isEmpty) {
    throw Exception('user-not-found');
  }

  final currentXp = (rows.first['xp'] as int?) ?? 0;
  final oldLevel = (rows.first['level'] as int?) ?? 1;

  // ✅ bu level için minimum total xp
  final minXp = _minTotalXpForLevel(safeLevel);

  // sadece yukarı çek (xp düşürmez)
  final newXp = currentXp < minXp ? minXp : currentXp;

  await db.update(
    'users',
    {
      'level': safeLevel,
      'xp': newXp,
    },
    where: 'id = ?',
    whereArgs: [userId],
  );

  // ✅ level milestone rozetleri
  if (safeLevel > oldLevel) {
    await _awardLevelMilestonesIfNeeded(
      userId: userId,
      oldLevel: oldLevel,
      newLevel: safeLevel,
    );
  }
}

static Future<void> adminSetXp({
  required int userId,
  required int xp,
}) async {
  final db = await database;
  final safeXp = xp < 0 ? 0 : xp;

  // ✅ old level oku (milestone için)
  final rows = await db.query(
    'users',
    columns: ['level'],
    where: 'id = ?',
    whereArgs: [userId],
    limit: 1,
  );
  if (rows.isEmpty) {
    throw Exception('user-not-found');
  }

  final oldLevel = (rows.first['level'] as int?) ?? 1;

  final newLevel = _computeLevelFromTotalXp(safeXp);

  await db.update(
    'users',
    {'xp': safeXp, 'level': newLevel},
    where: 'id = ?',
    whereArgs: [userId],
  );

  // ✅ level milestone rozetleri
  if (newLevel > oldLevel) {
    await _awardLevelMilestonesIfNeeded(
      userId: userId,
      oldLevel: oldLevel,
      newLevel: newLevel,
    );
  }
}

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


  // ------------------------------------------------------------
// ADMIN: Badge reset (test için)
// ------------------------------------------------------------
static Future<void> adminResetBadgesAndXp({
  required int userId,
}) async {
  final db = await database;

  // 1) Kullanıcının mevcut XP + level’ını sıfırla
  await db.update(
  'users',
  {
    'xp': 0,
    'level': 1,
    'favorite_team_code': null,
    'favorite_team_name': null,
    'favorite_player_id': null,
    'favorite_player_name': null,
  },
  where: 'id = ?',
  whereArgs: [userId],
);


  // 2) Kullanıcının aldığı tüm badge’leri sil
  await db.delete(
    'user_badges',
    where: 'user_id = ?',
    whereArgs: [userId],
  );

  // 2.5) ✅ user's predictions delete (so first_prediction can be re-earned in tests)
await db.delete(
  'predictions',
  where: 'user_id = ?',
  whereArgs: [userId],
);


  // 3) Prediction meta reset (accuracy badge’ler tekrar verilebilsin)
  await db.update(
    'predictions',
    {
      'exact_count': 0,
      'badges_awarded': 0,
      'scored_at': null,
      'points': null,
    },
    where: 'user_id = ?',
    whereArgs: [userId],
  );
}


  // ------------------------------------------------------------
  // Favorites => badge (XP badge’den geliyor)
  // ------------------------------------------------------------
  static Future<void> updateFavoriteTeam({
    required int userId,
    required String? teamCode,
    required String? teamName,
  }) async {
    final db = await database;

    await db.update(
      'users',
      {'favorite_team_code': teamCode, 'favorite_team_name': teamName},
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (teamCode == null || teamCode.trim().isEmpty) return;

    // ✅ badge -> XP
    await awardBadgeOnce(userId: userId, badgeKey: 'fav_team_set');
  }

  static Future<void> updateFavoritePlayer({
    required int userId,
    required String? playerId,
    required String? playerName,
  }) async {
    final db = await database;

    await db.update(
      'users',
      {'favorite_player_id': playerId, 'favorite_player_name': playerName},
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (playerId == null || playerId.trim().isEmpty) return;

    // ✅ badge -> XP
    await awardBadgeOnce(userId: userId, badgeKey: 'fav_player_set');
  }

  static Future<void> finalizeScoresForMatches({
  required List<String> matchIds,
  required Map<String, PlayerStat> boxscoreByPlayerId, // ✅ {playerId -> PlayerStat}
}) async {
  if (matchIds.isEmpty) return;

  final db = await database;

  final placeholders = List.filled(matchIds.length, '?').join(',');

  // ✅ Only predictions not finalized yet
  final preds = await db.rawQuery('''
    SELECT *
    FROM predictions
    WHERE match_id IN ($placeholders)
      AND (scored_at IS NULL OR badges_awarded = 0)
  ''', matchIds);

  if (preds.isEmpty) return;

  final nowIso = DateTime.now().toIso8601String();

  for (final p in preds) {
    final int predId = (p['id'] as int);
    final int userId = (p['user_id'] as int);
    final String playerId = (p['player_id'] as String);

    final stat = boxscoreByPlayerId[playerId];
    if (stat == null) {
      // boxscore yoksa finalize etme
      continue;
    }

    final int predPts = ((p['pred_pts'] as num?) ?? 0).toInt();
    final int predAst = ((p['pred_ast'] as num?) ?? 0).toInt();
    final int predReb = ((p['pred_reb'] as num?) ?? 0).toInt();

    int exact = 0;
    if (predPts == stat.pts) exact++;
    if (predAst == stat.ast) exact++;
    if (predReb == stat.reb) exact++;

    // ✅ write meta so we don't re-award
    await db.update(
      'predictions',
      {
        'exact_count': exact,  // 0..3
        'badges_awarded': 1,   // finalized
        'scored_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [predId],
    );

    // ✅ award accuracy badges (once)
    if (exact == 1) {
      await awardBadgeOnce(userId: userId, badgeKey: 'exact_1');
    }
    if (exact == 2) {
      await awardBadgeOnce(userId: userId, badgeKey: 'exact_2');
    }
    if (exact == 3) {
      await awardBadgeOnce(userId: userId, badgeKey: 'perfect_3');
    }
  }
}

  // ------------------------------------------------------------
  // ✅ Change Password
  // ------------------------------------------------------------
  static Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await database;

    final rows = await db.query(
      'users',
      columns: ['password'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('user-not-found');
    }

    final dbPass = (rows.first['password'] as String?) ?? '';
    if (dbPass != currentPassword) {
      throw Exception('wrong-password');
    }

    if (newPassword.trim().length < 6) {
      throw Exception('weak-password');
    }

    await db.update(
      'users',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }


}
