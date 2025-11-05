import 'package:flutter/material.dart';
import '../core/env.dart';
import '../models.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Env.lastMatches -> seçili güne ait karşılaşmalar
    // Env.lastBoxscore -> en son tıklanan maçın boxscore'u (playerId -> stat)
    final matches = Env.lastMatches;

    // Tüm oyuncuları tekilleştir
    final Map<String, Player> map = {};
    for (final g in matches) {
      for (final p in g.roster) {
        map[p.id] = p;
      }
    }
    final players = map.values.toList();
    final stats = Env.lastBoxscore; // olabilir boş (tap etmeden)

    return Scaffold(
      appBar: AppBar(title: Text('Oyuncular (${Env.selectedDate.toLocal().toString().split(' ').first})')),
      body: players.isEmpty
          ? const Center(child: Text('Önce Skorlar’da bir gün seç / boxscore yükle'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = players[i];
                final s = stats[p.id]; // seçili maçın boxscore’u yüklüyse gelir
                final statText = (s == null)
                    ? 'Boxscore yüklenmedi'
                    : '${s.pts} sayı • ${s.ast} asist • ${s.reb} rib';

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(p.name),
                    subtitle: Text('${p.team} • $statText'),
                  ),
                );
              },
            ),
    );
  }
}
