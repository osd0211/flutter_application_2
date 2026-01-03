import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../ui/app_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _submitting = false;

  // ✅ eye toggles
  bool _obscurePass1 = true;
  bool _obscurePass2 = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final auth = context.read<IAuthService>();
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    try {
      await auth.signUp(email, name, username, pass);

      if (!mounted) return;
      Navigator.of(context).pop(); // back to login
    } catch (e) {
      setState(() => _submitting = false);

      final msg = e.toString().contains('email-already-exists')
          ? 'Bu email ile zaten bir hesap var.'
          : e.toString().contains('username-already-exists')
              ? 'Bu kullanıcı adı alınmış.'
              : 'Kayıt olurken bir hata oluştu.';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  InputDecoration _passDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        tooltip: obscure ? 'Göster' : 'Gizle',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'İsim',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'İsim boş olamaz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı adı',
                  hintText: 'ornek: omer_123',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Kullanıcı adı boş olamaz';
                  if (value.length < 3) return 'En az 3 karakter olmalı';

                  final ok = RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value);
                  if (!ok) return 'Sadece harf, rakam, _ ve . kullan';

                  return null;
                },
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email boş olamaz';
                  }
                  if (!v.contains('@')) {
                    return 'Geçerli bir email gir';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ✅ password with eye icon
              TextFormField(
                controller: _passCtrl,
                decoration: _passDecoration(
                  label: 'Şifre',
                  obscure: _obscurePass1,
                  onToggle: () => setState(() => _obscurePass1 = !_obscurePass1),
                ),
                obscureText: _obscurePass1,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Şifre boş olamaz';
                  }
                  if (v.length < 4) {
                    return 'Şifre en az 4 karakter olmalı';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ✅ password repeat with eye icon
              TextFormField(
                controller: _pass2Ctrl,
                decoration: _passDecoration(
                  label: 'Şifre (tekrar)',
                  obscure: _obscurePass2,
                  onToggle: () => setState(() => _obscurePass2 = !_obscurePass2),
                ),
                obscureText: _obscurePass2,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Şifre tekrar boş olamaz';
                  }
                  if (v != _passCtrl.text) {
                    return 'Şifreler aynı değil';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Kaydediliyor...' : 'Kayıt Ol'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
