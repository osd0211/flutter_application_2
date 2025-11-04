import 'package:flutter/foundation.dart'; // ValueListenable için
import 'package:flutter/material.dart';

import '../../models.dart';
import '../../ui/app_theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    super.key,
    required this.challenges,
  });

  final ValueListenable<List<PredictionChallenge>> challenges;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PredictionChallenge>>(
      valueListenable: challenges,
      builder: (context, list, _) {
        final Map<String, int> totals = {};
        for (final c in list) {
          final add = c.points + c.assists + c.rebounds;
          totals.update(c.playerName, (v) => v + add, ifAbsent: () => add);
        }

        final entries = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          backgroundColor: AppColors.background,
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(e.key),
                  trailing: Text(
                    '${e.value}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
