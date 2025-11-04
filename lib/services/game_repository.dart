import 'package:supabase_flutter/supabase_flutter.dart';

class GameDto {
  GameDto({required this.id, required this.home, required this.away, required this.tipoff, required this.status});
  final String id;
  final String home;
  final String away;
  final DateTime tipoff;
  final String status;
}

class GameRepository {
  final _db = Supabase.instance.client;

  Future<List<GameDto>> fetchGames() async {
    final res = await _db
        .from('games')
        .select('id, tipoff, status, home:home_id(name,short), away:away_id(name,short)')
        .order('tipoff');
    return res.map<GameDto>((row) {
      final home = row['home']['name'];
      final away = row['away']['name'];
      return GameDto(
        id: row['id'],
        home: home,
        away: away,
        tipoff: DateTime.parse(row['tipoff']),
        status: row['status'],
      );
    }).toList();
  }
}
