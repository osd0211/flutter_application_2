// lib/screens/challenges_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/mock.dart';
import '../models.dart';
import '../ui/app_theme.dart';

class ChallengesScreen extends StatefulWidget {
  final List<PredictionChallenge> store;
  final void Function(List<PredictionChallenge>)? onChanged;

  const ChallengesScreen({
    super.key,
    required this.store,
    this.onChanged,
  });

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  MatchGame? _selectedGame;
  Player? _selectedPlayer;

  final _ptsCtrl = TextEditingController();
  final _astCtrl = TextEditingController();
  final _rebCtrl = TextEditingController();

  // Tek dialog ile 3 istatistiği birden al
  Future<void> _openPredictionDialog() async {
    if (_selectedGame == null || _selectedPlayer == null) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_selectedPlayer!.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NumberField(ctrl: _ptsCtrl, label: 'Sayı'),
            const SizedBox(height: 8),
            _NumberField(ctrl: _astCtrl, label: 'Asist'),
            const SizedBox(height: 8),
            _NumberField(ctrl: _rebCtrl, label: 'Ribaund'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(_ptsCtrl.text) ?? 0;
              final a = int.tryParse(_astCtrl.text) ?? 0;
              final r = int.tryParse(_rebCtrl.text) ?? 0;

              final ch = PredictionChallenge(
                id: const Uuid().v4(),
                matchId: _selectedGame!.id,
                playerId: _selectedPlayer!.id,
                playerName: _selectedPlayer!.name,
                points: p,
                assists: a,
                rebounds: r,
                createdAt: DateTime.now(),
              );

              widget.store.add(ch);
              mockChallenges.add(ch); // mock deposuna da yaz
              widget.onChanged?.call(List.unmodifiable(widget.store));

              _ptsCtrl.clear();
              _astCtrl.clear();
              _rebCtrl.clear();

              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1) Maç seçimi
        Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Maç Seç', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<MatchGame>(
                value: _selectedGame,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.sports_basketball)),
                items: mockGames
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text('${g.homeTeam} vs ${g.awayTeam}  (${g.homeScore}-${g.awayScore})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedGame = v;
                  _selectedPlayer = null;
                }),
              ),
              const SizedBox(height: 12),

              // 2) Oyuncu seçimi (seçilen maça göre filtreli)
              DropdownButtonFormField<Player>(
                value: _selectedPlayer,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.person)),
                items: (_selectedGame?.roster ?? [])
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (p) => setState(() => _selectedPlayer = p),
              ),
              const SizedBox(height: 12),

              // 3) Tek tuşla 3 istatistik dialogu
              FilledButton.icon(
                onPressed: (_selectedGame != null && _selectedPlayer != null)
                    ? _openPredictionDialog
                    : null,
                icon: const Icon(Icons.edit),
                label: const Text('Tahmini Gir'),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // Girilen tahminler listesi
        ...widget.store.map((c) => Card(
              color: AppColors.surface,
              child: ListTile(
                leading: const Icon(Icons.timeline, color: AppColors.yellow),
                title: Text(c.playerName),
                subtitle: Text('Sayı ${c.points} • Ast ${c.assists} • Rib ${c.rebounds}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    widget.store.removeWhere((x) => x.id == c.id);
                    mockChallenges.removeWhere((x) => x.id == c.id);
                    widget.onChanged?.call(List.unmodifiable(widget.store));
                    setState(() {});
                  },
                ),
              ),
            )),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _NumberField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
