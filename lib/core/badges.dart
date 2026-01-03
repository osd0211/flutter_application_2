import 'package:flutter/material.dart';

class BadgeMeta {
  final String title;
  final String description;
  final IconData icon;

  const BadgeMeta(this.title, this.description, this.icon);
}

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
    'Level 50’ye ulaştın',
    Icons.emoji_events,
  ),
  'level_100': BadgeMeta(
    'GOAT',
    'Level 100’e ulaştın',
    Icons.whatshot,
  ),
};
