
import '../services/auth_service.dart';
import '../services/prediction_repository.dart';
import '../services/game_repository.dart';

class Env {
  
  static const String supabaseUrl = '';
  static const String supabaseAnonKey = '';

    
  static final IAuthService auth = AuthServiceDb();

  
  static final PredictionRepository predictions = MemoryPredictionRepository();

  
  static final GameRepository games = GameRepository();

  
  static const bool useSupabaseAuth = false;
}
// OSD