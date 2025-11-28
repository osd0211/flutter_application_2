// lib/services/auth_service.dart

import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

/// Auth servis arayüzü
abstract class IAuthService {
  int? get currentUserId;   // DB'deki users.id
  String? get currentUserRole; // 'admin' / 'user'

  String? get currentUserName;   // eklendi
  String? get currentUserEmail;  // eklendi

  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

/// SQLite tabanlı auth servisi
class AuthServiceDb implements IAuthService {
  int? _userId;
  String? _role;
  String? _name;
  String? _email;


  @override
  int? get currentUserId => _userId;

  @override
  String? get currentUserRole => _role;

  @override
  String? get currentUserName => _name;

  @override
  String? get currentUserEmail => _email;

  @override
  Future<void> signIn(String email, String password) async {
    final Database db = await DatabaseService.database;

    final normalizedEmail = email.trim().toLowerCase();

    final rows = await db.query(
      'users',
      columns: ['id', 'role', 'name', 'email'],
      where: 'LOWER(email) = ? AND password = ?',
      whereArgs: [normalizedEmail, password],
      limit: 1,
    );

    if (rows.isEmpty) {
      // Login başarısız → hata fırlat
      throw Exception('invalid-credentials');
    }

    final row = rows.first;
    _userId = row['id'] as int;
    _role = row['role'] as String?;
    _name = row['name'] as String?;
    _email = row['email'] as String?;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _role = null;
  }




  
}
