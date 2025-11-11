import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_repository.dart';
import '../ui/app_theme.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GameRepository>();
    final day = repo.selectedDay;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: day == null
            ? const Center(
                child: Text('Önce Skorlar’dan bir gün seç.',
                    style: TextStyle(color: Colors.white70)),
              )
            : _Body(repo: repo),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.repo});
  final GameRepository repo;

  @override
  Widget build(BuildContext context) {
    final box = repo.boxscoreForSelected();
    if (box.isEmpty) {
      return const Center(
        child: Text('Bu gün için oyuncu istatistiği yok.',
            style: TextStyle(color: Colors.white70)),
      );
    }

    // Örnek: oyuncuları sayıya göre sırala ve göster
    final entries = box.entries.toList()
      ..sort((a, b) => b.value.pts.compareTo(a.value.pts));

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
      itemBuilder: (_, i) {
        final id = entries[i].key; // elinde isim yoksa id gösterir
        final s = entries[i].value;
        return ListTile(
          leading: const CircleAvatar(radius: 18),
          title: Text(id, style: const TextStyle(color: Colors.white)),
          subtitle: Text('Sayı ${s.pts} • Asist ${s.ast} • Rib ${s.reb}',
              style: const TextStyle(color: Colors.white70)),
        );
      },
    );
  }
}
