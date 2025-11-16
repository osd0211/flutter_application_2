// lib/services/data_source.dart
// Amaç: assets/euroleague içindeki günlük CSV'lerden
// boxscore, oyuncu map'i ve maç skorları üretmek.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';

class DataSource {
  DataSource._();

  static final DataSource instance = DataSource._();

  static const String _assetsPrefix = 'assets/euroleague/';

  // ---------------------------------------------------------------------------
  // Asset helper'ları
  // ---------------------------------------------------------------------------

  /// ScoresScreen gibi yerlerde gün listesini çekmek için public wrapper.
  Future<List<String>> listAllCsvAssets() {
    return _listAllCsvAssets();
  }

  /// AssetManifest.json içinden EuroLeague CSV dosyalarını listeler.
  Future<List<String>> _listAllCsvAssets() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    return manifestMap.keys
        .where((k) =>
            k.startsWith(_assetsPrefix) &&
            k.contains('boxscores_') &&
            k.endsWith('.csv'))
        .toList();
  }

  /// 'assets/euroleague/boxscores_2023-10-05.csv' gibi path'ten DateTime üretir.
  DateTime? _parseDateFromAsset(String path) {
    final fileName = path.split('/').last; // boxscores_2023-10-05.csv
    if (!fileName.startsWith('boxscores_')) return null;

    final datePart =
        fileName.substring('boxscores_'.length, fileName.length - '.csv'.length);

    final sep = datePart.contains('-') ? '-' : '_';
    final parts = datePart.split(sep);
    if (parts.length != 3) return null;

    try {
      int year, month, day;

      // YYYY-MM-DD mi, DD-MM-YYYY mi?
      if (parts[0].length == 4) {
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
        day = int.parse(parts[2]);
      } else {
        day = int.parse(parts[0]);
        month = int.parse(parts[1]);
        year = int.parse(parts[2]);
      }

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Verilen gün için doğru CSV dosyasını bulur.
  Future<String?> _findCsvForDay(DateTime day) async {
    final all = await _listAllCsvAssets();
    final target = DateTime(day.year, day.month, day.day);

    for (final path in all) {
      final d = _parseDateFromAsset(path);
      if (d == null) continue;
      if (d.year == target.year &&
          d.month == target.month &&
          d.day == target.day) {
        return path;
      }
    }
    return null;
  }

  /// Bir satırı, tırnak içindeki virgülleri bozmadan CSV alanlarına böler.
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];

      if (c == '"') {
        inQuotes = !inQuotes;
        buffer.write(c); // tırnağı da koruyoruz, sonra temizleriz
      } else if (c == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }

    result.add(buffer.toString());
    return result;
  }

  /// CSV dosyasını okuyup {kolonAdı: değer} map'lerinden oluşan liste döner.
  Future<List<Map<String, String>>> _loadCsvRows(String assetPath) async {
    final csv = await rootBundle.loadString(assetPath);
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return const <Map<String, String>>[];

    final headers = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];

    for (final rawLine in lines.skip(1)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final values = _parseCsvLine(line);
      final row = <String, String>{};
      final len =
          values.length < headers.length ? values.length : headers.length;

      for (var i = 0; i < len; i++) {
        row[headers[i]] = values[i];
      }

      rows.add(row);
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // Yardımcı: gerçek oyuncu mu, takım satırı mı?
  // ---------------------------------------------------------------------------

  bool _isRealPlayerId(String id) {
    // EuroLeague CSV'de oyuncular P ile başlıyor (P00xxxx),
    // IST / TEL / BAR gibi takım kodlarını elemek için kullanıyoruz.
    return id.startsWith('P');
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API – GameRepository buradaki metodları kullanıyor
  // ---------------------------------------------------------------------------

    /// Verilen gün için: {playerId -> PlayerStat}
  Future<Map<String, PlayerStat>> loadBoxscoreFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return <String, PlayerStat>{};

    final rows = await _loadCsvRows(pathForDay);
    final result = <String, PlayerStat>{};

    for (final row in rows) {
      final playerId = row['player_id'] ?? '';
      if (playerId.isEmpty) continue;
      if (!_isRealPlayerId(playerId)) continue; // takım satırlarını atla

      // 🔥 Aynı oyuncu zaten eklendiyse, tekrar ekleme (CSV’de duplicate var)
      if (result.containsKey(playerId)) continue;

      final pts = int.tryParse(row['pts'] ?? '') ?? 0;
      final ast = int.tryParse(row['ast'] ?? '') ?? 0;
      final reb = int.tryParse(row['reb'] ?? '') ?? 0;

      result[playerId] = PlayerStat(pts: pts, ast: ast, reb: reb);
    }

    return result;
  }


  /// Verilen gün için: {playerId -> Player}
  Future<Map<String, Player>> loadPlayersMapFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return <String, Player>{};

    final rows = await _loadCsvRows(pathForDay);
    final result = <String, Player>{};

    for (final row in rows) {
      final playerId = row['player_id'] ?? '';
      var name = row['player_name'] ?? '';
      if (playerId.isEmpty || name.isEmpty) continue;
      if (!_isRealPlayerId(playerId)) continue; // takım kodlarını atla

      // Baş ve sondaki tırnak/boşlukları temizle
      name = name.trim();
      if (name.startsWith('"') && name.endsWith('"') && name.length > 1) {
        name = name.substring(1, name.length - 1).trim();
      }

      // Bu CSV'de takım alanı yok gibi; yine de varsa oku:
      final team =
          row['player_team_name'] ?? row['team_name'] ?? row['team'] ?? '';

      result[playerId] = Player(id: playerId, name: name, team: team);
    }

    return result;
  }

  /// Verilen gün için maç skorları listesi.
  /// Skoru header'dan değil, oyuncu sayılarını toplayarak hesaplıyoruz.
  Future<List<MatchScore>> loadMatchScoresFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return const <MatchScore>[];

    final rows = await _loadCsvRows(pathForDay);

    // game_id -> maç bilgisi
    final byGame = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final gameId = row['game_id'] ?? '';
      if (gameId.isEmpty) continue;

      final map = byGame.putIfAbsent(gameId, () => <String, dynamic>{
            'homePts': 0,
            'awayPts': 0,
          });

      // ev / deplasman takım isimleri
      final homeName =
          row['home_team_name'] ?? row['home'] ?? row['team_a'] ?? '';
      final awayName =
          row['away_team_name'] ?? row['away'] ?? row['team_b'] ?? '';

      if (homeName.isNotEmpty) map['home'] = homeName;
      if (awayName.isNotEmpty) map['away'] = awayName;

      // CSV'de maç skorları zaten var: home_score / away_score
      final homeScoreStr = row['home_score'] ?? '';
      final awayScoreStr = row['away_score'] ?? '';

      // "96.0" gibi değerler için önce direkt parse dene, olmazsa '.' öncesini al
      final homeScore =
          int.tryParse(homeScoreStr) ??
          int.tryParse(homeScoreStr.split('.').first) ??
          0;
      final awayScore =
          int.tryParse(awayScoreStr) ??
          int.tryParse(awayScoreStr.split('.').first) ??
          0;

      // Bu satırda skor bilgisi varsa map'e yaz
      if (homeScore != 0 || awayScore != 0) {
        map['homePts'] = homeScore;
        map['awayPts'] = awayScore;
      }

      // tipoff: tarih + saat (varsa)
      if (map['tipoff'] == null) {
        final dateStr = row['game_date'];
        final timeStr = row['game_time'];

        DateTime tipoff;

        if (dateStr != null && dateStr.isNotEmpty) {
          final dParts = dateStr.split(RegExp(r'[-./]'));
          if (dParts.length == 3) {
            int year, month, dayNum;
            if (dParts[0].length == 4) {
              year = int.parse(dParts[0]);
              month = int.parse(dParts[1]);
              dayNum = int.parse(dParts[2]);
            } else {
              dayNum = int.parse(dParts[0]);
              month = int.parse(dParts[1]);
              year = int.parse(dParts[2]);
            }

            int hour = 0;
            int minute = 0;
            if (timeStr != null && timeStr.isNotEmpty) {
              final tParts = timeStr.split(':');
              if (tParts.isNotEmpty) {
                hour = int.tryParse(tParts[0]) ?? 0;
              }
              if (tParts.length > 1) {
                minute = int.tryParse(tParts[1]) ?? 0;
              }
            }

            tipoff = DateTime(year, month, dayNum, hour, minute);
          } else {
            tipoff = DateTime(day.year, day.month, day.day);
          }
        } else {
          tipoff = DateTime(day.year, day.month, day.day);
        }

        map['tipoff'] = tipoff;
      }
    }

    final list = <MatchScore>[];
    byGame.forEach((gameId, m) {
      final home = m['home'] as String? ?? '';
      final away = m['away'] as String? ?? '';
      final tipoff =
          m['tipoff'] as DateTime? ?? DateTime(day.year, day.month, day.day);
      final homePts = (m['homePts'] as int?) ?? 0;
      final awayPts = (m['awayPts'] as int?) ?? 0;

      list.add(MatchScore(
        gameId: gameId,
        home: home,
        away: away,
        tipoff: tipoff,
        homePts: homePts,
        awayPts: awayPts,
      ));
    });

    list.sort((a, b) => a.tipoff.compareTo(b.tipoff));
    return list;
  }

  /// Her maç için hangi oyuncular oynadı: {gameId -> {playerId,...}}
  Future<Map<String, Set<String>>> loadGamePlayersFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return const {};

    final rows = await _loadCsvRows(pathForDay);
    final result = <String, Set<String>>{};

    for (final row in rows) {
      final gameId = row['game_id'] ?? '';
      final playerId = row['player_id'] ?? '';
      if (gameId.isEmpty || playerId.isEmpty) continue;
      if (!_isRealPlayerId(playerId)) continue; // takım kodlarını atla

      final set = result.putIfAbsent(gameId, () => <String>{});
      set.add(playerId);
    }

    return result;
  }
}
