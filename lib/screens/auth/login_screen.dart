// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/env.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mail = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _mail.dispose();
    _pass.dispose();
    super.dispose();
  }

 Future<void> _doLogin() async {
  setState(() => _busy = true);
  final email = _mail.text.trim();
  final pass = _pass.text;

  try {
    await Env.auth.signIn(email, pass);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login successful')),
    );

    // ÖNEMLİ: Ana sayfaya yönlendir
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login failed: $e')),
    );
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _mail,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _doLogin,
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }
}
