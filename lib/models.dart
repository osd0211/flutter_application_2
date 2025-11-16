
// Maç simülasyon aşaması (global)
enum SimulationPhase {
  notStarted, // Maç başlamadı → skorlar/istatistikler 0, tahmin yapılabilir
  finished,   // Maç bitti → gerçek skor, tahmin yapılamaz
}



/// Basit Oyuncu modeli
class Player {
  final String id;
  final String name;
  final String team;
  const Player({required this.id, required this.name, required this.team});
}

/// Maç modeli (mock)
class MatchGame {
  final String id;
  final String home;
  final String away;
  final DateTime tipoff; // başlama saati
  final bool live;       // şu an oynanıyor mu
  final bool finished;   // bitti mi
  /// Bu maçta yer alan oyuncular (basit mock)
  final List<Player> roster;

  const MatchGame({
    required this.id,
    required this.home,
    required this.away,
    required this.tipoff,
    required this.live,
    required this.finished,
    required this.roster,
  });

  String get statusLabel {
    if (finished) return 'Bitti';
    if (live) return 'Oynanıyor';
    return 'Yaklaşan';
  }
}

enum ChallengeStatus { pending, scored }

/// Kullanıcının tahmini
class PredictionChallenge {
  final String id;
  final String matchId;
  final String playerId;
  final String playerName;

  final int points;
  final int assists;
  final int rebounds;

  final DateTime createdAt;
  final ChallengeStatus status;

  const PredictionChallenge({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.playerName,
    required this.points,
    required this.assists,
    required this.rebounds,
    required this.createdAt,
    this.status = ChallengeStatus.pending,
  });
}

// Basit oyuncu istatistiği (bugünkü box score)
class PlayerStat {
  final int pts;
  final int ast;
  final int reb;
  const PlayerStat({this.pts = 0, this.ast = 0, this.reb = 0});
}

// lib/models.dart

int _scoreSingleStat({
  required int predicted,
  required int actual,
  required int baseScore,
  required int tightDiff,
  required int mediumDiff,
}) {
  final diff = (predicted - actual).abs();

  double multiplier;
  if (diff == 0) {
    multiplier = 3.0;
  } else if (diff <= tightDiff) {
    multiplier = 2.0;
  } else if (diff <= mediumDiff) {
    multiplier = 1.0;
  } else {
    multiplier = 0.0;
  }

  return (baseScore * multiplier).round();
}

int scoreChallengeWithBoxscore(
  PredictionChallenge c,
  PlayerStat? stat,
) {
  if (stat == null) return 0;

  final ptsScore = _scoreSingleStat(
    predicted: c.points,
    actual: stat.pts,
    baseScore: 10,
    tightDiff: 2,
    mediumDiff: 5,
  );

  final astScore = _scoreSingleStat(
    predicted: c.assists,
    actual: stat.ast,
    baseScore: 8,
    tightDiff: 1,
    mediumDiff: 3,
  );

  final rebScore = _scoreSingleStat(
    predicted: c.rebounds,
    actual: stat.reb,
    baseScore: 8,
    tightDiff: 1,
    mediumDiff: 3,
  );

  return ptsScore + astScore + rebScore;
}








/// Bir maç için toplam skorlar (CSV'den hesaplanır)
class MatchScore {
  final String gameId;
  final String home;
  final String away;
  final DateTime tipoff;
  final int homePts;
  final int awayPts;

  const MatchScore({
    required this.gameId,
    required this.home,
    required this.away,
    required this.tipoff,
    required this.homePts,
    required this.awayPts,
  });
}

