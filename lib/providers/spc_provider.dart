// lib/providers/spc_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spc_state.dart';
import '../services/spc_service.dart';
import 'inspection_provider.dart';

/// Provider de l'état SPC dérivé de inspectionListProvider.
/// Extrait les pitch_mean_mm et calcule SpcState.
final spcStateProvider = Provider<SpcState>((ref) {
  final inspectionsAsync = ref.watch(inspectionListProvider);

  return inspectionsAsync.when(
    data: (inspections) => SpcService.compute(inspections),
    loading: () => const SpcState(),
    error: (_, __) => const SpcState(),
  );
});

/// Provider pour une version étendue de l'état SPC (plus de données)
final extendedSpcStateProvider = Provider<SpcState>((ref) {
  final inspectionsAsync = ref.watch(inspectionHistoryProvider(100));

  return inspectionsAsync.when(
    data: (inspections) => SpcService.compute(inspections),
    loading: () => const SpcState(),
    error: (_, __) => const SpcState(),
  );
});

/// Provider dérivé: dérive détectée?
final driftDetectedProvider = Provider<bool>((ref) {
  return ref.watch(spcStateProvider).driftDetected;
});

/// Provider dérivé: dernier pitch
final lastPitchProvider = Provider<double?>((ref) {
  return ref.watch(spcStateProvider).lastPitch;
});

/// Provider dérivé: nombre de points hors contrôle
final outOfControlCountProvider = Provider<int>((ref) {
  return ref.watch(spcStateProvider).outOfControlCount;
});

/// Provider dérivé: Cp (Process Capability)
final cpProvider = Provider<double>((ref) {
  return ref.watch(extendedSpcStateProvider).cp;
});

/// Provider dérivé: Cpk (Process Capability Index)
final cpkProvider = Provider<double>((ref) {
  return ref.watch(extendedSpcStateProvider).cpk;
});

/// Provider dérivé: moyenne des pitches
final meanPitchProvider = Provider<double>((ref) {
  return ref.watch(spcStateProvider).mean;
});

/// Provider dérivé: écart-type
final stdDevProvider = Provider<double>((ref) {
  return ref.watch(extendedSpcStateProvider).standardDeviation;
});
