// lib/services/auth_service.dart
/// Basit bir mock auth servisi: gerçek backend yok.
/// Uygulama içinde `Env.auth` üzerinden kullanacağız.

abstract class IAuthService {
  String? get currentUserId;
  Future<void> signInAnonymously();
  Future<void> signOut();
}

class AuthServiceMock implements IAuthService {
  String? _uid = 'demo-user'; // uygulama açılır açılmaz login kabul ediyoruz

  @override
  String? get currentUserId => _uid;

  @override
  Future<void> signInAnonymously() async {
    _uid = 'demo-user';
  }

  @override
  Future<void> signOut() async {
    _uid = null;
  }
}
