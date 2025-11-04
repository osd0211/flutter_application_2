import 'package:flutter/material.dart';
import '../../core/env.dart';
import '../../ui/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'demo@user.com');
  final _pass = TextEditingController(text: '123456');
  bool _loading = false;
  bool _isLogin = true;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await Env.auth.signIn(_email.text.trim(), _pass.text.trim());
      } else {
        await Env.auth.signUp(_email.text.trim(), _pass.text.trim());
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('EuroScore',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.yellow)),
                const SizedBox(height: 16),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Şifre'), obscureText: true),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_isLogin ? 'Giriş yap' : 'Kayıt ol'),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'Hesabın yok mu? Kayıt ol' : 'Hesabın var mı? Giriş yap'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
