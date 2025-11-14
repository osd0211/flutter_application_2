// lib/core/env.dart
// Ortak environment ayarları: auth, repo'lar, vb.

import '../services/auth_service.dart';
import '../services/prediction_repository.dart';
import '../services/game_repository.dart';

class Env {
  /// Supabase kullanacaksan doldurursun; şimdilik mock
  static const String supabaseUrl = '';
  static const String supabaseAnonKey = '';

  /// Mock kimlik doğrulama
  static final IAuthService auth = AuthServiceMock();

  /// Tahmin (prediction) verileri
  static final PredictionRepository predictions = MemoryPredictionRepository();

  /// Maç & boxscore verileri (CSV okuyan repo)
  static final GameRepository games = GameRepository();

  /// Supabase Auth kullanımı (şimdilik kapalı)
  static const bool useSupabaseAuth = false;
}
