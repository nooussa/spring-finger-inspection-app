

import '../models/inspection_result.dart';
import '../models/spc_state.dart';


class SpcService {

  static const double defaultUcl = 2.650;
  static const double defaultLcl = 2.350;
  static const double defaultTarget = 2.500;


  static SpcState compute(
    List<InspectionResult> inspections, {
    double ucl = defaultUcl,
    double lcl = defaultLcl,
    double target = defaultTarget,
  }) {
    final pitches = extractPitches(inspections);
    return SpcState.fromPitches(
      pitches,
      ucl: ucl,
      lcl: lcl,
      target: target,
    );
  }


  static List<double> extractPitches(List<InspectionResult> inspections) {
    return extractPitchesChronological(inspections);
  }

  static List<double> extractPitchesChronological(
      List<InspectionResult> inspections) {
    final sorted = List<InspectionResult>.from(inspections)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted
        .where((i) => i.pitchMeanMm > 0)
        .map((i) => i.pitchMeanMm)
        .toList();
  }

  static bool detectDrift(List<double> pitches) {
    if (pitches.length < 7) return false;
    final last7 = pitches.sublist(pitches.length - 7);

    bool allIncreasing = true;
    bool allDecreasing = true;

    for (int i = 1; i < last7.length; i++) {
      if (last7[i] <= last7[i - 1]) allIncreasing = false;
      if (last7[i] >= last7[i - 1]) allDecreasing = false;
    }

    return allIncreasing || allDecreasing;
  }

  static double calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double calculateStdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = calculateMean(values);
    final sumSquares =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return _sqrt(sumSquares / (values.length - 1));
  }

  static double calculateCp(List<double> values, double ucl, double lcl) {
    final sigma = calculateStdDev(values);
    if (sigma == 0) return 0.0;
    return (ucl - lcl) / (6 * sigma);
  }

  static double calculateCpk(List<double> values, double ucl, double lcl) {
    final sigma = calculateStdDev(values);
    if (sigma == 0) return 0.0;
    final mean = calculateMean(values);
    final cpu = (ucl - mean) / (3 * sigma);
    final cpl = (mean - lcl) / (3 * sigma);
    return cpu < cpl ? cpu : cpl;
  }

  static int countOutOfControl(List<double> values, double ucl, double lcl) {
    return values.where((v) => v > ucl || v < lcl).length;
  }

  static bool isOutOfControl(double pitch,
      {double ucl = defaultUcl, double lcl = defaultLcl}) {
    return pitch > ucl || pitch < lcl;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
