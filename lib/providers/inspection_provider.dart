

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspection_result.dart';
import '../services/inspection_db_service.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';

final inspectionListProvider =
    StreamProvider<List<InspectionResult>>((ref) async* {
  final wsService = ref.watch(webSocketServiceProvider);
  final token = ref.watch(authTokenProvider);

  await for (final payload in wsService.stream(token: token)) {

    ref.read(lastFetchTimeProvider.notifier).state = DateTime.now();
    yield payload.inspections;
  }
});

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

final statsProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final wsService = ref.watch(webSocketServiceProvider);
  final token = ref.watch(authTokenProvider);

  await for (final payload in wsService.stream(token: token)) {
    ref.read(lastFetchTimeProvider.notifier).state = DateTime.now();
    yield payload.stats;
  }
});

final passCountProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['pass'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final failCountProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['fail'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final totalCountProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['total'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final conformityRateProvider = Provider<double>((ref) {
  final pass = ref.watch(passCountProvider);
  final fail = ref.watch(failCountProvider);
  final total = pass + fail;
  if (total == 0) return 0.0;
  return pass / total;
});

final conformityRateFromStatsProvider = Provider<double>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) =>
        ((stats['taux_pass_pct'] as num?)?.toDouble() ?? 0.0) / 100.0,
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

final avgPitchProvider = Provider<double>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['avg_pitch_mm'] as num?)?.toDouble() ?? 0.0,
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

final totalMissingProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['total_missing'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final totalBentProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(statsProvider);
  return statsAsync.when(
    data: (stats) => (stats['total_bent'] as num?)?.toInt() ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

enum InspectionFilter { all, pass, fail }

final inspectionFilterProvider =
    StateProvider<InspectionFilter>((ref) => InspectionFilter.all);

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
