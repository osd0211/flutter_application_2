// lib/services/auth_service.dart
abstract class IAuthService {
  String? get currentUserId;

  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

/// Basit mock: her girişte sabit bir uid üretir, signOut ile sıfırlar.
class AuthServiceMock implements IAuthService {
  String? _uid;

  @override
  String? get currentUserId => _uid;

  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _uid = 'mock-user-001';
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _uid = null;
  }
}
