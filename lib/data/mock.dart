// lib/data/mock.dart
// Sadece mock veri: maçlar + oyuncular + basit yardımcılar

import '../models.dart';


// Bugünün box-score'u: playerId -> stat
final Map<String, PlayerStat> mockBoxscoreToday = {
  'p-larkin'   : const PlayerStat(pts: 21, ast: 7, reb: 4),
  'p-beaubois' : const PlayerStat(pts: 14, ast: 4, reb: 2),
  'p-pleiss'   : const PlayerStat(pts: 12, ast: 1, reb: 6),

  'p-wilbekin' : const PlayerStat(pts: 22, ast: 5, reb: 2),
  'p-guduric'  : const PlayerStat(pts: 17, ast: 6, reb: 5),
  'p-motley'   : const PlayerStat(pts: 15, ast: 2, reb: 9),

  'p-sloukas'  : const PlayerStat(pts: 10, ast: 8, reb: 3),
  'p-nunn'     : const PlayerStat(pts: 21, ast: 3, reb: 4),

  'p-satoransky': const PlayerStat(pts: 9,  ast: 7, reb: 4),
  'p-mirotic'   : const PlayerStat(pts: 18, ast: 2, reb: 6),
};

// Güvenli erişim helper’ı
PlayerStat statFor(String playerId) =>
    mockBoxscoreToday[playerId] ?? const PlayerStat();

const _efes = 'Anadolu Efes';
const _fener = 'Fenerbahçe';
const _pana = 'Panathinaikos';
const _barca = 'Barcelona';

const List<Player> _efesPlayers = [
  Player(id: 'p-larkin', name: 'Shane Larkin', team: _efes),
  Player(id: 'p-beaubois', name: 'Rodrigue Beaubois', team: _efes),
  Player(id: 'p-pleiss', name: 'Tibor Pleiss', team: _efes),
];

const List<Player> _fenerPlayers = [
  Player(id: 'p-wilbekin', name: 'Scottie Wilbekin', team: _fener),
  Player(id: 'p-guduric', name: 'Marko Gudurić', team: _fener),
  Player(id: 'p-motley', name: 'Johnathan Motley', team: _fener),
];

const List<Player> _panaPlayers = [
  Player(id: 'p-sloukas', name: 'Kostas Sloukas', team: _pana),
  Player(id: 'p-nunn', name: 'Kendrick Nunn', team: _pana),
];

const List<Player> _barcaPlayers = [
  Player(id: 'p-satoransky', name: 'Tomas Satoransky', team: _barca),
  Player(id: 'p-mirotic', name: 'Nikola Mirotic', team: _barca),
];

/// Bugünün maçları (yaklaşan / oynanan / bitti karması)
final List<MatchGame> mockGamesToday = [
  MatchGame(
    id: 'g1',
    home: _efes,
    away: _fener,
    tipoff: DateTime.now().add(const Duration(hours: 1)),
    live: false,
    finished: false,
    roster: [..._efesPlayers, ..._fenerPlayers],
  ),
  MatchGame(
    id: 'g2',
    home: _pana,
    away: _barca,
    tipoff: DateTime.now().subtract(const Duration(minutes: 20)),
    live: true,
    finished: false,
    roster: [..._panaPlayers, ..._barcaPlayers],
  ),
  MatchGame(
    id: 'g3',
    home: _efes,
    away: _barca,
    tipoff: DateTime.now().subtract(const Duration(hours: 3)),
    live: false,
    finished: true,
    roster: [..._efesPlayers, ..._barcaPlayers],
  ),
];

/// Belirli maçtaki oyuncular
List<Player> playersForMatch(String matchId) {
  return mockGamesToday.firstWhere((m) => m.id == matchId).roster;
}

/// Basit id üretimi (uuid yerine)
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
