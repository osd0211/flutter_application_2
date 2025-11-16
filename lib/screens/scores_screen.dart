// lib/screens/scores_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_repository.dart';
import '../services/data_source.dart';
import '../ui/app_theme.dart';
import '../models.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  bool _loading = true;
  List<DateTime> _days = <DateTime>[];

  @override
  void initState() {
    super.initState();
    _loadDays(); // sadece gün listesini getir, seçim YOK
  }

  Future<void> _loadDays() async {
    final assets = await DataSource.instance.listAllCsvAssets();
    final re = RegExp(r'boxscores_(\d{4})[-_](\d{2})[-_](\d{2})\.csv$');
    final parsed = <DateTime>[];
    for (final p in assets) {
      final m = re.firstMatch(p);
      if (m == null) continue;
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      parsed.add(DateTime(y, mo, d));
    }
    parsed.sort(); // eski-yeni sıralı dursun
    if (!mounted) return;
    setState(() {
      _days = parsed;
      _loading = false;
    });
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GameRepository>();
    final selected = repo.selectedDay;
    final phase = repo.simulationPhase;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    // Henüz gün seçilmemişse, kullanıcıdan seçmesini iste
    if (selected == null) {
      if (_days.isEmpty) {
        return const Center(
          child: Text(
            'Hiç CSV bulunamadı',
            style: TextStyle(color: Colors.white70),
          ),
        );
      }
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2340),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gün Seçin',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButton<DateTime>(
                dropdownColor: const Color(0xFF0B1A2E),
                value: null,
                hint: const Text(
                  'Tarih seç',
                  style: TextStyle(color: Colors.white70),
                ),
                items: _days
                    .map(
                      (d) => DropdownMenuItem<DateTime>(
                        value: d,
                        child: Text(
                          _fmt(d),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (d) async {
                  if (d == null) return;
                  await context.read<GameRepository>().selectDay(d);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Not: Geçen sezon verileri ekledikçe buradan seçim yapacaksınız.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Gün seçiliyse maçları göster
    final matches = repo.matchScoresForSelected();
    if (matches.isEmpty) {
      return const Center(
        child: Text(
          'Bu gün için maç bulunamadı',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      children: [
        // Üstte simülasyon aşaması toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Simülasyon Aşaması',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              ToggleButtons(
                borderRadius: BorderRadius.circular(12),
                isSelected: [
                  phase == SimulationPhase.notStarted,
                  phase == SimulationPhase.finished,
                ],
                constraints:
                    const BoxConstraints(minHeight: 36, minWidth: 90),
                onPressed: (index) {
                  final newPhase = index == 0
                      ? SimulationPhase.notStarted
                      : SimulationPhase.finished;
                  context
                      .read<GameRepository>()
                      .setSimulationPhase(newPhase);
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Maç Başlamadı'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Maç Bitti'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),

        // Maç listesi
        Expanded(
          child: ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (_, i) {
              final m = matches[i];

              // Simülasyon mantığı:
              // Maç Başlamadı -> 0-0 göster
              // Maç Bitti -> gerçek skorları göster
              final homePts =
                  phase == SimulationPhase.notStarted ? 0 : m.homePts;
              final awayPts =
                  phase == SimulationPhase.notStarted ? 0 : m.awayPts;

              return ListTile(
                title: Text(
                  '${m.home}  $homePts  —  $awayPts  ${m.away}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${m.tipoff.toLocal()}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month,
                      color: Colors.white70),
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF0B1A2E),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => _DayPickerSheet(
                        days: _days,
                        fmt: _fmt,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Alt tarafta gün seçim sheet'i
// ---------------------------------------------------------------------------
class _DayPickerSheet extends StatelessWidget {
  const _DayPickerSheet({
    required this.days,
    required this.fmt,
  });

  final List<DateTime> days;
  final String Function(DateTime) fmt;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GameRepository>();
    final selected = repo.selectedDay;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gün Seçin',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final d = days[i];
                  final isSel = selected != null &&
                      d.year == selected.year &&
                      d.month == selected.month &&
                      d.day == selected.day;
                  return ListTile(
                    title: Text(
                      fmt(d),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check, color: Colors.white70)
                        : null,
                    onTap: () async {
                      await context.read<GameRepository>().selectDay(d);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
