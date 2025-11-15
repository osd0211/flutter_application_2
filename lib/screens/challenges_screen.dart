// lib/screens/challenges_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/game_repository.dart';

enum SimulationPhase { preGame, inGame, finished }

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({
    super.key,
    required this.store,
    required this.onChanged,
    this.repo, // opsiyonel, dokunmadım
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

  SimulationPhase _phase = SimulationPhase.preGame;

  @override
  void initState() {
    super.initState();
    // GameRepository context'e bind olduktan sonra veriyi çekelim
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadFromGameRepository();
    });
  }

  @override
  void dispose() {
    _pts.dispose();
    _ast.dispose();
    _reb.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // GameRepository'den gerçek maç + oyuncu verisini çek
  // ---------------------------------------------------------------------------
  void _reloadFromGameRepository() {
    final repo = context.read<GameRepository>();

    final matchScores = repo.matchScoresForSelected();
    final playersMap = repo.playersForSelected();

    if (matchScores.isEmpty || playersMap.isEmpty) {
      setState(() {
        _games = [];
        _selectedGame = null;
        _players = const [];
        _selectedPlayer = null;
      });
      return;
    }

    bool isLive;
    bool isFinished;

    switch (_phase) {
      case SimulationPhase.preGame:
        isLive = false;
        isFinished = false;
        break;
      case SimulationPhase.inGame:
        isLive = true;
        isFinished = false;
        break;
      case SimulationPhase.finished:
        isLive = false;
        isFinished = true;
        break;
    }

    final List<MatchGame> games = [];

    for (final ms in matchScores) {
      // Bu maçta oynayan oyuncular: takımı ev veya deplasman olanlar
      final roster = playersMap.values
          .where((p) => p.team == ms.home || p.team == ms.away)
          .toList();

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

    setState(() {
      _games = games;
      _selectedGame = games.isNotEmpty ? games.first : null;
      _players = _selectedGame?.roster ?? const [];
      _selectedPlayer = _players.isNotEmpty ? _players.first : null;
    });
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

  // ---------------------------------------------------------------------------
  // Tahmin kaydet / sil (store + onChanged mimarini koruyorum)
  // ---------------------------------------------------------------------------
  void _save() {
    if (_selectedGame == null || _selectedPlayer == null) return;

    final p = int.tryParse(_pts.text.trim()) ?? 0;
    final a = int.tryParse(_ast.text.trim()) ?? 0;
    final r = int.tryParse(_reb.text.trim()) ?? 0;

 final item = PredictionChallenge(
  // Basit unique id: zaman damgası
  id: DateTime.now().microsecondsSinceEpoch.toString(),
  matchId: _selectedGame!.id,
  playerId: _selectedPlayer!.id,
  playerName: _selectedPlayer!.name,
  points: p,
  assists: a,
  rebounds: r,
  createdAt: DateTime.now(),
);

    setState(() {
      widget.store.add(item);
    });
    widget.onChanged(List<PredictionChallenge>.unmodifiable(widget.store));

    _pts.clear();
    _ast.clear();
    _reb.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tahmin kaydedildi')),
    );
  }

  void _remove(PredictionChallenge c) {
    setState(() {
      widget.store.removeWhere((e) => e.id == c.id);
    });
    widget.onChanged(List<PredictionChallenge>.unmodifiable(widget.store));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Simülasyon aşaması toggle
        Text('Simülasyon Aşaması', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ToggleButtons(
          borderRadius: BorderRadius.circular(12),
          isSelected: [
            _phase == SimulationPhase.preGame,
            _phase == SimulationPhase.inGame,
            _phase == SimulationPhase.finished,
          ],
          onPressed: (index) {
            setState(() {
              _phase = SimulationPhase.values[index];
            });
            _reloadFromGameRepository(); // live/finished flaglerini güncelle
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Maç Öncesi'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Maç İçi'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Maç Bitti'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // MAÇ / OYUNCU SEÇİMİ + INPUT
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Günün Maçı', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),

                // Maç seçimi
                DropdownButtonFormField<MatchGame>(
                  value: _selectedGame,
                  decoration: const InputDecoration(
                    labelText: 'Maç',
                    border: OutlineInputBorder(),
                  ),
                  items: _games
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text('${m.home} – ${m.away} • ${m.statusLabel}'),
                        ),
                      )
                      .toList(),
                  onChanged: _onSelectGame,
                ),
                const SizedBox(height: 16),

                // Oyuncu seçimi
                DropdownButtonFormField<Player>(
                  value: _selectedPlayer,
                  decoration: const InputDecoration(
                    labelText: 'Oyuncu',
                    border: OutlineInputBorder(),
                  ),
                  items: _players
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} • ${p.team}'),
                        ),
                      )
                      .toList(),
                  onChanged: _onSelectPlayer,
                ),
                const SizedBox(height: 16),

                // 3 input tek seferde
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
                    onPressed: _save,
                    child: const Text('Tahmini Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // KAYITLI TAHMİNLER
        ...widget.store.map(
          (c) => Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(c.playerName),
              subtitle: Text(
                'Maç: ${c.matchId} • Tahmin: ${c.points} sayı · ${c.assists} ast · ${c.rebounds} rib',
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
