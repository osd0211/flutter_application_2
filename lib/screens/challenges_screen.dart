// lib/screens/challenges_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/game_repository.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({
    super.key,
    required this.store,
    required this.onChanged,
    this.repo,
  });

  final List<PredictionChallenge> store;
  final void Function(List<PredictionChallenge>) onChanged;

  final Object? repo;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<MatchGame> _games = [];
  MatchGame? _selectedGame;

  List<Player> _players = const [];
  Player? _selectedPlayer;

  final TextEditingController _pts = TextEditingController();
  final TextEditingController _ast = TextEditingController();
  final TextEditingController _reb = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = context.read<GameRepository>();
      _reloadFromGameRepository();
      repo.addListener(_reloadFromGameRepository);
    });
  }

  @override
  void dispose() {
    final repo = context.read<GameRepository>();
    repo.removeListener(_reloadFromGameRepository);

    _pts.dispose();
    _ast.dispose();
    _reb.dispose();
    super.dispose();
  }

  void _reloadFromGameRepository() async {
    if (!mounted) return;

    final repo = context.read<GameRepository>();
    final matchScores = repo.matchScoresForSelected();

    if (matchScores.isEmpty) {
      setState(() {
        _games = [];
        _selectedGame = null;
        _players = const [];
        _selectedPlayer = null;
      });
      widget.onChanged(const []);
      return;
    }

    final phase = repo.simulationPhase;
    final bool isLive = false;
    final bool isFinished = phase == SimulationPhase.finished;

    final List<MatchGame> games = [];

    for (final ms in matchScores) {
      final roster = repo.playersForGame(ms.gameId);

      games.add(
        MatchGame(
          id: ms.gameId,
          home: ms.home,
          away: ms.away,
          tipoff: ms.tipoff,
          live: isLive,
          finished: isFinished,
          roster: roster,
        ),
      );
    }

    games.sort((a, b) => a.tipoff.compareTo(b.tipoff));

    MatchGame initialGame;
    if (_selectedGame != null) {
      final found = games.where((g) => g.id == _selectedGame!.id);
      initialGame = found.isNotEmpty ? found.first : games.first;
    } else {
      initialGame = games.first;
    }

    final initialPlayers = initialGame.roster;

    if (!mounted) return;
    setState(() {
      _games = games;
      _selectedGame = initialGame;
      _players = initialPlayers;
      _selectedPlayer = _players.isNotEmpty ? _players.first : null;
    });

    await _loadPredictionsForCurrentUserAndDay();
  }

  Future<void> _loadPredictionsForCurrentUserAndDay() async {
    if (!mounted) return;

    final auth = context.read<IAuthService>();
    final userId = auth.currentUserId;
    if (userId == null) return;

    if (_games.isEmpty) {
      widget.onChanged(const []);
      return;
    }

    final gameIds = _games.map((g) => g.id).toSet();
    final rows = await DatabaseService.loadPredictionsForUser(userId);

    final List<PredictionChallenge> list = [];

    for (final row in rows) {
      final matchId = row['match_id'] as String;
      if (!gameIds.contains(matchId)) continue;

      final playerId = row['player_id'] as String;
      final challengeId = row['challenge_id'] as String;
      final predPts = (row['pred_pts'] as num).toInt();
      final predAst = (row['pred_ast'] as num).toInt();
      final predReb = (row['pred_reb'] as num).toInt();

      final createdAtStr = row['created_at'] as String;
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {
        createdAt = DateTime.now();
      }

      Player player;
      try {
        final game = _games.firstWhere(
          (g) => g.id == matchId,
          orElse: () => _games.first,
        );
        player = game.roster.firstWhere(
          (p) => p.id == playerId,
          orElse: () => Player(
            id: playerId,
            name: 'Player $playerId',
            team: 'Unknown',
          ),
        );
      } catch (_) {
        player = Player(
          id: playerId,
          name: 'Player $playerId',
          team: 'Unknown',
        );
      }

      list.add(
        PredictionChallenge(
          id: challengeId,
          matchId: matchId,
          playerId: playerId,
          playerName: player.name,
          points: predPts,
          assists: predAst,
          rebounds: predReb,
          createdAt: createdAt,
        ),
      );
    }

    if (!mounted) return;

    widget.store
      ..clear()
      ..addAll(list);

    widget.onChanged(List<PredictionChallenge>.unmodifiable(widget.store));
    setState(() {});
  }

  void _onSelectGame(MatchGame? m) {
    setState(() {
      _selectedGame = m;
      _players = m == null ? const [] : m.roster;
      _selectedPlayer = _players.isNotEmpty ? _players.first : null;
    });
  }

  void _onSelectPlayer(Player? p) {
    setState(() {
      _selectedPlayer = p;
    });
  }

  Future<void> _save() async {
    if (_selectedGame == null || _selectedPlayer == null) return;

    final repo = context.read<GameRepository>();
    final phase = repo.simulationPhase;

    if (phase == SimulationPhase.finished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maç bittikten sonra tahmin yapılamaz.')),
      );
      return;
    }

    final auth = context.read<IAuthService>();
    final userId = auth.currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahmin yapmak için giriş yapmalısınız.')),
      );
      return;
    }

    // ✅ Günlük limit: base 5 + her 5 level +1
    final userRow = await DatabaseService.getUserById(userId);
    final int level = ((userRow?['level'] as int?) ?? 1);
    final int dailyLimit = DatabaseService.totalPredictionLimit(level);

    if (widget.store.length >= dailyLimit) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Limit Aşıldı'),
          content: Text(
            'Bugün en fazla $dailyLimit tahmin yapabilirsin. (Level: $level)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final p = int.tryParse(_pts.text.trim()) ?? 0;
    final a = int.tryParse(_ast.text.trim()) ?? 0;
    final r = int.tryParse(_reb.text.trim()) ?? 0;

    final challengeId = '${_selectedGame!.id}_${_selectedPlayer!.id}';

    final item = PredictionChallenge(
      id: challengeId,
      matchId: _selectedGame!.id,
      playerId: _selectedPlayer!.id,
      playerName: _selectedPlayer!.name,
      points: p,
      assists: a,
      rebounds: r,
      createdAt: DateTime.now(),
    );

    // ✅ Yeni mi update mi?
    final existingIndex = widget.store.indexWhere((e) => e.id == item.id);
    final bool isNewPrediction = existingIndex < 0;

    await DatabaseService.upsertPrediction(
      userId: userId,
      matchId: item.matchId,
      playerId: item.playerId,
      challengeId: item.id,
      predPts: item.points,
      predAst: item.assists,
      predReb: item.rebounds,
    );

    // ✅ XP sadece ilk kez tahmin girince (+20)
    if (isNewPrediction) {
      await DatabaseService.addXp(userId: userId, gainedXp: 20);
       // ✅ NEW: first_prediction + day_5_predictions badge check
      await DatabaseService.onNewPredictionCreated(userId);
    }

    setState(() {
      if (existingIndex >= 0) {
        widget.store[existingIndex] = item;
      } else {
        widget.store.add(item);
      }
    });
    widget.onChanged(List<PredictionChallenge>.unmodifiable(widget.store));

    _pts.clear();
    _ast.clear();
    _reb.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNewPrediction ? 'Tahmin kaydedildi. ' : 'Tahmin güncellendi.',
        ),
      ),
    );
  }

  Future<void> _remove(PredictionChallenge c) async {
    final auth = context.read<IAuthService>();
    final userId = auth.currentUserId;

    if (userId != null) {
      final db = await DatabaseService.database;
      await db.delete(
        'predictions',
        where: 'user_id = ? AND challenge_id = ?',
        whereArgs: [userId, c.id],
      );
    }

    setState(() {
      widget.store.removeWhere((e) => e.id == c.id);
    });
    widget.onChanged(List<PredictionChallenge>.unmodifiable(widget.store));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<GameRepository>();
    final phase = repo.simulationPhase;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Günün Maçı', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<MatchGame>(
                  value: _selectedGame,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Maç',
                    border: OutlineInputBorder(),
                  ),
                  items: _games
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            '${m.home} – ${m.away} • ${m.statusLabel}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onSelectGame,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Player>(
                  value: _selectedPlayer,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Oyuncu',
                    border: OutlineInputBorder(),
                  ),
                  items: _players
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onSelectPlayer,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pts,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sayı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _ast,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Asist',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _reb,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ribaund',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: phase == SimulationPhase.finished ? null : _save,
                    child: const Text('Tahmini Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Tahminlerim', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.store.isEmpty)
          const Text('Henüz tahmin yok.', style: TextStyle(color: Colors.white70))
        else
          ...widget.store.map(
            (c) => Card(
              child: ListTile(
                title: Text(
                  c.playerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Maç: ${c.matchId} • Tahmin: '
                  '${c.points} sayı · ${c.assists} ast · ${c.rebounds} rib',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(c),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
