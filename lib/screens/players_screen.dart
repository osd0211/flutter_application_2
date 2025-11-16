import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_repository.dart';
import '../ui/app_theme.dart';
import '../models.dart';

enum PlayerSortBy { points, assists, rebounds }

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  PlayerSortBy _sortBy = PlayerSortBy.points;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GameRepository>();
    final day = repo.selectedDay;

    if (day == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return _buildPlayers(repo);
  }

  Widget _buildPlayers(GameRepository repo) {
    final stats = repo.boxscoreForSelected();     // {playerId -> PlayerStat}
    final players = repo.playersForSelected();    // {playerId -> Player}
    final phase = repo.simulationPhase;

    // Sadece gerçek oyuncular: players map'inde karşılığı olan id'ler
    final entries = stats.entries
        .where((e) => players[e.key] != null)
        .toList();

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Oyuncu verisi yok',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Sıralama: her zaman gerçek istatistiğe göre (phase'den bağımsız)
    entries.sort((a, b) {
      final sa = a.value;
      final sb = b.value;
      switch (_sortBy) {
        case PlayerSortBy.points:
          return sb.pts.compareTo(sa.pts);
        case PlayerSortBy.assists:
          return sb.ast.compareTo(sa.ast);
        case PlayerSortBy.rebounds:
          return sb.reb.compareTo(sa.reb);
      }
    });

    return Column(
      children: [
        // Üstte sıralama seçici
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Sırala:',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              ToggleButtons(
                borderRadius: BorderRadius.circular(12),
                isSelected: [
                  _sortBy == PlayerSortBy.points,
                  _sortBy == PlayerSortBy.assists,
                  _sortBy == PlayerSortBy.rebounds,
                ],
                constraints:
                    const BoxConstraints(minHeight: 32, minWidth: 80),
                onPressed: (index) {
                  setState(() {
                    if (index == 0) {
                      _sortBy = PlayerSortBy.points;
                    } else if (index == 1) {
                      _sortBy = PlayerSortBy.assists;
                    } else {
                      _sortBy = PlayerSortBy.rebounds;
                    }
                  });
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('Sayı'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('Asist'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('Ribaund'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),

        // Oyuncu listesi
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (_, i) {
              final playerId = entries[i].key;
              final s = entries[i].value;
              final player = players[playerId]!;

              // İsim temiz
              final name = player.name.trim();

              // Simülasyon mantığı:
              // Maç Başlamadı -> tüm istatistikler 0 gözüksün
              // Maç Bitti -> gerçek değerler
              final pts =
                  phase == SimulationPhase.notStarted ? 0 : s.pts;
              final ast =
                  phase == SimulationPhase.notStarted ? 0 : s.ast;
              final reb =
                  phase == SimulationPhase.notStarted ? 0 : s.reb;

              return ListTile(
                leading: const CircleAvatar(radius: 18),
                title: Text(
                  name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Sayı $pts • Asist $ast • Rib $reb',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
