import 'package:flutter/material.dart';
import '../ui/app_theme.dart';
import '../data/mock.dart';

class ScoresScreen extends StatelessWidget {
  const ScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: mockMatches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final m = mockMatches[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.orange.withValues(alpha: .2)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${m.home} vs ${m.away}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              const Divider(height: 1, thickness: 1, color: Colors.white24),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Tip-off: ${m.tipoff}',
                      style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(m.status,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
