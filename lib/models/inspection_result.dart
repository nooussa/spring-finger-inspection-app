// lib/models/inspection_result.dart

/// Modèle représentant un résultat d'inspection PCB.
/// Correspond à la collection MongoDB "inspections".
class InspectionResult {
  final String id;
  final DateTime timestamp;
  final String verdict; // 'PASS' | 'FAIL'
  final int nbFingers;
  final double pitchMeanMm;
  final double totalWidthMm;
  final bool totalWidthOk;
  final int nOk;
  final int nMissing;
  final int nBent;
  final double mpp;
  final int nbAlertes;
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
    this.pitchMeanMm = 0.0,
    this.totalWidthMm = 0.0,
    this.totalWidthOk = true,
    this.nOk = 0,
    this.nMissing = 0,
    this.nBent = 0,
    this.mpp = 0.0,
    this.nbAlertes = 0,
    this.piece,
    this.operator,
    this.fingers = const [],
    this.defauts = const [],
    this.createdAt,
    this.imagePath,
  });

  /// Factory pour parser le JSON de l'API/MongoDB.
  /// Gère les deux formats d'ID (_id et id).
  factory InspectionResult.fromJson(Map<String, dynamic> json) {
    // Gestion _id / id (MongoDB retourne les deux)
    String extractId(Map<String, dynamic> j) {
      if (j['_id'] != null) {
        if (j['_id'] is Map && j['_id']['\$oid'] != null) {
          return j['_id']['\$oid'] as String;
        }
        return j['_id'].toString();
      }
      return j['id']?.toString() ?? '';
    }

    // Parse timestamp (peut être ISO string ou objet MongoDB)
    DateTime parseTimestamp(dynamic ts) {
      if (ts == null) return DateTime.now();
      if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
      if (ts is Map && ts['\$date'] != null) {
        return DateTime.tryParse(ts['\$date'].toString()) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return InspectionResult(
      id: extractId(json),
      timestamp: parseTimestamp(json['timestamp']),
      verdict: json['verdict']?.toString() ?? 'FAIL',
      nbFingers: (json['nb_fingers'] as num?)?.toInt() ?? 0,
      pitchMeanMm: (json['pitch_mean_mm'] as num?)?.toDouble() ?? 0.0,
      totalWidthMm: (json['total_width_mm'] as num?)?.toDouble() ?? 0.0,
      totalWidthOk: json['total_width_ok'] as bool? ?? true,
      nOk: (json['n_ok'] as num?)?.toInt() ?? 0,
      nMissing: (json['n_missing'] as num?)?.toInt() ?? 0,
      nBent: (json['n_bent'] as num?)?.toInt() ?? 0,
      mpp: (json['mpp'] as num?)?.toDouble() ?? 0.0,
      nbAlertes: (json['nb_alertes'] as num?)?.toInt() ?? 0,
      piece: json['piece'] != null
          ? InspectionPiece.fromJson(json['piece'] as Map<String, dynamic>)
          : null,
      operator: json['operator'] != null
          ? InspectionOperator.fromJson(
              json['operator'] as Map<String, dynamic>)
          : null,
      fingers: (json['fingers'] as List<dynamic>?)
              ?.map((f) => FingerData.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      defauts: (json['defauts'] as List<dynamic>?)
              ?.map((d) => DefautData.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: parseTimestamp(json['created_at']),
      imagePath: json['image_path'] as String?,
    );
  }

  bool get isPass => verdict == 'PASS';

  /// Obtenir le code de pièce ou l'ID par défaut
  String get displayName => piece?.pieceCode ?? id;
}

/// Données de pièce/lot
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

/// Données opérateur
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

/// Données d'un doigt individuel
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

/// Données d'un défaut détecté
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
