// lib/services/prediction_repository.dart
import '../models.dart';

/// Arayüz
abstract class PredictionRepository {
  Future<List<PredictionChallenge>> fetchyPredictions(String userId);
  Future<void> addPrediction(String userId, PredictionChallenge c);
  Future<int> myTotalPoints(String userId);
}

/// Basit bellek içi (mock) implementasyon
class MemoryPredictionRepository implements PredictionRepository {
  final List<PredictionChallenge> _store = <PredictionChallenge>[];

  @override
  Future<List<PredictionChallenge>> fetchyPredictions(String userId) async {
    return List.unmodifiable(_store);
  }

  @override
  Future<void> addPrediction(String userId, PredictionChallenge c) async {
    _store.add(c);
  }

  @override
  Future<int> myTotalPoints(String userId) async {
    return _store.fold<int>(0, (a, b) => a + b.points);
  }
}
