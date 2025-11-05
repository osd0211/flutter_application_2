// lib/services/data_source.dart
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models.dart';

abstract class DataSource {
  Future<List<MatchGame>> loadMatchesForDate(DateTime date);
  Future<Map<String, PlayerStat>> loadBoxScoreForGame(String gameId, DateTime date);
}

class CsvDataSource implements DataSource {
  final String folder; // assets/euroleague
  CsvDataSource({this.folder = 'assets/euroleague'});

  List<Map<String, String>> _parseCsv(String raw) {
    final lines = const LineSplitter().convert(raw)
        .where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final headers = lines.first.split(',').map((e)=>e.trim()).toList();

    return lines.skip(1).map((line) {
      final cols = line.split(','); // basit parser (virgüllü metin yok varsayımı)
      return {
        for (int i = 0; i < headers.length && i < cols.length; i++)
          headers[i]: cols[i].trim(),
      };
    }).toList();
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}_${d.month.toString().padLeft(2,'0')}_${d.day.toString().padLeft(2,'0')}';

  Future<List<Map<String,String>>> _readDay(DateTime date) async {
    final path = '$folder/boxscores_${_dayKey(date)}.csv';
    final csv = await rootBundle.loadString(path);
    final rows = _parseCsv(csv);
    final y = date.year, m = date.month.toString().padLeft(2,'0'), d = date.day.toString().padLeft(2,'0');
    return rows.where((r) => (r['date'] ?? '').startsWith('$y-$m-$d')).toList();
  }

  @override
  Future<List<MatchGame>> loadMatchesForDate(DateTime date) async {
    final rows = await _readDay(date);
    final byGame = <String, List<Map<String,String>>>{};
    for (final r in rows) {
      final gid = r['game_id']!;
      byGame.putIfAbsent(gid, () => <Map<String,String>>[]).add(r);
    }

    final matches = <MatchGame>[];
    for (final e in byGame.entries) {
      final first = e.value.first;
      final tipoffUtc = DateTime.parse(first['tipoff_utc']!);
      final roster = e.value.map((r) => Player(
        id: r['player_id']!,
        name: r['player_name']!,
        team: r['team']!,
      )).toList();

      matches.add(MatchGame(
        id: e.key,
        home: first['home']!,
        away: first['away']!,
        tipoff: tipoffUtc.toLocal(),
        live: false,
        finished: true, // geçmiş gün için
        roster: roster,
      ));
    }
    return matches;
  }

  @override
  Future<Map<String, PlayerStat>> loadBoxScoreForGame(String gameId, DateTime date) async {
    final rows = await _readDay(date);
    final gameRows = rows.where((r) => r['game_id'] == gameId);
    final out = <String, PlayerStat>{};
    for (final r in gameRows) {
      out[r['player_id']!] = PlayerStat(
        pts: int.tryParse(r['pts'] ?? '') ?? 0,
        ast: int.tryParse(r['ast'] ?? '') ?? 0,
        reb: int.tryParse(r['reb'] ?? '') ?? 0,
      );
    }
    return out;
  }
}
