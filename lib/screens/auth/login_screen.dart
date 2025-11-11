// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../core/env.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final uid = Env.auth.currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Giriş')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: const Text('Durum'),
                subtitle: Text(uid == null ? 'Çıkışta' : 'Giriş yapıldı: $uid'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || uid != null
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await Env.auth.signInAnonymously();
                      if (mounted) setState(() => _busy = false);
                    },
              child: const Text('Anonim Giriş Yap'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy || uid == null
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await Env.auth.signOut();
                      if (mounted) setState(() => _busy = false);
                    },
              child: const Text('Çıkış Yap'),
            ),
          ],
        ),
      ),
    );
  }
}
