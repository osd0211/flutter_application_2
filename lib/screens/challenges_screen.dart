// lib/screens/challenges_screen.dart
import 'package:flutter/material.dart';
import '../models.dart';
import '../data/mock.dart';

/// Dışarıdan verilen store + onChanged ile mevcut mimarine uyuyor.
/// repo parametren varsa da aynı imzayı koruruz (kullanmasan da sorun yok).
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({
    super.key,
    required this.store,
    required this.onChanged,
    this.repo, // opsiyonel
  });

  final List<PredictionChallenge> store;
  final void Function(List<PredictionChallenge>) onChanged;
  final Object? repo;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  MatchGame? _selectedGame;
  Player? _selectedPlayer;

  final TextEditingController _pts = TextEditingController();
  final TextEditingController _ast = TextEditingController();
  final TextEditingController _reb = TextEditingController();

  List<Player> _players = const [];

  @override
  void initState() {
    super.initState();
    // Varsayılan: ilk maç, ilk oyuncu
    if (mockGamesToday.isNotEmpty) {
      _selectedGame = mockGamesToday.first;
      _players = playersForMatch(_selectedGame!.id);
      if (_players.isNotEmpty) _selectedPlayer = _players.first;
    }
  }

  @override
  void dispose() {
    _pts.dispose();
    _ast.dispose();
    _reb.dispose();
    super.dispose();
  }

  void _save() {
    if (_selectedGame == null || _selectedPlayer == null) return;

    final p = int.tryParse(_pts.text.trim()) ?? 0;
    final a = int.tryParse(_ast.text.trim()) ?? 0;
    final r = int.tryParse(_reb.text.trim()) ?? 0;

    final item = PredictionChallenge(
      id: newId(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // MAÇ SEÇİMİ
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
                  decoration: const InputDecoration(
                    labelText: 'Maç',
                    border: OutlineInputBorder(),
                  ),
                  items: mockGamesToday.map((m) {
                    final label =
                        '${m.home} – ${m.away} • ${m.statusLabel}';
                    return DropdownMenuItem(
                      value: m,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (m) {
                    setState(() {
                      _selectedGame = m;
                      _players = m == null ? [] : playersForMatch(m.id);
                      _selectedPlayer =
                          _players.isNotEmpty ? _players.first : null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // OYUNCU SEÇİMİ
                DropdownButtonFormField<Player>(
                  value: _selectedPlayer,
                  decoration: const InputDecoration(
                    labelText: 'Oyuncu',
                    border: OutlineInputBorder(),
                  ),
                  items: _players
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} • ${p.team}'),
                          ))
                      .toList(),
                  onChanged: (p) => setState(() => _selectedPlayer = p),
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
        ...widget.store.map((c) => Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(c.playerName),
                subtitle: Text(
                    'Maç: ${c.matchId} • Tahmin: ${c.points} sayı · ${c.assists} ast · ${c.rebounds} rib'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      widget.store.removeWhere((e) => e.id == c.id);
                    });
                    widget.onChanged(
                      List<PredictionChallenge>.unmodifiable(widget.store),
                    );
                  },
                ),
              ),
            )),
      ],
    );
  }
}
