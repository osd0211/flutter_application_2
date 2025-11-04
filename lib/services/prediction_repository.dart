// Prediction repository (Mock & Supabase için arayüz)

import '../models.dart';

abstract class PredictionRepository {
  Future<List<PredictionChallenge>> fetchMyPredictions(String userId);
  Future<void> addPrediction(String userId, PredictionChallenge c);
  Future<void> deletePrediction(String userId, String id);
  Future<int> myTotalPoints(String userId);
}

/// MOCK: hafızada tutar; uygulama kapanınca sıfırlanır.
class MockPredictionRepository implements PredictionRepository {
  final List<PredictionChallenge> _store = [];

  @override
  Future<List<PredictionChallenge>> fetchMyPredictions(String userId) async {
    return List<PredictionChallenge>.from(_store);
  }

  @override
  Future<void> addPrediction(String userId, PredictionChallenge c) async {
    _store.insert(0, c);
  }

  @override
  Future<void> deletePrediction(String userId, String id) async {
    _store.removeWhere((e) => e.id == id);
  }

  @override
  Future<int> myTotalPoints(String userId) async {
    final total = _store.fold<int>(0, (a, c) => a + c.points);
    return total; // Future<int>
  }
}


/// Supabase sürümü — şimdilik iskelet (yarın dolduracağız).
class SupabasePredictionRepository implements PredictionRepository {
  @override
  Future<void> addPrediction(String userId, PredictionChallenge c) async {
    // await Supabase.instance.client.from('predictions').insert({...});
  }

  @override
  Future<void> deletePrediction(String userId, String id) async {
    // await Supabase.instance.client.from('predictions').delete().eq('id', id).eq('user_id', userId);
  }

  @override
  Future<List<PredictionChallenge>> fetchMyPredictions(String userId) async {
    // final res = await Supabase.instance.client.from('predictions').select()...
    return [];
  }

  @override
  Future<int> myTotalPoints(String userId) async {
    // final res = await Supabase.instance.client.from('predictions').select('points')...
    return 0;
  }
}
