import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'admin_users_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _showEditUsernameDialog(
    BuildContext context, {
    required int userId,
    required String currentUsername,
    required int level,
    required bool isAdmin,
  }) async {
    // ✅ Admin her zaman değiştirebilir
    if (!isAdmin && level < 5) return;

    final ctrl = TextEditingController(text: currentUsername == '-' ? '' : currentUsername);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcı adını değiştir'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Yeni kullanıcı adı',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final newUsername = result.trim();
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı boş olamaz')),
      );
      return;
    }

    try {
      // ✅ DB'ye yaz (unique kontrol içinde var)
      await DatabaseService.adminUpdateUsername(
        userId: userId,
        newUsername: newUsername,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username güncellendi ✅ (görmek için çıkış-giriş yap)'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      final msg = e.toString().contains('username-already-exists')
          ? 'Bu kullanıcı adı alınmış.'
          : e.toString().contains('username-empty')
              ? 'Kullanıcı adı boş olamaz.'
              : 'Güncelleme sırasında hata oluştu.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<IAuthService>();

    final userId = auth.currentUserId ?? -1;
    final name = auth.currentUserName ?? '-';
    final username = auth.currentUsername ?? '-';
    final email = auth.currentUserEmail ?? '-';
    final role = auth.currentUserRole ?? '-';

    final level = auth.currentUserLevel;
    final xp = auth.currentUserXp;

    final isAdmin = (auth.currentUserRole ?? '') == 'admin';

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text(
            'Profil',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('İsim', name),
                  const Divider(height: 24),
                  _row('Kullanıcı adı', username),
                  const Divider(height: 24),
                  _row('Email', email),
                  const Divider(height: 24),
                  _row('Rol', role),
                  const Divider(height: 24),
                  _row('Level', '$level'),
                  const Divider(height: 24),
                  _row('XP', '$xp'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: Icon((isAdmin || level >= 5) ? Icons.edit : Icons.lock_outline),
              title: const Text('Kullanıcı adı değiştirme'),
              subtitle: Text(
                isAdmin
                    ? 'Admin ✅ (level bağımsız)'
                    : (level >= 5 ? 'Açık ✅ (Level 5+)' : 'Kilitli 🔒 (Level 5’te açılır)'),
              ),
              trailing: (isAdmin || level >= 5)
                  ? const Icon(Icons.arrow_forward_ios, size: 16)
                  : const Icon(Icons.lock),
              onTap: (isAdmin || level >= 5)
                  ? () => _showEditUsernameDialog(
                        context,
                        userId: userId,
                        currentUsername: username,
                        level: level,
                        isAdmin: isAdmin,
                      )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Nasıl level atlarım?'),
              subtitle: const Text('Tahmin yaptıkça XP kazanırsın. (Bir sonraki adımda bağlayacağız)'),
            ),
          ),

          // ✅ ADMIN PANEL KARTI
          if (isAdmin) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin Panel'),
                subtitle: const Text('Kullanıcıların username/level/xp düzenle (test)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
