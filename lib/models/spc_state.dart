// lib/models/spc_state.dart

/// État SPC (Statistical Process Control) pour le monitoring pitch.
class SpcState {
  /// Liste des valeurs de pitch mesurées (pitch_mean_mm)
  final List<double> pitches;

  /// Limite de contrôle supérieure (Upper Control Limit)
  final double ucl;

  /// Limite de contrôle inférieure (Lower Control Limit)
  final double lcl;

  /// Valeur cible
  final double target;

  /// Dérive détectée (7 points consécutifs monotones)
  final bool driftDetected;

  const SpcState({
    this.pitches = const [],
    this.ucl = 1.25,
    this.lcl = 1.15,
    this.target = 1.20,
    this.driftDetected = false,
  });

  /// Dernier pitch mesuré (null si aucune donnée)
  double? get lastPitch => pitches.isNotEmpty ? pitches.last : null;

  /// Moyenne des pitches
  double get mean {
    if (pitches.isEmpty) return 0.0;
    return pitches.reduce((a, b) => a + b) / pitches.length;
  }

  /// Nombre de points
  int get count => pitches.length;

  /// Vérifie si un pitch est hors contrôle
  bool isOutOfControl(double pitch) => pitch > ucl || pitch < lcl;

  /// Compte les points hors contrôle
  int get outOfControlCount => pitches.where(isOutOfControl).length;

  /// Écart-type
  double get standardDeviation {
    if (pitches.length < 2) return 0.0;
    final m = mean;
    final sumSquares =
        pitches.map((p) => (p - m) * (p - m)).reduce((a, b) => a + b);
    return _sqrt(sumSquares / (pitches.length - 1));
  }

  /// Cp (Process Capability)
  double get cp {
    final sigma = standardDeviation;
    if (sigma == 0) return 0.0;
    return (ucl - lcl) / (6 * sigma);
  }

  /// Cpk (Process Capability Index)
  double get cpk {
    final sigma = standardDeviation;
    if (sigma == 0) return 0.0;
    final cpuVal = (ucl - mean) / (3 * sigma);
    final cplVal = (mean - lcl) / (3 * sigma);
    return cpuVal < cplVal ? cpuVal : cplVal;
  }

  /// Copie avec modifications
  SpcState copyWith({
    List<double>? pitches,
    double? ucl,
    double? lcl,
    double? target,
    bool? driftDetected,
  }) {
    return SpcState(
      pitches: pitches ?? this.pitches,
      ucl: ucl ?? this.ucl,
      lcl: lcl ?? this.lcl,
      target: target ?? this.target,
      driftDetected: driftDetected ?? this.driftDetected,
    );
  }

  /// Ajoute un nouveau pitch et retourne un nouvel état
  SpcState addPitch(double pitch) {
    final newPitches = [...pitches, pitch];
    return copyWith(
      pitches: newPitches,
      driftDetected: _detectDrift(newPitches),
    );
  }

  /// Détecte une dérive (7 points consécutifs monotones)
  static bool _detectDrift(List<double> values) {
    if (values.length < 7) return false;
    final last7 = values.sublist(values.length - 7);
    bool allIncreasing = true;
    bool allDecreasing = true;
    for (int i = 1; i < last7.length; i++) {
      if (last7[i] <= last7[i - 1]) allIncreasing = false;
      if (last7[i] >= last7[i - 1]) allDecreasing = false;
    }
    return allIncreasing || allDecreasing;
  }

  /// Racine carrée simple (évite d'importer dart:math partout)
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  /// Crée un état à partir d'une liste de pitches
  factory SpcState.fromPitches(
    List<double> pitches, {
    double ucl = 1.25,
    double lcl = 1.15,
    double target = 1.20,
  }) {
    return SpcState(
      pitches: pitches,
      ucl: ucl,
      lcl: lcl,
      target: target,
      driftDetected: _detectDrift(pitches),
    );
  }
}
