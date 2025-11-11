// lib/services/data_source.dart
// Amaç: AssetManifest içinden tüm CSV'leri listele, tarihleri çıkar,
// seçilen CSV'yi yükle ve box-score'a çevir.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models.dart';

class DataSource {
  DataSource._();
  static final instance = DataSource._();

  static const String assetsPrefix = 'assets/euroleague/';

  /// AssetManifest.json içinden `assets/euroleague/*.csv` yollarını bulur.
  Future<List<String>> listAllCsvAssets() async {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final map = jsonDecode(manifestJson) as Map<String, dynamic>;

    final paths = map.keys
        .where((p) => p.startsWith(assetsPrefix) && p.toLowerCase().endsWith('.csv'))
        .toList();

    // kronolojik sıraya sokmak genelde işimize yarar
    paths.sort();
    return paths;
  }

  /// Yoldan YYYY_MM_DD veya YYYY-MM-DD tarihini yakalar.
  static DateTime? extractDateFromPath(String path) {
    final m = RegExp(r'(\d{4})[_-](\d{2})[_-](\d{2})').firstMatch(path);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    return DateTime(y, mo, d);
  }

  /// Bir CSV asset'i yükler ve {playerId -> PlayerStat} map'ine çevirir.
  Future<Map<String, PlayerStat>> loadBoxscoreFromAssets(String assetPath) async {
    final csv = await rootBundle.loadString(assetPath);
    return parseBoxscoreCsv(csv);
  }

  /// Basit CSV parser:
  /// Header satırı bekler. player_id, pts, ast, reb alanları zorunlu.
  /// Örnek header: player_id,player_name,team,pts,ast,reb
  Map<String, PlayerStat> parseBoxscoreCsv(String csv) {
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return const {};

    final header = lines.first.split(',').map((e) => e.trim().toLowerCase()).toList();

    int idx(String name) => header.indexWhere((h) => h == name);

    final pidIdx = idx('player_id');
    final ptsIdx = idx('pts');
    final astIdx = idx('ast');
    final rebIdx = idx('reb');

    if (pidIdx < 0 || ptsIdx < 0 || astIdx < 0 || rebIdx < 0) {
      // minimum kolonlar yoksa boş dön
      return const {};
    }

    final Map<String, PlayerStat> map = {};
    for (var i = 1; i < lines.length; i++) {
      final row = lines[i].split(',');
      if (row.length <= rebIdx) continue;

      final id = row[pidIdx].trim();
      if (id.isEmpty) continue;

      int parseInt(String s) {
        return int.tryParse(s.trim()) ?? 0;
      }

      final stat = PlayerStat(
        pts: parseInt(row[ptsIdx]),
        ast: parseInt(row[astIdx]),
        reb: parseInt(row[rebIdx]),
      );
      map[id] = stat;
    }
    return map;
  }
}
