import 'package:flutter/material.dart';

import '../services/database_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  List<Map<String, Object?>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DatabaseService.adminLoadAllUsers();
    if (!mounted) return;
    setState(() {
      _users = rows;
      _loading = false;
    });
  }

  Future<void> _editUser(Map<String, Object?> u) async {
    final int id = u['id'] as int;
    final String name = (u['name'] as String?) ?? '-';
    final String email = (u['email'] as String?) ?? '-';
    final String role = (u['role'] as String?) ?? '-';
    final String username = (u['username'] as String?) ?? '';
    final int level = (u['level'] as int?) ?? 1;
    

    final usernameCtrl = TextEditingController(text: username);
    final levelCtrl = TextEditingController(text: level.toString());
   

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcıyı Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('$name • $role\n$email', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: levelCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Level'),
            ),
            
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (action != 'save') return;

    try {
      final newUsername = usernameCtrl.text.trim();
      final newLevel = int.tryParse(levelCtrl.text.trim()) ?? 1;
      

      if (newUsername.isNotEmpty) {
        await DatabaseService.adminUpdateUsername(userId: id, newUsername: newUsername);
      }
      await DatabaseService.adminSetLevel(userId: id, level: newLevel);
     

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncellendi ✅')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('username-already-exists')
          ? 'Bu username alınmış.'
          : e.toString().contains('username-empty')
              ? 'Username boş olamaz.'
              : 'Güncelleme hatası.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin • Kullanıcılar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = _users[i];
                final id = u['id'];
                final name = u['name'] ?? '-';
                final role = u['role'] ?? '-';
                final username = u['username'] ?? '-';
                final level = u['level'] ?? 1;

                return ListTile(
                  title: Text('$name  (@$username)'),
                  subtitle: Text('id: $id • role: $role • level: $level'),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _editUser(u),
                );
              },
            ),
    );
  }
}
