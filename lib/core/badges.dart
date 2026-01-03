import 'package:flutter/material.dart';

class BadgeMeta {
  final String title;
  final String description;
  final IconData icon;

  const BadgeMeta(this.title, this.description, this.icon);
}

/// 🎖️ Badge catalog (title + description + icon)
const Map<String, BadgeMeta> badgeCatalog = {
  // ⭐ Favoriler
  'fav_team_set': BadgeMeta(
    'Sadık Taraftar',
    'Favori takımını seçtin',
    Icons.shield,
  ),
  'fav_player_set': BadgeMeta(
    'Yıldız Avcısı',
    'Favori oyuncunu seçtin',
    Icons.star,
  ),

  // 🎯 Başlangıç
  'first_prediction': BadgeMeta(
    'İlk Adım',
    'İlk tahminini yaptın',
    Icons.play_arrow,
  ),
  'day_5_predictions': BadgeMeta(
    'Tahmin Makinesi',
    'Bir günde 5 tahmin',
    Icons.flash_on,
  ),

  // 🧠 Doğruluk
  'exact_1': BadgeMeta(
    'Keskin Göz',
    '1 istatistik tam',
    Icons.visibility,
  ),
  'exact_2': BadgeMeta(
    'Analist',
    '2 istatistik tam',
    Icons.analytics,
  ),
  'perfect_3': BadgeMeta(
    'Kahin',
    'Tüm istatistikler tam',
    Icons.auto_awesome,
  ),

  // 🚀 Level
  'level_5': BadgeMeta(
    'Rookie',
    'Level 5’e ulaştın',
    Icons.looks_one,
  ),
  'level_10': BadgeMeta(
    'Sixth Man',
    'Level 10’a ulaştın',
    Icons.looks_two,
  ),
  'level_25': BadgeMeta(
    'All-Star',
    'Level 25’e ulaştın',
    Icons.star_rate,
  ),
  'level_50': BadgeMeta(
    'MVP',
    'Level 50’e ulaştın',
    Icons.emoji_events,
  ),
  'level_100': BadgeMeta(
    'GOAT',
    'Level 100’e ulaştın',
    Icons.whatshot,
  ),
};

/// ✅ Badge detaylarını gösteren bottom sheet
void showBadgeDetailsSheet(
  BuildContext context, {
  required String badgeKey,
  required String earnedAt,
  required int xp,
}) {
  final meta = badgeCatalog[badgeKey];

  final title = meta?.title ?? badgeKey;
  final desc = meta?.description ?? 'Açıklama bulunamadı.';
  final icon = meta?.icon ?? Icons.verified;

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(desc),
            const SizedBox(height: 14),
            Text(
              'XP: +$xp',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Kazanma: $earnedAt',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
