// lib/services/game_repository.dart
// Amaç: Çok-gün box-score saklama, gün seçme, lazy/preload yükleme.

import 'package:flutter/foundation.dart';
import '../models.dart';
import 'data_source.dart';

class GameRepository extends ChangeNotifier {
  // day -> {playerId -> PlayerStat}
  final Map<DateTime, Map<String, PlayerStat>> _boxscores = {};
  DateTime? _selectedDay;

  DateTime? get selectedDay => _selectedDay;

  /// Yüklü günlerin listesi (tarih olarak). UI'da dropdown'a basmak için.
  List<DateTime> get availableDays {
    final list = _boxscores.keys.toList()..sort();
    return list;
  }

  /// Seçili gün için boxscore var mı?
  bool get hasBoxscoreForSelected {
    final d = _selectedDay;
    if (d == null) return false;
    return _boxscores.containsKey(_dateOnly(d));
  }

  /// Seçili günün boxscore'u. Yoksa boş map döner.
  Map<String, PlayerStat> boxscoreForSelected() {
    final d = _selectedDay;
    if (d == null) return const {};
    return _boxscores[_dateOnly(d)] ?? const {};
  }

  /// Belirli bir günün boxscore'unu set et.
  void setBoxscore(DateTime day, Map<String, PlayerStat> box) {
    _boxscores[_dateOnly(day)] = box;
    notifyListeners();
  }

  /// Gün seç.
  void selectDay(DateTime day) {
    _selectedDay = _dateOnly(day);
    notifyListeners();
  }

  /// Lazy: Gün yüklenmemişse assets'ten yükle.
  Future<void> ensureDayLoaded(DateTime day) async {
    final d = _dateOnly(day);
    if (_boxscores.containsKey(d)) return;

    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final assetPath = 'assets/euroleague/boxscores_${yyyy}_${mm}_$dd.csv';

    final box = await DataSource.instance.loadBoxscoreFromAssets(assetPath);
    setBoxscore(d, box);
  }

  /// İstersen uygulama açılışında tüm CSV'leri preload edebilirsin.
  Future<void> preloadAllFromAssets() async {
    final paths = await DataSource.instance.listAllCsvAssets();
    for (final p in paths) {
      final day = DataSource.extractDateFromPath(p);
      if (day == null) continue;
      final box = await DataSource.instance.loadBoxscoreFromAssets(p);
      _boxscores[_dateOnly(day)] = box;
    }
    // Varsayılan bir gün seç (son gün)
    if (_selectedDay == null && _boxscores.isNotEmpty) {
      final last = (availableDays).last;
      _selectedDay = last;
    }
    notifyListeners();
  }

  /// Seçili gün ve oyuncu id'ye göre stat getir (yoksa 0'lı stat).
  PlayerStat statForSelected(String playerId) {
    final box = boxscoreForSelected();
    return box[playerId] ?? const PlayerStat();
    // PlayerStat() default 0 değerlerle tanımlı olmalı (models.dart’ta).
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
