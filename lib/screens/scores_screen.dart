import 'package:flutter/material.dart';
import '../core/env.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadForDate(Env.selectedDate);
  }

  Future<void> _loadForDate(DateTime date) async {
    setState(() => _loading = true);
    final matches = await Env.data.loadMatchesForDate(date);
    setState(() {
      Env.selectedDate = date;
      Env.lastMatches = matches;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: Env.selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      await _loadForDate(picked);
    }
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final list = Env.lastMatches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skorlar (CSV)'),
        actions: [
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_month))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(child: Text('Bu gün için kayıt yok'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final g = list[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.sports_basketball),
                        title: Text('${g.home} – ${g.away}'),
                        subtitle: Text('Bitti • ${_hhmm(g.tipoff)}'),
                        onTap: () async {
                          // Bu maça ait boxscore’u yükle ve cache’e koy
                          final box = await Env.data.loadBoxScoreForGame(g.id, Env.selectedDate);
                          setState(() => Env.lastBoxscore = box);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Boxscore yüklendi: ${box.length} oyuncu')),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
