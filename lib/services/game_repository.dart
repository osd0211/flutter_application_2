import 'package:flutter/foundation.dart';

import '../models.dart';
import 'data_source.dart';
import 'database_service.dart';

class GameRepository extends ChangeNotifier {
  DateTime? _selectedDay;

  /// Default'u notStarted yapalım; gerçek değer DB'den yüklenecek
  SimulationPhase _phase = SimulationPhase.notStarted;

  List<MatchScore> _matches = const [];
  Map<String, PlayerStat> _box = const {};
  Map<String, Player> _players = const {};

  /// gameId -> o maçta oynayan playerId set'i
  Map<String, Set<String>> _playersByGame = const {};

  DateTime? get selectedDay => _selectedDay;
  SimulationPhase get simulationPhase => _phase;

  List<MatchScore> matchScoresForSelected() => _matches;
  Map<String, PlayerStat> boxscoreForSelected() => _box;
  Map<String, Player> playersForSelected() => _players;

  /// Belirli bir maç için sadece o maçta oynayan oyuncular
  List<Player> playersForGame(String gameId) {
    final ids = _playersByGame[gameId];
    if (ids == null || ids.isEmpty) return const [];

    final list = <Player>[];
    for (final id in ids) {
      final p = _players[id];
      if (p != null) list.add(p);
    }

    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  // ---------------------------------------------------------------------------
  // ✅ App açılışında phase'i DB'den yükle (gir-çık bug fix)
  // ---------------------------------------------------------------------------
  Future<void> loadSimulationPhaseFromDb() async {
    final saved = await DatabaseService.loadSimulationPhase();
    if (saved != null && saved != _phase) {
      _phase = saved;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Gün seçme + verileri yükleme
  // ---------------------------------------------------------------------------
  Future<void> selectDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    _selectedDay = normalized;

    final ds = DataSource.instance;

    final matches = await ds.loadMatchScoresFor(normalized);
    final box = await ds.loadBoxscoreFor(normalized);
    final players = await ds.loadPlayersMapFor(normalized);
    final playersByGame = await ds.loadGamePlayersFor(normalized);

    _matches = matches;
    _box = box;
    _players = players;
    _playersByGame = playersByGame;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ✅ Simülasyon aşaması (DB'ye kaydet)
  // ---------------------------------------------------------------------------
  Future<void> setSimulationPhase(SimulationPhase phase) async {
    if (_phase == phase) return;

    _phase = phase;
    notifyListeners();

    // ✅ persist (restart / gir-çık problemi çözülür)
    await DatabaseService.saveSimulationPhase(phase);

    // ✅ badge finalize tetiklerin varsa burada kalsın / dokunmuyoruz
  }
}
