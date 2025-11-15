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


    /// ScoresScreen gibi yerlerde gün listesini çekmek için public wrapper.
  Future<List<String>> listAllCsvAssets() {
    return _listAllCsvAssets();
  }

  // ---------------------------------------------------------------------------
  // Asset helper'ları
  // ---------------------------------------------------------------------------

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

  /// CSV dosyasını okuyup {kolonAdı: değer} map'lerinden oluşan liste döner.
  Future<List<Map<String, String>>> _loadCsvRows(String assetPath) async {
    final csv = await rootBundle.loadString(assetPath);
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return const <Map<String, String>>[];

    final headers = lines.first.split(',');
    final rows = <Map<String, String>>[];

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;

      final values = line.split(',');
      final row = <String, String>{};
      final len = values.length < headers.length ? values.length : headers.length;

      for (var i = 0; i < len; i++) {
        row[headers[i]] = values[i];
      }

      rows.add(row);
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API – GameRepository buradaki 3 metodu kullanıyor
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

  // Baş ve sondaki tırnak/boşlukları temizle
  name = name.trim();
  if (name.startsWith('"') && name.endsWith('"') && name.length > 1) {
    name = name.substring(1, name.length - 1).trim();
  }

  final team =
      row['player_team_name'] ?? row['team_name'] ?? row['team'] ?? '';

  result[playerId] = Player(id: playerId, name: name, team: team);
}


    return result;
  }

  /// Verilen gün için maç skorları listesi.
  Future<List<MatchScore>> loadMatchScoresFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return const <MatchScore>[];

    final rows = await _loadCsvRows(pathForDay);

    // game_id -> maç bilgisi
    final byGame = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final gameId = row['game_id'] ?? '';
      if (gameId.isEmpty) continue;

      final map = byGame.putIfAbsent(gameId, () => <String, dynamic>{});

      // ev / deplasman takım isimleri
      map['home'] ??=
          row['home_team_name'] ?? row['home'] ?? row['team_a'] ?? '';
      map['away'] ??=
          row['away_team_name'] ?? row['away'] ?? row['team_b'] ?? '';

      // skorlar
      final homeScoreStr = row['home_score'] ?? row['score_a'];
      final awayScoreStr = row['away_score'] ?? row['score_b'];

      if (homeScoreStr != null && homeScoreStr.isNotEmpty) {
        map['homePts'] = int.tryParse(homeScoreStr) ?? map['homePts'] ?? 0;
      }
      if (awayScoreStr != null && awayScoreStr.isNotEmpty) {
        map['awayPts'] = int.tryParse(awayScoreStr) ?? map['awayPts'] ?? 0;
      }

      // tipoff: tarih + saat
      if (map['tipoff'] == null) {
        final dateStr = row['game_date'];
        final timeStr = row['game_time'];

        DateTime tipoff;

        if (dateStr != null && dateStr.isNotEmpty) {
          // tarih parçala (YYYY-MM-DD ya da DD-MM-YYYY)
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

            // saat parçala
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
}
