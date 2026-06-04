import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inspection_result.dart';
import '../services/analysis_service.dart';

enum AnalysisPhase { idle, running, success, failure }

class AnalysisState {
  final AnalysisPhase phase;
  final InspectionResult? result;
  final String? error;
  final String message;
  final bool usedFallback;

  const AnalysisState({
    required this.phase,
    this.result,
    this.error,
    this.message = '',
    this.usedFallback = false,
  });

  const AnalysisState.idle() : this(phase: AnalysisPhase.idle);

  AnalysisState copyWith({
    AnalysisPhase? phase,
    InspectionResult? result,
    String? error,
    String? message,
    bool? usedFallback,
  }) {
    return AnalysisState(
      phase: phase ?? this.phase,
      result: result ?? this.result,
      error: error,
      message: message ?? this.message,
      usedFallback: usedFallback ?? this.usedFallback,
    );
  }
}

class AnalysisController extends StateNotifier<AnalysisState> {
  final AnalysisService _analysisService;

  AnalysisController(this._analysisService) : super(const AnalysisState.idle());

  Future<void> run({
    String? token,
    String? operatorId,
    String? pieceCode,
    String? lot,
    String mode = 'quick',
  }) async {
    state = state.copyWith(
      phase: AnalysisPhase.running,
      error: null,
      message: 'Analyse en cours...',
      usedFallback: false,
    );

    try {
      final runResult = await _analysisService.analyzeNow(
        token: token,
        operatorId: operatorId,
        pieceCode: pieceCode,
        lot: lot,
        mode: mode,
      );
      state = AnalysisState(
        phase: AnalysisPhase.success,
        result: runResult.inspection,
        message: runResult.message,
        usedFallback: runResult.usedFallback,
      );
    } catch (e) {
      state = AnalysisState(
        phase: AnalysisPhase.failure,
        error: e.toString(),
        message: 'Analyse échouée.',
      );
    }
  }

  Future<void> runFromFile({
    required File imageFile,
    String? token,
    String? operatorId,
    String? pieceCode,
    String? lot,
    String sourceType = 'gallery',
    String mode = 'quick',
  }) async {
    state = state.copyWith(
      phase: AnalysisPhase.running,
      error: null,
      message: 'Analyse de l\'image en cours...',
      usedFallback: false,
    );

    try {
      final runResult = await _analysisService.analyzeFromFile(
        imageFile: imageFile,
        token: token,
        operatorId: operatorId,
        pieceCode: pieceCode,
        lot: lot,
        sourceType: sourceType,
        mode: mode,
      );
      state = AnalysisState(
        phase: AnalysisPhase.success,
        result: runResult.inspection,
        message: runResult.message,
        usedFallback: runResult.usedFallback,
      );
    } catch (e) {
      state = AnalysisState(
        phase: AnalysisPhase.failure,
        error: e.toString(),
        message: 'Analyse échouée.',
      );
    }
  }

  void reset() {
    state = const AnalysisState.idle();
  }
}

final analysisControllerProvider =
    StateNotifierProvider<AnalysisController, AnalysisState>((ref) {
  final service = ref.watch(analysisServiceProvider);
  return AnalysisController(service);
});
