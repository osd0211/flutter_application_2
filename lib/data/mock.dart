// lib/data/mock.dart
import '../models.dart';

// Örnek oyuncular
const _efes = [
  Player(id: 'p-larkin', name: 'Shane Larkin'),
  Player(id: 'p-beaubois', name: 'Rodrigue Beaubois'),
  Player(id: 'p-pleiss', name: 'Tibor Pleiss'),
];

const _monaco = [
  Player(id: 'p-mike', name: 'Mike James'),
  Player(id: 'p-okobo', name: 'Elie Okobo'),
  Player(id: 'p-john', name: 'John Brown'),
];

const _fener = [
  Player(id: 'p-wilbekin', name: 'Scottie Wilbekin'),
  Player(id: 'p-guduric', name: 'Marko Guduric'),
  Player(id: 'p-motley', name: 'Johnathan Motley'),
];

// Maçlar + skorlar (Skorlar ekranı bunları gösterir)
final List<MatchGame> mockGames = [
  MatchGame(
    id: 'g1',
    homeTeam: 'Anadolu Efes',
    awayTeam: 'AS Monaco',
    homeScore: 87,
    awayScore: 83,
    tipoff: DateTime.now().subtract(const Duration(hours: 2)),
    roster: [..._efes, ..._monaco],
  ),
  MatchGame(
    id: 'g2',
    homeTeam: 'Fenerbahçe',
    awayTeam: 'Virtus Bologna',
    homeScore: 79,
    awayScore: 76,
    tipoff: DateTime.now().subtract(const Duration(days: 1)),
    roster: [..._fener],
  ),
];

// Başlangıçta boş bir liste; kullanıcı tahmin yaptıkça dolacak
final List<PredictionChallenge> mockChallenges = [];
