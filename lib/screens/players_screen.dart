// lib/screens/players_screen.dart
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

    // AppBar’ı kaldırdık; dıştaki _HomeShell’de zaten AppBar var
    if (day == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return _buildPlayers(repo);
  }

  Widget _buildPlayers(GameRepository repo) {
    final box = repo.boxscoreForSelected();
    final players = repo.playersForSelected(); // id -> Player
    final entries = box.entries.toList()
      ..sort((a, b) => b.value.pts.compareTo(a.value.pts));

    if (entries.isEmpty) {
      return const Center(
        child: Text('Oyuncu verisi yok', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.white12),
      itemBuilder: (_, i) {
        final id = entries[i].key;
        final s = entries[i].value;
        final name = players[id]?.name ?? id;

        return ListTile(
          leading: const CircleAvatar(radius: 18),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            'Sayı ${s.pts} • Asist ${s.ast} • Rib ${s.reb}',
            style: const TextStyle(color: Colors.white70),
          ),
        );
      },
    );
  }
}
