// lib/screens/scores_screen.dart
import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../ui/app_theme.dart';

class ScoresScreen extends StatelessWidget {
  const ScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mockGames.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final g = mockGames[i];
        return Card(
          color: AppColors.surface,
          child: ListTile(
            title: Text('${g.homeTeam}  ${g.homeScore} – ${g.awayScore}  ${g.awayTeam}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Başlama: ${g.tipoff}'),
            leading: const Icon(Icons.sports_basketball, color: AppColors.yellow),
          ),
        );
      },
    );
  }
}
