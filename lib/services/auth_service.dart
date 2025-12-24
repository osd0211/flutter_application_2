// lib/services/auth_service.dart

import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// Auth servis arayüzü
abstract class IAuthService {
  int? get currentUserId;      // DB'deki users.id
  String? get currentUserRole; // 'admin' / 'user'

  String? get currentUserName;
  String? get currentUserEmail;
  String? get currentUsername;

  int get currentUserLevel; // 👈 YENİ
  int get currentUserXp;    // 👈 YENİ

  Future<void> signIn(String identifier, String password);
  Future<void> signOut();

  Future<void> signUp(
    String email,
    String name,
    String username,
    String password,
  );
}

/// SQLite tabanlı auth servisi
class AuthServiceDb implements IAuthService {
  int? _userId;
  String? _role;
  String? _name;
  String? _email;
  String? _username;

  int _level = 1;
  int _xp = 0;

  @override
  int? get currentUserId => _userId;

  @override
  String? get currentUserRole => _role;

  @override
  String? get currentUserName => _name;

  @override
  String? get currentUserEmail => _email;

  @override
  String? get currentUsername => _username;

  @override
  int get currentUserLevel => _level;

  @override
  int get currentUserXp => _xp;

  @override
  Future<void> signIn(String identifier, String password) async {
    final Database db = await DatabaseService.database;

    final input = identifier.trim();
    final isEmail = input.contains('@');
    final normalized = input.toLowerCase();

    final rows = await db.query(
      'users',
      columns: [
        'id',
        'role',
        'name',
        'email',
        'username',
        'level',
        'xp',
      ],
      where: isEmail
          ? 'LOWER(email) = ? AND password = ?'
          : 'LOWER(username) = ? AND password = ?',
      whereArgs: [normalized, password],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('invalid-credentials');
    }

    final row = rows.first;
    _userId = row['id'] as int;
    _role = row['role'] as String?;
    _name = row['name'] as String?;
    _email = row['email'] as String?;
    _username = row['username'] as String?;
    _level = (row['level'] as int?) ?? 1;
    _xp = (row['xp'] as int?) ?? 0;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _role = null;
    _name = null;
    _email = null;
    _username = null;
    _level = 1;
    _xp = 0;
  }

  @override
  Future<void> signUp(
    String email,
    String name,
    String username,
    String password,
  ) async {
    await DatabaseService.createUser(
      email: email,
      name: name,
      username: username,
      password: password,
    );

    // Kayıttan sonra otomatik giriş
    await signIn(email, password);
  }
}
