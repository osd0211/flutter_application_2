// lib/services/game_repository.dart
// Amaç: Çok-gün box-score saklama, gün seçme, lazy/preload yükleme + isim ve maç skoru önbelleği.

import 'package:flutter/foundation.dart';
import '../models.dart';
import 'data_source.dart';

class GameRepository extends ChangeNotifier {
  // day -> {playerId -> PlayerStat}
  final Map<DateTime, Map<String, PlayerStat>> _boxscores = {};
  // day -> {playerId -> Player}
  final Map<DateTime, Map<String, Player>> _players = {};
  // day -> List<MatchScore>
  final Map<DateTime, List<MatchScore>> _matchScores = {};

  DateTime? _selectedDay;
  DateTime? get selectedDay => _selectedDay;

  /// UI’da dropdown vb. için seçili güne ait boxscore anahtarlarından gün üretmek yerine,
  /// ekran tarafında zaten gün listesi hazırlanıyor. Bu getter yine de geriye
  /// önceden yüklenmiş günleri döndürür (gerekebilecek yerler için).
  List<DateTime> get availableDays {
    final set = <DateTime>{}
      ..addAll(_boxscores.keys)
      ..addAll(_players.keys)
      ..addAll(_matchScores.keys);
    final list = set.toList()..sort();
    return list;
  }

  Map<String, PlayerStat> boxscoreForSelected() {
    final d = _selectedDay;
    if (d == null) return <String, PlayerStat>{};
    return _boxscores[d] ?? <String, PlayerStat>{};
  }

  Map<String, Player> playersForSelected() {
    final d = _selectedDay;
    if (d == null) return <String, Player>{};
    return _players[d] ?? <String, Player>{};
  }

  List<MatchScore> matchScoresForSelected() {
    final d = _selectedDay;
    if (d == null) return const <MatchScore>[];
    return _matchScores[d] ?? const <MatchScore>[];
  }

  /// Verilen gün için (yüklü değilse) verileri yükler.
  Future<void> ensureDayLoaded(DateTime day) async {
    final key = _dateOnly(day);

    if (!_boxscores.containsKey(key)) {
      _boxscores[key] = await DataSource.instance.loadBoxscoreFor(key);
    }
    if (!_players.containsKey(key)) {
      _players[key] = await DataSource.instance.loadPlayersMapFor(key);
    }
    if (!_matchScores.containsKey(key)) {
      _matchScores[key] = await DataSource.instance.loadMatchScoresFor(key);
    }
  }

  /// Günü seç ve dinleyicileri tetikle.
  Future<void> selectDay(DateTime day) async {
    final key = _dateOnly(day);
    await ensureDayLoaded(key);
    _selectedDay = key;
    notifyListeners();
  }

  /// Seçili gün ve oyuncu id'ye göre stat getir (yoksa 0'lı stat).
  PlayerStat statForSelected(String playerId) {
    final box = boxscoreForSelected();
    return box[playerId] ?? const PlayerStat();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
