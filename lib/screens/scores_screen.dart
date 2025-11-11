import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_repository.dart';
import '../services/data_source.dart';
import '../ui/app_theme.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});
  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  List<DateTime> _allDays = [];
  bool _loadingDays = true;
  bool _loadingBox = false;

  @override
  void initState() {
    super.initState();
    _loadAllDays();
  }

  Future<void> _loadAllDays() async {
    final paths = await DataSource.instance.listAllCsvAssets();
    final days = <DateTime>[];
    for (final p in paths) {
      final d = DataSource.extractDateFromPath(p);
      if (d != null) days.add(DateTime(d.year, d.month, d.day));
    }
    days.sort();

    setState(() {
      _allDays = days;
      _loadingDays = false;
    });

    final repo = context.read<GameRepository>();
    if (repo.selectedDay == null && days.isNotEmpty) {
      await _selectDay(days.last, repo);
    }
  }

  Future<void> _selectDay(DateTime day, GameRepository repo) async {
    setState(() => _loadingBox = true);
    await repo.ensureDayLoaded(day);
    repo.selectDay(day);
    if (mounted) setState(() => _loadingBox = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GameRepository>();
    final selected = repo.selectedDay;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: Colors.white70),
                const SizedBox(width: 8),
                Text('Skorlar (CSV)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                if (_loadingDays)
                  const SizedBox(
                    height: 28, width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  DropdownButton<DateTime>(
                    value: selected ?? (_allDays.isNotEmpty ? _allDays.last : null),
                    dropdownColor: AppColors.card,  // yoksa Colors.black54 da olur
                    iconEnabledColor: Colors.white70,
                    items: _allDays.map((d) {
                      final label =
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                      return DropdownMenuItem(
                        value: d,
                        child: Text(label, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (d) {
                      if (d == null) return;
                      _selectDay(d, repo);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingBox) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Expanded(child: _content(repo)),
          ],
        ),
      ),
    );
  }

  Widget _content(GameRepository repo) {
    if (repo.selectedDay == null) {
      return const Center(
        child: Text('Önce bir gün seç.', style: TextStyle(color: Colors.white70)),
      );
    }
    if (!repo.hasBoxscoreForSelected) {
      return const Center(
        child: Text('Bu gün için boxscore bulunamadı.',
            style: TextStyle(color: Colors.white70)),
      );
    }

    final box = repo.boxscoreForSelected();
    final day = repo.selectedDay!;
    final label =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    return ListView(
      children: [
        Text('$label için kayıt sayısı: ${box.length}',
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        ...box.entries.take(30).map((e) => ListTile(
              title: Text(e.key, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                'Sayı ${e.value.pts} • Asist ${e.value.ast} • Rib ${e.value.reb}',
                style: const TextStyle(color: Colors.white70),
              ),
            )),
      ],
    );
  }
}
