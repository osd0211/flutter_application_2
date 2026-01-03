// lib/screens/admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../services/auth_service.dart';

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
    final int id = (u['id'] as int?) ?? -1;
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
              child: Text(
                '$name • $role\n$email',
                style: const TextStyle(fontSize: 12),
              ),
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

      // ✅ Eğer düzenlenen kullanıcı şu an login olan kullanıcıysa cache’i yenile
      final auth = context.read<IAuthService>();
      if (auth.currentUserId == id) {
        await auth.refreshCurrentUser(); // ✅ doğru method
      }

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

  Future<void> _resetUserProgress({
    required int userId,
    required String name,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misin?'),
        content: Text(
          '$name kullanıcısının TÜM rozetleri ve XP sıfırlanacak.\n'
          'Bu işlem sadece test içindir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await DatabaseService.adminResetBadgesAndXp(userId: userId);

    // ✅ Eğer resetlenen kullanıcı şu an login olan kullanıcıysa cache’i yenile
    final auth = context.read<IAuthService>();
    if (auth.currentUserId == userId) {
      await auth.refreshCurrentUser(); // ✅ doğru method
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rozetler ve XP sıfırlandı ✅')),
    );

    await _load();
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

                final int id = (u['id'] as int?) ?? -1;
                final String name = (u['name'] as String?) ?? '-';
                final String role = (u['role'] as String?) ?? '-';
                final String username = (u['username'] as String?) ?? '-';
                final int level = (u['level'] as int?) ?? 1;

                return ListTile(
                  title: Text('$name  (@$username)'),
                  subtitle: Text('id: $id • role: $role • level: $level'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restart_alt, color: Colors.orange),
                        tooltip: 'Rozetleri & XP sıfırla (TEST)',
                        onPressed: () => _resetUserProgress(userId: id, name: name),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editUser(u),
                      ),
                    ],
                  ),
                  onTap: () => _editUser(u),
                );
              },
            ),
    );
  }
}
