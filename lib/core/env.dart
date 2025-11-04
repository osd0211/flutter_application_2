// Uygulama özellik bayrakları ve global bağımlılıklar
import '../services/prediction_repository.dart';
import '../services/auth_service.dart';

class Env {
  /// Login ekranını kullan (true) ya da kapat (false)
  static const bool useAuth = true;

  /// Auth tipi: false => MockAuth, true => SupabaseAuth
  static const bool useSupabaseAuth = false;

  /// Supabase bilgileri (ileride doldurursun)
  static const String supabaseUrl = 'https://hygyowdbnpgkxtguwpzx.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh5Z3lvd2RibnBna3h0Z3V3cHp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDc4NTEsImV4cCI6MjA3NzgyMzg1MX0.3nFHXI_YH57xShKagaMqFslKRRghyuOockj0exLSQKQ';

  /// Auth servis seçimi
  static AuthService get auth =>
      useSupabaseAuth ? SupabaseAuthService() : MockAuthService();

  /// Prediction repo seçimi (bugün MOCK)
  static PredictionRepository get predictions => MockPredictionRepository();
  // Yarın Supabase’e geçmek istersen:
  // static PredictionRepository get predictions => SupabasePredictionRepository();
}
