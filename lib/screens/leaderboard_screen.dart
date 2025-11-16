// lib/screens/leaderboard_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../ui/app_theme.dart';
import '../services/game_repository.dart';

/// Sabit aralığa göre oransal skor:
/// diff = |pred - actual|
/// oran = diff / range (max 1)
/// skor = (1 - oran) * maxScore
double _rangeScore({
  required int predicted,
  required int actual,
  required double maxScore,
  required double range,
}) {
  final int diff = (predicted - actual).abs();

  final double ratio = diff / range;
  final double clamped = ratio > 1.0 ? 1.0 : ratio;

  final double score = (1.0 - clamped) * maxScore;
  return score < 0 ? 0 : score;
}

/// Bir challenge için toplam skor (oran + bonuslar)
int _scoreChallengeWithBoxscore(
  PredictionChallenge c,
  PlayerStat? stat,
) {
  if (stat == null) return 0;

  // ---------- 1) ORANSAL PUANLAR ----------
  // Sayı: max 60 puan, mantıklı fark aralığı ~40 sayı
  final double ptsBase = _rangeScore(
    predicted: c.points,
    actual: stat.pts,
    maxScore: 60.0,
    range: 40.0,
  );

  // Asist: max 40 puan, mantıklı fark aralığı ~12 asist
  final double astBase = _rangeScore(
    predicted: c.assists,
    actual: stat.ast,
    maxScore: 40.0,
    range: 12.0,
  );

  // Ribaund: max 40 puan, mantıklı fark aralığı ~12 ribaund
  final double rebBase = _rangeScore(
    predicted: c.rebounds,
    actual: stat.reb,
    maxScore: 40.0,
    range: 12.0,
  );

  // ---------- 2) TEK TEK TAM BİLME BONUSLARI ----------
  int bonus = 0;
  int exactCount = 0;

  if (c.points == stat.pts) {
    bonus += 25; // sayı bonusu
    exactCount++;
  }

  if (c.assists == stat.ast) {
    bonus += 20; // asist bonusu
    exactCount++;
  }

  if (c.rebounds == stat.reb) {
    bonus += 20; // ribaund bonusu
    exactCount++;
  }

  // ---------- 3) KOMBO BONUSLARI ----------
  if (exactCount == 2) {
    // 2 istatistiği tam bilene ekstra
    bonus += 50;
  } else if (exactCount == 3) {
    // 3'ünü de tam bilene mega bonus
    bonus += 120;
  }

  final double total = ptsBase + astBase + rebBase + bonus;
  return total.round();
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    super.key,
    required this.challenges,
  });

  final ValueListenable<List<PredictionChallenge>> challenges;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PredictionChallenge>>(
      valueListenable: challenges,
      builder: (context, list, _) {
        final repo = context.watch<GameRepository>();
        final box = repo.boxscoreForSelected();

        final Map<String, int> totals = {};

        for (final c in list) {
          final stat = box[c.playerId];
          final add = _scoreChallengeWithBoxscore(c, stat);

          totals.update(c.playerName, (v) => v + add, ifAbsent: () => add);
        }

        final entries = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          backgroundColor: AppColors.background,
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(e.key),
                  trailing: Text(
                    '${e.value}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
