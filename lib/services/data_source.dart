// lib/services/data_source.dart
// Amaç: AssetManifest içinden CSV’leri bulup,
// seçilen güne göre boxscore, oyuncu isimleri ve maç skorlarını üretmek.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models.dart';

class DataSource {
  DataSource._();
  static final instance = DataSource._();

  static const String assetsPrefix = 'assets/euroleague/';

  /// AssetManifest.json içinden `assets/euroleague/*.csv` yollarını döndürür.
  Future<List<String>> listAllCsvAssets() async {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest = json.decode(manifestJson);
    final paths = manifest.keys
        .where((k) => k.startsWith(assetsPrefix) && k.endsWith('.csv'))
        .toList()
      ..sort();
    return paths;
  }

  /// Bir CSV asset’ini okuyup {playerId -> PlayerStat} sözlüğü üretir.
  Future<Map<String, PlayerStat>> loadBoxscoreFromAssets(String assetPath) async {
    final csv = await rootBundle.loadString(assetPath);
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return <String, PlayerStat>{};

    final header = lines.first.split(',');
    final idIdx  = header.indexOf('player_id');
    final ptsIdx = header.indexOf('pts');
    final astIdx = header.indexOf('ast');
    final rebIdx = header.indexOf('reb');

    final map = <String, PlayerStat>{};
    for (int i = 1; i < lines.length; i++) {
      final row = lines[i].split(',');
      if (row.length <= rebIdx) continue;

      int parseInt(String s) => int.tryParse(s.trim()) ?? 0;

      final id = row[idIdx].trim();
      map[id] = PlayerStat(
        pts: parseInt(row[ptsIdx]),
        ast: parseInt(row[astIdx]),
        reb: parseInt(row[rebIdx]),
      );
    }
    return map;
  }

  /// Verilen gün için uygun CSV dosyasını bulup boxscore döndürür.
  Future<Map<String, PlayerStat>> loadBoxscoreFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return <String, PlayerStat>{};
    return loadBoxscoreFromAssets(pathForDay);
  }

  /// Verilen gün için {playerId -> Player} sözlüğü.
  Future<Map<String, Player>> loadPlayersMapFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return <String, Player>{};

    final csv = await rootBundle.loadString(pathForDay);
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return <String, Player>{};

    final header  = lines.first.split(',');
    final idIdx   = header.indexOf('player_id');
    final nameIdx = header.indexOf('player_name');
    final teamIdx = header.indexOf('team');

    final map = <String, Player>{};
    for (int i = 1; i < lines.length; i++) {
      final row = lines[i].split(',');
      if (row.length <= teamIdx) continue;
      final id   = row[idIdx].trim();
      final name = row[nameIdx].trim();
      final team = row[teamIdx].trim();
      map[id] = Player(id: id, name: name, team: team);
    }
    return map;
  }

  /// Verilen gün için maç skorlarını üretir (game_id bazında toplar).
  Future<List<MatchScore>> loadMatchScoresFor(DateTime day) async {
    final pathForDay = await _findCsvForDay(day);
    if (pathForDay == null) return const <MatchScore>[];

    final csv = await rootBundle.loadString(pathForDay);
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return const <MatchScore>[];

    final header  = lines.first.split(',');
    final gameIdx = header.indexOf('game_id');
    final homeIdx = header.indexOf('home');
    final awayIdx = header.indexOf('away');
    final tipIdx  = header.indexOf('tipoff_utc');
    final teamIdx = header.indexOf('team');
    final ptsIdx  = header.indexOf('pts');

    // game_id -> {meta, homePts, awayPts}
    final tmp = <String, Map<String, dynamic>>{};
    for (int i = 1; i < lines.length; i++) {
      final row = lines[i].split(',');
      if (row.length <= ptsIdx) continue;

      final gid  = row[gameIdx].trim();
      final home = row[homeIdx].trim();
      final away = row[awayIdx].trim();
      final tip  = DateTime.parse(row[tipIdx].trim());
      final team = row[teamIdx].trim();
      final pts  = int.tryParse(row[ptsIdx].trim()) ?? 0;

      final m = tmp.putIfAbsent(gid, () => {
            'home': home,
            'away': away,
            'tip': tip,
            'homePts': 0,
            'awayPts': 0,
          });

      if (team == home) {
        m['homePts'] = (m['homePts'] as int) + pts;
      } else if (team == away) {
        m['awayPts'] = (m['awayPts'] as int) + pts;
      }
    }

    final list = tmp.entries.map((e) {
      final v = e.value;
      return MatchScore(
        gameId: e.key,
        home: v['home'] as String,
        away: v['away'] as String,
        tipoff: v['tip'] as DateTime,
        homePts: v['homePts'] as int,
        awayPts: v['awayPts'] as int,
      );
    }).toList()
      ..sort((a, b) => a.tipoff.compareTo(b.tipoff));

    return list;
  }

  /// İstenen gün için `assets/euroleague/boxscores_YYYY_MM_DD.csv` dosyasını bulur.
  Future<String?> _findCsvForDay(DateTime day) async {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    final targetSuffix = 'boxscores_${y}_${m}_$d.csv';

    final all = await listAllCsvAssets();
    try {
      return all.firstWhere((p) => p.endsWith(targetSuffix));
    } catch (_) {
      return null;
    }
  }
}
