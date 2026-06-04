

class SpcState {

  final List<double> pitches;

  final double ucl;

  final double lcl;

  final double target;

  final bool driftDetected;

  const SpcState({
    this.pitches = const [],
    this.ucl = 2.65,
    this.lcl = 2.35,
    this.target = 2.50,
    this.driftDetected = false,
  });

  double? get lastPitch => pitches.isNotEmpty ? pitches.last : null;

  double get mean {
    if (pitches.isEmpty) return 0.0;
    return pitches.reduce((a, b) => a + b) / pitches.length;
  }

  int get count => pitches.length;

  bool isOutOfControl(double pitch) => pitch > ucl || pitch < lcl;

  int get outOfControlCount => pitches.where(isOutOfControl).length;

  double get standardDeviation {
    if (pitches.length < 2) return 0.0;
    final m = mean;
    final sumSquares =
        pitches.map((p) => (p - m) * (p - m)).reduce((a, b) => a + b);
    return _sqrt(sumSquares / (pitches.length - 1));
  }

  double get cp {
    final sigma = standardDeviation;
    if (sigma == 0) return 0.0;
    return (ucl - lcl) / (6 * sigma);
  }

  double get cpk {
    final sigma = standardDeviation;
    if (sigma == 0) return 0.0;
    final cpuVal = (ucl - mean) / (3 * sigma);
    final cplVal = (mean - lcl) / (3 * sigma);
    return cpuVal < cplVal ? cpuVal : cplVal;
  }

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

  SpcState addPitch(double pitch) {
    final newPitches = [...pitches, pitch];
    return copyWith(
      pitches: newPitches,
      driftDetected: _detectDrift(newPitches),
    );
  }

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

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  factory SpcState.fromPitches(
    List<double> pitches, {
    double ucl = 2.65,
    double lcl = 2.35,
    double target = 2.50,
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
