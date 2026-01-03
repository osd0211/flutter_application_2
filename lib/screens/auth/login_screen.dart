// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController(); // email veya username
  final _pass = TextEditingController();

  bool _busy = false;
  String? _error;

  // ✅ eye toggle
  bool _obscurePass = true;

  @override
  void dispose() {
    _identifier.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final id = _identifier.text.trim();
    final pass = _pass.text;

    if (id.isEmpty || pass.isEmpty) {
      setState(() {
        _error = 'E-posta/kullanıcı adı ve şifre boş olamaz.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = context.read<IAuthService>();
      await auth.signIn(id, pass);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'E-posta/kullanıcı adı veya şifre hatalı.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Yap')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EuroScore',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Demo kullanıcı ile giriş yap 🚀',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _identifier,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'E-posta veya kullanıcı adı',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ password with eye icon
                TextField(
                  controller: _pass,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                      tooltip: _obscurePass ? 'Göster' : 'Gizle',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                ],

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Demo hesaplar:\n'
                    '• admin@euroscore.app / admin / 123456 (admin)\n'
                    '• omer@euroscore.app / osd / 123456\n'
                    '• ahmet@euroscore.app / 123456\n'
                    'Not: İstersen kullanıcı adıyla da giriş yapabilirsin.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _doLogin,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Giriş Yap'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignUpScreen(),
                            ),
                          );
                        },
                  child: const Text('Hesabın yok mu? Kayıt ol'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
