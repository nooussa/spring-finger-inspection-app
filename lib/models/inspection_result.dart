


class InspectionResult {
  final String id;
  final DateTime timestamp;
  final String verdict; // 'PASS' | 'FAIL'
  final int nbFingers;
  final List<double> pitchesMm;
  final List<bool> pitchesOk;
  final double pitchMeanMm;
  final double totalWidthMm;
  final bool totalWidthOk;
  final int nOk;
  final int nMissing;
  final int nBent;
  final double mpp;
  final int nbAlertes;
  final List<String> causes;
  final List<String> alerts;
  final InspectionPiece? piece;
  final InspectionOperator? operator;
  final List<FingerData> fingers;
  final List<DefautData> defauts;
  final DateTime? createdAt;
  final String? imagePath;

  const InspectionResult({
    required this.id,
    required this.timestamp,
    required this.verdict,
    this.nbFingers = 0,
    this.pitchesMm = const [],
    this.pitchesOk = const [],
    this.pitchMeanMm = 0.0,
    this.totalWidthMm = 0.0,
    this.totalWidthOk = true,
    this.nOk = 0,
    this.nMissing = 0,
    this.nBent = 0,
    this.mpp = 0.0,
    this.nbAlertes = 0,
    this.causes = const [],
    this.alerts = const [],
    this.piece,
    this.operator,
    this.fingers = const [],
    this.defauts = const [],
    this.createdAt,
    this.imagePath,
  });


  factory InspectionResult.fromJson(Map<String, dynamic> json) {

    String extractId(Map<String, dynamic> j) {
      if (j['_id'] != null) {
        if (j['_id'] is Map && j['_id']['\$oid'] != null) {
          return j['_id']['\$oid'] as String;
        }
        return j['_id'].toString();
      }
      return j['id']?.toString() ?? '';
    }

    DateTime parseTimestamp(dynamic ts) {
      if (ts == null) return DateTime.now();
      if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
      if (ts is Map && ts['\$date'] != null) {
        return DateTime.tryParse(ts['\$date'].toString()) ?? DateTime.now();
      }
      return DateTime.now();
    }

    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    List<double> parseDoubleList(dynamic value) {
      if (value is List) {
        return value.map(parseDouble).whereType<double>().toList();
      }
      return [];
    }

    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    bool? parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == 'yes') return true;
        if (normalized == 'false' || normalized == 'no') return false;
      }
      return null;
    }

    List<bool> parseBoolList(dynamic value) {
      if (value is List) {
        return value.map(parseBool).whereType<bool>().toList();
      }
      return [];
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value
            .map((v) => v?.toString())
            .whereType<String>()
            .where((v) => v.trim().isNotEmpty)
            .toList();
      }
      return [];
    }

    final mesures = json['mesures'] is Map<String, dynamic>
        ? json['mesures'] as Map<String, dynamic>
        : <String, dynamic>{};
    final qualityReport = json['quality_report'] is Map<String, dynamic>
        ? json['quality_report'] as Map<String, dynamic>
        : <String, dynamic>{};

    var pitchesMm = parseDoubleList(
      json['pitches_mm'] ?? mesures['pitches_mm'],
    );
    var pitchesOk = parseBoolList(
      json['pitches_ok'] ?? mesures['pitches_ok'],
    );
    final alerts = parseStringList(
      json['alertes'] ??
          json['alerts'] ??
          qualityReport['alertes'] ??
          qualityReport['alerts'],
    );
    final causes = parseStringList(
      json['causes'] ?? json['raisons'] ?? json['reasons'],
    );

    if (pitchesMm.isEmpty) {
      final criteres = qualityReport['criteres'];
      if (criteres is Map<String, dynamic>) {
        final pitchCrit = criteres['pitches'];
        if (pitchCrit is Map<String, dynamic> && pitchCrit['details'] is List) {
          final details = pitchCrit['details'] as List;
          pitchesMm = details
              .map((d) => d is Map<String, dynamic>
                  ? parseDouble(d['valeur_mm'])
                  : null)
              .whereType<double>()
              .toList();
          if (pitchesOk.isEmpty) {
            pitchesOk = details
                .map((d) =>
                    d is Map<String, dynamic> ? parseBool(d['ok']) : null)
                .whereType<bool>()
                .toList();
          }
        }
      }
    }

    final fingers = (json['fingers'] as List<dynamic>?)
            ?.map((f) => FingerData.fromJson(f as Map<String, dynamic>))
            .toList() ??
        [];

    if (pitchesMm.isEmpty && fingers.isNotEmpty) {
      final firstThreeFingers = fingers.take(3).toList();
      if (firstThreeFingers.any((finger) => finger.missing)) {
        pitchesMm = [];
        pitchesOk = [];
      } else {
        pitchesMm = firstThreeFingers.map((finger) => finger.pitchMm).toList();
        pitchesOk = firstThreeFingers.map((finger) => finger.pitchOk).toList();
      }
    }

    return InspectionResult(
      id: extractId(json),
      timestamp: parseTimestamp(json['timestamp']),
      verdict: json['verdict']?.toString() ?? 'FAIL',
      nbFingers: parseInt(json['nb_fingers']) ?? 0,
      pitchesMm: pitchesMm,
      pitchesOk: pitchesOk,
      pitchMeanMm: parseDouble(json['pitch_mean_mm']) ??
          parseDouble(mesures['pitch_mean_mm']) ??
          0.0,
      totalWidthMm: parseDouble(json['total_width_mm']) ??
          parseDouble(mesures['total_width_mm']) ??
          0.0,
      totalWidthOk: parseBool(json['total_width_ok']) ??
          parseBool(mesures['total_width_ok']) ??
          true,
      nOk: parseInt(json['n_ok']) ?? 0,
      nMissing: parseInt(json['n_missing']) ?? 0,
      nBent: parseInt(json['n_bent']) ?? 0,
      mpp: parseDouble(json['mpp']) ?? parseDouble(mesures['mpp']) ?? 0.0,
      nbAlertes: parseInt(json['nb_alertes']) ?? 0,
      causes: causes,
      alerts: alerts,
      piece: json['piece'] != null
          ? InspectionPiece.fromJson(json['piece'] as Map<String, dynamic>)
          : null,
      operator: json['operator'] != null
          ? InspectionOperator.fromJson(
              json['operator'] as Map<String, dynamic>)
          : null,
        fingers: fingers,
      defauts: (json['defauts'] as List<dynamic>?)
              ?.map((d) => DefautData.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: parseTimestamp(json['created_at']),
      imagePath: json['image_path'] as String?,
    );
  }

  bool get isPass => verdict == 'PASS';

  String get displayName => piece?.pieceCode ?? id;
}

class InspectionPiece {
  final String? pieceCode;
  final String? lot;

  const InspectionPiece({this.pieceCode, this.lot});

  factory InspectionPiece.fromJson(Map<String, dynamic> json) {
    return InspectionPiece(
      pieceCode: json['piece_code'] as String?,
      lot: json['lot'] as String?,
    );
  }
}

class InspectionOperator {
  final String? operatorId;
  final String? login;
  final String? displayName;
  final String? role;

  const InspectionOperator({
    this.operatorId,
    this.login,
    this.displayName,
    this.role,
  });

  factory InspectionOperator.fromJson(Map<String, dynamic> json) {
    return InspectionOperator(
      operatorId: json['operator_id']?.toString(),
      login: json['login'] as String?,
      displayName: json['display_name'] as String?,
      role: json['role'] as String?,
    );
  }
}

class FingerData {
  final int fingerNum;
  final double pitchMm;
  final bool pitchOk;
  final double offsetMm;
  final double heightMm;
  final double tiltDeg;
  final bool tiltOk;
  final bool missing;
  final bool bent;
  final double yoloConf;

  const FingerData({
    required this.fingerNum,
    this.pitchMm = 0.0,
    this.pitchOk = true,
    this.offsetMm = 0.0,
    this.heightMm = 0.0,
    this.tiltDeg = 0.0,
    this.tiltOk = true,
    this.missing = false,
    this.bent = false,
    this.yoloConf = 0.0,
  });

  factory FingerData.fromJson(Map<String, dynamic> json) {
    return FingerData(
      fingerNum: (json['finger_num'] as num?)?.toInt() ?? 0,
      pitchMm: (json['pitch_mm'] as num?)?.toDouble() ?? 0.0,
      pitchOk: json['pitch_ok'] as bool? ?? true,
      offsetMm: (json['offset_mm'] as num?)?.toDouble() ?? 0.0,
      heightMm: (json['height_mm'] as num?)?.toDouble() ?? 0.0,
      tiltDeg: (json['tilt_deg'] as num?)?.toDouble() ?? 0.0,
      tiltOk: json['tilt_ok'] as bool? ?? true,
      missing: json['missing'] as bool? ?? false,
      bent: json['bent'] as bool? ?? false,
      yoloConf: (json['yolo_conf'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DefautData {
  final int fingerNum;
  final String typeDefaut;
  final String description;
  final double valeurMm;
  final double ecartMm;

  const DefautData({
    required this.fingerNum,
    required this.typeDefaut,
    this.description = '',
    this.valeurMm = 0.0,
    this.ecartMm = 0.0,
  });

  factory DefautData.fromJson(Map<String, dynamic> json) {
    return DefautData(
      fingerNum: (json['finger_num'] as num?)?.toInt() ?? 0,
      typeDefaut: json['type_defaut'] as String? ?? '',
      description: json['description'] as String? ?? '',
      valeurMm: (json['valeur_mm'] as num?)?.toDouble() ?? 0.0,
      ecartMm: (json['ecart_mm'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
