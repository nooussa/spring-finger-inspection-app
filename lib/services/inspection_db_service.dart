// lib/services/inspection_db_service.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspection_result.dart';
import 'api_service.dart';

/// Service d'accès aux données d'inspection.
/// Encapsule les appels à ApiService pour les inspections.
class InspectionDbService {
  final ApiService _apiService;

  InspectionDbService(this._apiService);

  /// Récupère les N dernières inspections
  Future<List<InspectionResult>> fetchLatest({int n = 20}) async {
    return _apiService.getLatestInspections(n: n);
  }

  /// Récupère les statistiques globales
  Future<Map<String, dynamic>> fetchStats() async {
    return _apiService.getStats();
  }

  /// Stream qui poll les dernières inspections à intervalle régulier
  Stream<List<InspectionResult>> pollLatest({
    Duration interval = const Duration(seconds: 5),
    int n = 20,
  }) async* {
    // Émettre immédiatement au premier appel
    try {
      yield await fetchLatest(n: n);
    } catch (e) {
      yield []; // Liste vide en cas d'erreur initiale
    }

    // Puis poll à intervalle régulier
    await for (final _ in Stream.periodic(interval)) {
      try {
        yield await fetchLatest(n: n);
      } catch (e) {
        // En cas d'erreur, on n'émet pas (garde la dernière valeur)
        // Le prochain poll réessaiera
      }
    }
  }

  /// Stream qui poll les stats à intervalle régulier
  Stream<Map<String, dynamic>> pollStats({
    Duration interval = const Duration(seconds: 10),
  }) async* {
    // Émettre immédiatement
    try {
      yield await fetchStats();
    } catch (e) {
      yield _defaultStats();
    }

    // Poll à intervalle
    await for (final _ in Stream.periodic(interval)) {
      try {
        yield await fetchStats();
      } catch (e) {
        // Garder dernière valeur
      }
    }
  }

  /// Stats par défaut en cas d'erreur
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

/// Provider pour InspectionDbService
final inspectionDbServiceProvider = Provider<InspectionDbService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return InspectionDbService(apiService);
});

/// Stocke le dernier timestamp de fetch réussi (pour badge connexion)
final lastFetchTimeProvider = StateProvider<DateTime?>((ref) => null);

/// Provider indiquant si l'API est connectée (dernier fetch < 10s)
final isApiConnectedProvider = Provider<bool>((ref) {
  final lastFetch = ref.watch(lastFetchTimeProvider);
  if (lastFetch == null) return false;
  return DateTime.now().difference(lastFetch).inSeconds < 10;
});
