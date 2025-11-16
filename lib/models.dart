
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

