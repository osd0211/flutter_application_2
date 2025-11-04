// lib/models.dart
import 'package:flutter/material.dart';

// Basit oyuncu modeli
class Player {
  final String id;
  final String name;
  const Player({required this.id, required this.name});
}

// Maç modeli (skor ve maçtaki oyuncular)
class MatchGame {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final DateTime tipoff;
  final List<Player> roster; // Bu maçta kullanılabilir oyuncular

  const MatchGame({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.tipoff,
    required this.roster,
  });
}

// Tahmin (tek oyuncu için 3 istatistik)
class PredictionChallenge {
  final String id;
  final String matchId;
  final String playerId;
  final String playerName;
  final int points;
  final int assists;
  final int rebounds;
  final DateTime createdAt;

  const PredictionChallenge({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.playerName,
    required this.points,
    required this.assists,
    required this.rebounds,
    required this.createdAt,
  });
}
