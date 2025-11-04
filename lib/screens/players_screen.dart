// lib/screens/players_screen.dart
import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../models.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Oyuncu bazında birikim
    final Map<String, _Agg> agg = {};
    for (final PredictionChallenge c in mockChallenges) {
      final key = c.playerId;
      agg.putIfAbsent(key, () => _Agg(name: c.playerName));
      agg[key]!
        ..pts += c.points
        ..ast += c.assists
        ..reb += c.rebounds
        ..count += 1;
    }

    final items = agg.entries.toList()
      ..sort((a, b) => (b.value.pts + b.value.ast + b.value.reb)
          .compareTo(a.value.pts + a.value.ast + a.value.reb));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = items[i];
        final a = e.value;
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(a.name),
            subtitle: Text(
              'Toplam: ${a.pts} sayı • ${a.ast} asist • ${a.reb} ribaund  '
              '(kayıt: ${a.count})',
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class _Agg {
  _Agg({required this.name});
  final String name;
  int pts = 0;
  int ast = 0;
  int reb = 0;
  int count = 0;
}
