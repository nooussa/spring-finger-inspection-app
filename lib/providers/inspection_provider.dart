// lib/providers/inspection_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspection_result.dart';
import '../services/inspection_db_service.dart';

/// Provider qui poll /inspections/latest toutes les 5 secondes
final inspectionListProvider =
    StreamProvider<List<InspectionResult>>((ref) async* {
  final dbService = ref.watch(inspectionDbServiceProvider);

  await for (final inspections in dbService.pollLatest(
    interval: const Duration(seconds: 5),
    n: 20,
  )) {
    // Mettre à jour le timestamp du dernier fetch réussi
    ref.read(lastFetchTimeProvider.notifier).state = DateTime.now();
    yield inspections;
  }
});

/// Provider pour récupérer plus d'inspections (pour l'historique)
final inspectionHistoryProvider =
    StreamProvider.family<List<InspectionResult>, int>((ref, count) async* {
  final dbService = ref.watch(inspectionDbServiceProvider);

  await for (final inspections in dbService.pollLatest(
    interval: const Duration(seconds: 10),
    n: count,
  )) {
    ref.read(lastFetchTimeProvider.notifier).state = DateTime.now();
    yield inspections;
  }
});

/// Provider des stats (poll toutes les 10 secondes)
final statsProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final dbService = ref.watch(inspectionDbServiceProvider);

  await for (final stats in dbService.pollStats(
    interval: const Duration(seconds: 10),
  )) {
    yield stats;
  }
});

/// Provider dérivé : nombre de PASS
final passCountProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['pass'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider dérivé : nombre de FAIL
final failCountProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['fail'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider dérivé : total inspections
final totalCountProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['total'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider dérivé : taux de conformité (double 0.0-1.0)
final conformityRateProvider = Provider<double>((ref) {
  final pass = ref.watch(passCountProvider);
  final fail = ref.watch(failCountProvider);
  final total = pass + fail;
  if (total == 0) return 0.0;
  return pass / total;
});

/// Provider dérivé : taux de conformité depuis stats API (plus précis)
final conformityRateFromStatsProvider = Provider<double>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) =>
        ((stats['taux_pass_pct'] as num?)?.toDouble() ?? 0.0) / 100.0,
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider pour le pitch moyen depuis les stats
final avgPitchProvider = Provider<double>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['avg_pitch_mm'] as num?)?.toDouble() ?? 0.0,
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider pour le total de doigts manquants
final totalMissingProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['total_missing'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider pour le total de doigts pliés
final totalBentProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['total_bent'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Filtre pour l'historique
enum InspectionFilter { all, pass, fail }

final inspectionFilterProvider =
    StateProvider<InspectionFilter>((ref) => InspectionFilter.all);

/// Provider filtré des inspections pour l'historique
final filteredInspectionsProvider =
    Provider<AsyncValue<List<InspectionResult>>>((ref) {
  final inspectionsAsync = ref.watch(inspectionHistoryProvider(100));
  final filter = ref.watch(inspectionFilterProvider);

  return inspectionsAsync.when(
    data: (inspections) {
      final filtered = switch (filter) {
        InspectionFilter.all => inspections,
        InspectionFilter.pass =>
          inspections.where((i) => i.verdict == 'PASS').toList(),
        InspectionFilter.fail =>
          inspections.where((i) => i.verdict == 'FAIL').toList(),
      };
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
