

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspection_result.dart';
import 'api_service.dart';


class InspectionDbService {
  final ApiService _apiService;

  InspectionDbService(this._apiService);

  Future<List<InspectionResult>> fetchLatest({int n = 20}) async {
    return _apiService.getLatestInspections(n: n);
  }

  Future<Map<String, dynamic>> fetchStats() async {
    return _apiService.getStats();
  }

  Stream<List<InspectionResult>> pollLatest({
    Duration interval = const Duration(seconds: 5),
    int n = 20,
  }) async* {

    try {
      yield await fetchLatest(n: n);
    } catch (e) {
      yield []; // Liste vide en cas d'erreur initiale
    }

    await for (final _ in Stream.periodic(interval)) {
      try {
        yield await fetchLatest(n: n);
      } catch (e) {


      }
    }
  }

  Stream<Map<String, dynamic>> pollStats({
    Duration interval = const Duration(seconds: 10),
  }) async* {

    try {
      yield await fetchStats();
    } catch (e) {
      yield _defaultStats();
    }

    await for (final _ in Stream.periodic(interval)) {
      try {
        yield await fetchStats();
      } catch (e) {

      }
    }
  }

  Map<String, dynamic> _defaultStats() => {
        'total': 0,
        'pass': 0,
        'fail': 0,
        'taux_pass_pct': 0.0,
        'avg_pitch_mm': 0.0,
        'avg_total_mm': 0.0,
        'avg_mpp': 0.0,
        'total_ok': 0,
        'total_missing': 0,
        'total_bent': 0,
      };
}

final inspectionDbServiceProvider = Provider<InspectionDbService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return InspectionDbService(apiService);
});

final lastFetchTimeProvider = StateProvider<DateTime?>((ref) => null);

final isApiConnectedProvider = Provider<bool>((ref) {
  final lastFetch = ref.watch(lastFetchTimeProvider);
  if (lastFetch == null) return false;
  return DateTime.now().difference(lastFetch).inSeconds < 10;
});
