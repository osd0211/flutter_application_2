import 'package:flutter/material.dart';
import '../ui/app_theme.dart';
import '../models.dart';

class LeaderboardScreen extends StatelessWidget {
  final List<PredictionChallenge> challenges;
  const LeaderboardScreen({super.key, required this.challenges});

  int get myTotal => challenges.fold(0, (a, c) => a + c.points);

  @override
  Widget build(BuildContext context) {
    final rows = <(String ad, int puan)>[
      ('Sen', myTotal),
      ('Bot-A', (myTotal * .85).round()),
      ('Bot-B', (myTotal * .70).round()),
      ('Bot-C', (myTotal * .55).round()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => Gaps.h12,
      itemBuilder: (_, i) {
        final r = rows[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.orange.withValues(alpha: .25)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: i == 0 ? AppColors.yellow : AppColors.navy.withValues(alpha: .6),
                foregroundColor: Colors.black,
                child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Gaps.w12,
              Expanded(child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w800))),
              const Icon(Icons.bolt, color: AppColors.yellow, size: 18),
              Gaps.w8,
              Text('${r.$2} puan', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        );
      },
    );
  }
}
