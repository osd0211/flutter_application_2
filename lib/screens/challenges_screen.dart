import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../ui/app_theme.dart';
import '../models.dart';
import '../data/mock.dart';

final _uuid = const Uuid();

/// Puan çarpanları
const Map<StatType, double> kKatsayi = {
  StatType.pts: 1.00,
  StatType.reb: 1.20,
  StatType.ast: 1.10,
};

/// Puan bantları (record kullanıyoruz; Dart 3+)
const List<(int farkEsigi, int puan)> kBantlar = [
  (0, 50),
  (1, 40),
  (2, 30),
  (3, 20),
  (5, 10),
  (999, 0),
];

/// Tüm istatistikler ≤1 fark ise bonus
const int kKombinBonus = 20;

class ChallengesScreen extends StatefulWidget {
  final ValueNotifier<List<PredictionChallenge>> store;
  const ChallengesScreen({super.key, required this.store});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final List<PredictionChallenge> challenges = [];

  Match? _selectedMatch;
  Player? _selectedPlayer;

  final _ptsCtrl = TextEditingController(text: '20');
  final _rebCtrl = TextEditingController(text: '6');
  final _astCtrl = TextEditingController(text: '4');

  @override
  void dispose() {
    _ptsCtrl.dispose();
    _rebCtrl.dispose();
    _astCtrl.dispose();
    super.dispose();
  }

  // Tek stat puanlama
  int _puanla({
    required int gercek,
    required int tahmin,
    required StatType stat,
  }) {
    final fark = (gercek - tahmin).abs();
    int temel = 0;
    for (final b in kBantlar) {
      if (fark <= b.$1) {
        temel = b.$2;
        break;
      }
    }
    return (temel * kKatsayi[stat]!).round();
  }

  // Kombin puanı (bonus dahil)
  int _kombinPuan(Map<StatType, int> predictions, Player p) {
    final gercek = <StatType, int>{
      StatType.pts: p.pts.round(),
      StatType.reb: p.reb.round(),
      StatType.ast: p.ast.round(),
    };

    int toplam = 0;
    bool hepsiBirIcinde = true;

    for (final entry in predictions.entries) {
      final stat = entry.key;
      final th = entry.value;
      final gr = gercek[stat]!;
      toplam += _puanla(gercek: gr, tahmin: th, stat: stat);
      if ((gr - th).abs() > 1) hepsiBirIcinde = false;
    }

    if (hepsiBirIcinde) toplam += kKombinBonus;
    return toplam;
  }

  void _openCreateSheet() {
    _selectedMatch ??= mockMatches.first;
    _selectedPlayer ??= _selectedMatch!.roster.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, inset + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kombine Tahmin (PTS • REB • AST)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.yellow,
                  ),
                ),
                SizedBox(height: 12),

                // Maç seçimi
                DropdownButtonFormField<Match>(
                  initialValue: _selectedMatch,
                  decoration: const InputDecoration(
                    labelText: 'Maç',
                    prefixIcon: Icon(Icons.sports_basketball),
                  ),
                  items: mockMatches
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text('${m.home} vs ${m.away}  •  ${m.tipoff}'),
                          ))
                      .toList(),
                  onChanged: (m) {
                    setState(() {
                      _selectedMatch = m;
                      _selectedPlayer = m?.roster.first;
                    });
                    Navigator.pop(ctx);
                    _openCreateSheet();
                  },
                ),
                SizedBox(height: 12),

                // Oyuncu seçimi
                DropdownButtonFormField<Player>(
                  initialValue: _selectedPlayer,
                  decoration: const InputDecoration(
                    labelText: 'Oyuncu',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: (_selectedMatch?.roster ?? [])
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name}  •  ${p.team}'),
                          ))
                      .toList(),
                  onChanged: (p) => setState(() => _selectedPlayer = p),
                ),
                SizedBox(height: 12),

                // 3 istatistik – aynı anda gir
                _StatRowInt(label: 'PTS', controller: _ptsCtrl, color: AppColors.orange),
                SizedBox(height: 8),
                _StatRowInt(label: 'REB', controller: _rebCtrl, color: Colors.lightBlueAccent),
                SizedBox(height: 8),
                _StatRowInt(label: 'AST', controller: _astCtrl, color: AppColors.yellow),
                SizedBox(height: 16),

                // Kaydet
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Tahmini Kaydet'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      if (_selectedMatch == null || _selectedPlayer == null) return;

                      final preds = <StatType, int>{
                        StatType.pts: int.tryParse(_ptsCtrl.text.trim()) ?? 0,
                        StatType.reb: int.tryParse(_rebCtrl.text.trim()) ?? 0,
                        StatType.ast: int.tryParse(_astCtrl.text.trim()) ?? 0,
                      };

                      final c = PredictionChallenge(
                        id: _uuid.v4(),
                        matchId: _selectedMatch!.id,
                        playerName: _selectedPlayer!.name,
                        team: _selectedPlayer!.team,
                        predictions: preds,
                      );

                      c.points = _kombinPuan(preds, _selectedPlayer!);
                      c.status = c.points > 0 ? ChallengeStatus.won : ChallengeStatus.lost;

                      setState(() => challenges.insert(0, c));
                      widget.store.value = List<PredictionChallenge>.from(challenges);

                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tahminler')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.black,
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Tahmin'),
      ),
      body: challenges.isEmpty
          ? const Center(
              child: Text(
                'Henüz tahmin yok.\n“Yeni Tahmin” ile oluştur.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: challenges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final c = challenges[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: .25),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.playerName} • ${c.team}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _pill('PTS: ${c.predictions[StatType.pts]}'),
                          _pill('REB: ${c.predictions[StatType.reb]}'),
                          _pill('AST: ${c.predictions[StatType.ast]}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.bolt, size: 18, color: AppColors.yellow),
                          const SizedBox(width: 8),
                          Text('+${c.points} puan',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => challenges.removeAt(i));
                              widget.store.value =
                                  List<PredictionChallenge>.from(challenges);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Sil'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orange.withValues(alpha: .3)),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

/// Tek satır tam sayı alanı + stepper
class _StatRowInt extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;

  const _StatRowInt({
    required this.label,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    void change(int delta) {
      final v = int.tryParse(controller.text.trim()) ?? 0;
      controller.text = (v + delta).clamp(0, 200).toString();
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tahmin (tam sayı)'),
          ),
        ),
        const SizedBox(width: 12),
        _stepBtn(Icons.remove, () => change(-1), color),
        const SizedBox(width: 8),
        _stepBtn(Icons.add, () => change(1), color),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap, Color color) {
    return SizedBox(
      width: 38,
      height: 38,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: color.withValues(alpha: .45)),
          foregroundColor: color,
        ),
        onPressed: onTap,
        child: Icon(icon, size: 18),
      ),
    );
  }
}
