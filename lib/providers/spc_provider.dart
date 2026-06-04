

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spc_state.dart';
import '../services/spc_service.dart';
import 'inspection_provider.dart';


final spcStateProvider = Provider<SpcState>((ref) {
  final inspectionsAsync = ref.watch(inspectionListProvider);

  return inspectionsAsync.when(
    data: (inspections) => SpcService.compute(inspections),
    loading: () => const SpcState(),
    error: (_, __) => const SpcState(),
  );
});

final extendedSpcStateProvider = Provider<SpcState>((ref) {
  final inspectionsAsync = ref.watch(inspectionHistoryProvider(100));

  return inspectionsAsync.when(
    data: (inspections) => SpcService.compute(inspections),
    loading: () => const SpcState(),
    error: (_, __) => const SpcState(),
  );
});

final driftDetectedProvider = Provider<bool>((ref) {
  return ref.watch(spcStateProvider).driftDetected;
});

final lastPitchProvider = Provider<double?>((ref) {
  return ref.watch(spcStateProvider).lastPitch;
});

final outOfControlCountProvider = Provider<int>((ref) {
  return ref.watch(spcStateProvider).outOfControlCount;
});

final cpProvider = Provider<double>((ref) {
  return ref.watch(extendedSpcStateProvider).cp;
});

final cpkProvider = Provider<double>((ref) {
  return ref.watch(extendedSpcStateProvider).cpk;
});

final meanPitchProvider = Provider<double>((ref) {
  return ref.watch(spcStateProvider).mean;
});

final stdDevProvider = Provider<double>((ref) {
  return ref.watch(extendedSpcStateProvider).standardDeviation;
});
