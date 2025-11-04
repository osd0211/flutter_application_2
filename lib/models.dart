enum StatType { pts, reb, ast }

class Match {
  final String id;
  final String home;
  final String away;
  final String tipoff;
  int homePts;
  int awayPts;
  String status;
  bool favorite;
  final List<Player> roster;

  Match({
    required this.id,
    required this.home,
    required this.away,
    required this.tipoff,
    this.homePts = 0,
    this.awayPts = 0,
    this.status = 'Scheduled',
    this.favorite = false,
    this.roster = const [],
  });
}

class Player {
  final String name;
  final String team;
  double pts;
  double reb;
  double ast;

  Player({
    required this.name,
    required this.team,
    this.pts = 0,
    this.reb = 0,
    this.ast = 0,
  });
}

enum ChallengeStatus { pending, won, lost }

class PredictionChallenge {
  final String id;
  final String matchId;
  final String playerName;
  final String team;
  final Map<StatType, int> predictions;
  int points;
  ChallengeStatus status;

  PredictionChallenge({
    required this.id,
    required this.matchId,
    required this.playerName,
    required this.team,
    required this.predictions,
    this.points = 0,
    this.status = ChallengeStatus.pending,
  });
}
