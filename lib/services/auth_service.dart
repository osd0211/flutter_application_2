import 'package:supabase_flutter/supabase_flutter.dart';

// Ortak arayüz
abstract class AuthService {
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
  String? get currentUserId;
}

// Mock (kalsın, dokunma)
class MockAuthService implements AuthService {
  String? _uid;
  @override String? get currentUserId => _uid;
  @override Future<void> signIn(String email, String password) async { _uid = email; }
  @override Future<void> signUp(String email, String password) => signIn(email, password);
  @override Future<void> signOut() async { _uid = null; }
}

// Supabase gerçek giriş
class SupabaseAuthService implements AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> signIn(String email, String password) async {
    final res = await _client.auth.signInWithPassword(
      email: email, password: password,
    );
    if (res.user == null) {
      throw Exception('Giriş başarısız');
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    final res = await _client.auth.signUp(
      email: email, password: password,
    );
    if (res.user == null) {
      throw Exception('Kayıt başarısız');
    }
    // E-posta doğrulaması açıksa mail gider; demo için şifre ile giriş yapabilirsin.
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
