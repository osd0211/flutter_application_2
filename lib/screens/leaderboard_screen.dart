// lib/screens/leaderboard_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../ui/app_theme.dart';
import '../services/game_repository.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

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

int _scoreChallengeWithBoxscore(
  PredictionChallenge c,
  PlayerStat? stat,
) {
  if (stat == null) return 0;

  final double ptsBase = _rangeScore(
    predicted: c.points,
    actual: stat.pts,
    maxScore: 60.0,
    range: 40.0,
  );

  final double astBase = _rangeScore(
    predicted: c.assists,
    actual: stat.ast,
    maxScore: 40.0,
    range: 12.0,
  );

  final double rebBase = _rangeScore(
    predicted: c.rebounds,
    actual: stat.reb,
    maxScore: 40.0,
    range: 12.0,
  );

  int bonus = 0;
  int exactCount = 0;

  if (c.points == stat.pts) {
    bonus += 25;
    exactCount++;
  }
  if (c.assists == stat.ast) {
    bonus += 20;
    exactCount++;
  }
  if (c.rebounds == stat.reb) {
    bonus += 20;
    exactCount++;
  }

  if (exactCount == 2) {
    bonus += 50;
  } else if (exactCount == 3) {
    bonus += 120;
  }

  final double total = ptsBase + astBase + rebBase + bonus;
  return total.round();
}

class _UserChallengeScore {
  final int userId;
  final String userName;
  final String? userUsername;
  final String? userEmail;
  final bool isCurrentUser;
  final PredictionChallenge challenge;
  final int score;

  _UserChallengeScore({
    required this.userId,
    required this.userName,
    required this.userUsername,
    required this.userEmail,
    required this.isCurrentUser,
    required this.challenge,
    required this.score,
  });

  String get label {
    final u = (userUsername ?? '').trim();
    if (u.isNotEmpty) return '@$u';
    final n = userName.trim();
    if (n.isNotEmpty) return n;
    return userEmail ?? 'User $userId';
  }
}

Future<List<_UserChallengeScore>> _loadScoresForSelectedDay(
  BuildContext context,
) async {
  final repo = context.read<GameRepository>();
  final auth = context.read<IAuthService>();

  final phase = repo.simulationPhase;
  final bool showScores = phase == SimulationPhase.finished;

  final box = repo.boxscoreForSelected(); // {playerId -> PlayerStat}
  final players = repo.playersForSelected();
  final games = repo.matchScoresForSelected();
  final matchIds = games.map((g) => g.gameId).toList();
  if (matchIds.isEmpty) return [];

  //  maç bittiyse: finalize (badge/XP) tek sefer çalışsın
  if (showScores) {
    await DatabaseService.finalizeScoresForMatches(
      matchIds: matchIds,
      boxscoreByPlayerId: box,
    );
  }

  final rows = await DatabaseService.loadPredictionsWithUsersForMatches(matchIds);
  final currentUserId = auth.currentUserId;

  final List<_UserChallengeScore> result = [];

  for (final row in rows) {
    final int userId = row['user_id'] as int;
    final String userName = (row['user_name'] as String?) ?? '';
    final String? userUsername = row['user_username'] as String?;
    final String? userEmail = row['user_email'] as String?;

    final String matchId = row['match_id'] as String;
    final String playerId = row['player_id'] as String;
    final String challengeId =
        (row['challenge_id'] as String?) ?? '${matchId}_$playerId';

    final int predPts = (row['pred_pts'] as num).toInt();
    final int predAst = (row['pred_ast'] as num).toInt();
    final int predReb = (row['pred_reb'] as num).toInt();

    final String? createdAtStr = row['created_at'] as String?;
    DateTime createdAt;
    if (createdAtStr != null) {
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    final playerName = players[playerId]?.name ?? 'Player $playerId';

    final challenge = PredictionChallenge(
      id: challengeId,
      matchId: matchId,
      playerId: playerId,
      playerName: playerName,
      points: predPts,
      assists: predAst,
      rebounds: predReb,
      createdAt: createdAt,
    );

    final stat = showScores ? box[playerId] : null;
    final score = showScores ? _scoreChallengeWithBoxscore(challenge, stat) : 0;

    result.add(
      _UserChallengeScore(
        userId: userId,
        userName: userName,
        userUsername: userUsername,
        userEmail: userEmail,
        isCurrentUser: currentUserId != null && userId == currentUserId,
        challenge: challenge,
        score: score,
      ),
    );
  }

  return result;
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
      builder: (context, value, child) {

        final repo = context.watch<GameRepository>();
        final phase = repo.simulationPhase;
        final bool showScores = phase == SimulationPhase.finished;

        final auth = context.watch<IAuthService>();
        final isAdmin = auth.currentUserRole == 'admin';

        return FutureBuilder<List<_UserChallengeScore>>(
          future: _loadScoresForSelectedDay(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: Text(
                    showScores
                        ? 'Bu gün için henüz tahmin veya puan yok.'
                        : 'Tahminler alındı. Skorlar maçlar bitince hesaplanacak.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            final scores = snapshot.data!;

            if (isAdmin) {
              return _buildAdminView(scores, showScores: showScores);
            } else {
              final currentUserId = auth.currentUserId;
              return _buildUserView(scores, currentUserId, showScores: showScores);
            }
          },
        );
      },
    );
  }

  Widget _buildAdminView(List<_UserChallengeScore> scores, {required bool showScores}) {
    final Map<int, int> totals = {};
    final Map<int, String> labels = {};
    final Map<int, int> counts = {};

    for (final s in scores) {
      totals.update(s.userId, (v) => v + (showScores ? s.score : 0),
          ifAbsent: () => (showScores ? s.score : 0));
      labels[s.userId] = s.label;
      counts.update(s.userId, (v) => v + 1, ifAbsent: () => 1);
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final allChallenges = List<_UserChallengeScore>.from(scores)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!showScores)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Maçlar bitmeden skorlar gizli. Maç bitince otomatik hesaplanır.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const Text(
            'Kullanıcı Toplam Puanları',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...entries.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final userId = entry.value.key;
            final total = entry.value.value;
            final label = labels[userId] ?? 'User $userId';
            final count = counts[userId] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                    child: Text('$rank'),
                  ),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Tahmin sayısı: $count',
                      style: const TextStyle(color: Colors.white70)),
                  trailing: Text(
                    showScores ? '$total' : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Tüm Tahminler',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...allChallenges.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                child: ListTile(
                  title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${s.challenge.playerName}\n'
                    'Tahmin: ${s.challenge.points} sayı · '
                    '${s.challenge.assists} ast · '
                    '${s.challenge.rebounds} rib',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Text(
                    showScores ? '${s.score}' : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserView(
    List<_UserChallengeScore> scores,
    int? currentUserId, {
    required bool showScores,
  }) {
    final myScores = scores.where((s) => s.isCurrentUser).toList();

    final Map<int, int> totals = {};
    final Map<int, String> labels = {};

    for (final s in scores) {
      totals.update(s.userId, (v) => v + (showScores ? s.score : 0),
          ifAbsent: () => (showScores ? s.score : 0));
      labels[s.userId] = s.label;
    }

    final totalEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int myTotal = currentUserId != null
        ? (totals[currentUserId] ?? 0)
        : myScores.fold(0, (sum, s) => sum + (showScores ? s.score : 0));

    final myPairs = myScores.map((s) => '${s.challenge.matchId}_${s.challenge.playerId}').toSet();

    final rivals = scores.where((s) {
      if (s.isCurrentUser) return false;
      final key = '${s.challenge.matchId}_${s.challenge.playerId}';
      return myPairs.contains(key);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!showScores)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Maçlar bitmeden skorlar gizli. Maç bitince otomatik hesaplanır.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const Text(
            'Genel Sıralama (Toplam Puanlar)',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...totalEntries.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final userId = entry.value.key;
            final total = entry.value.value;
            final label = labels[userId] ?? 'User $userId';

            final bool isMe = currentUserId != null && userId == currentUserId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                color: isMe ? const Color(0xFF142850) : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                    child: Text('$rank'),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMe ? AppColors.yellow : Colors.white,
                    ),
                  ),
                  trailing: Text(
                    showScores ? '$total' : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              title: const Text('Toplam Puanın', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                myScores.isEmpty ? 'Henüz tahmin yapmadın.' : 'Toplam tahmin sayısı: ${myScores.length}',
              ),
              trailing: Text(
                showScores ? '$myTotal' : '—',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.yellow),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Senin Tahminlerin',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (myScores.isEmpty)
            const Text('Bu gün için tahminin yok.', style: TextStyle(color: Colors.white70))
          else
            ...myScores.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  child: ListTile(
                    title: Text(s.challenge.playerName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Tahmin: ${s.challenge.points} sayı · '
                      '${s.challenge.assists} ast · '
                      '${s.challenge.rebounds} rib',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Text(
                      showScores ? '${s.score}' : '—',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.yellow),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'Aynı Oyuncuya Tahmin Yapanlar',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (rivals.isEmpty)
            const Text(
              'Seninle aynı oyuncuya tahmin yapan başka kullanıcı yok.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...rivals.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  child: ListTile(
                    title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${s.challenge.playerName}\n'
                      'Tahmin: ${s.challenge.points} sayı · '
                      '${s.challenge.assists} ast · '
                      '${s.challenge.rebounds} rib',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Text(
                      showScores ? '${s.score}' : '—',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.yellow),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
// OSD