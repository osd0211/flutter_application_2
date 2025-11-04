import '../models.dart';

final Match fbReal = Match(
  id: 'M1',
  home: 'Fenerbahçe',
  away: 'Real Madrid',
  tipoff: '20:45',
  homePts: 86,
  awayPts: 79,
  status: 'FT',
  roster: [
    Player(name: 'S. Wilbekin', team: 'Fenerbahçe', pts: 19, reb: 3, ast: 5),
    Player(name: 'N. Hayes-Davis', team: 'Fenerbahçe', pts: 14, reb: 6, ast: 2),
    Player(name: 'M. Hezonja', team: 'Real Madrid', pts: 17, reb: 5, ast: 2),
    Player(name: 'W. Tavares', team: 'Real Madrid', pts: 12, reb: 9, ast: 1),
  ],
);

final Match efesBarca = Match(
  id: 'M2',
  home: 'Anadolu Efes',
  away: 'Barcelona',
  tipoff: '21:00',
  status: 'Q4 03:12',
  homePts: 71,
  awayPts: 73,
  roster: [
    Player(name: 'S. Larkin', team: 'Anadolu Efes', pts: 21, reb: 3, ast: 7),
    Player(name: 'W. Clyburn', team: 'Anadolu Efes', pts: 13, reb: 4, ast: 2),
    Player(name: 'W. Hernangómez', team: 'Barcelona', pts: 15, reb: 7, ast: 1),
    Player(name: 'N. Laprovittola', team: 'Barcelona', pts: 11, reb: 2, ast: 6),
  ],
);

final Match olyPartizan = Match(
  id: 'M3',
  home: 'Olympiacos',
  away: 'Partizan',
  tipoff: '22:00',
  status: 'Scheduled',
  roster: [
    Player(name: 'K. Papanikolaou', team: 'Olympiacos', pts: 0, reb: 0, ast: 0),
    Player(name: 'N. Milutinov', team: 'Olympiacos', pts: 0, reb: 0, ast: 0),
    Player(name: 'K. Punter', team: 'Partizan', pts: 0, reb: 0, ast: 0),
    Player(name: 'F. Kaminsky', team: 'Partizan', pts: 0, reb: 0, ast: 0),
  ],
);

final List<Match> mockMatches = [fbReal, efesBarca, olyPartizan];

/// simple helper: flatten all match rosters
List<Player> allPlayersToday() =>
    mockMatches.expand((m) => m.roster).toList();
