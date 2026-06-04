import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/inspection_result.dart';
import 'api_service.dart';

class AnalysisRunResult {
  final InspectionResult inspection;
  final bool usedFallback;
  final String message;

  const AnalysisRunResult({
    required this.inspection,
    required this.usedFallback,
    required this.message,
  });
}

class AnalysisService {
  final ApiService _apiService;
  final http.Client _client;

  AnalysisService(this._apiService, {http.Client? client})
      : _client = client ?? http.Client();

  Future<AnalysisRunResult> analyzeNow({
    String? token,
    String? operatorId,
    String? pieceCode,
    String? lot,
    String mode = 'quick',
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    try {
      final jobId = await _startAnalysis(
        token: token,
        operatorId: operatorId,
        pieceCode: pieceCode,
        lot: lot,
        mode: mode,
      );
      final inspection = await _waitForResult(
        jobId: jobId,
        token: token,
        timeout: timeout,
        pollInterval: pollInterval,
      );

      return AnalysisRunResult(
        inspection: inspection,
        usedFallback: false,
        message: 'Analyse terminée avec succès.',
      );
    } on _AnalysisEndpointUnavailable {
      final fallback = await _fallbackLastInspection();
      return AnalysisRunResult(
        inspection: fallback,
        usedFallback: true,
        message:
            'Endpoints /analysis non disponibles. Affichage du dernier résultat.',
      );
    }
  }

  Future<AnalysisRunResult> analyzeFromFile({
    required File imageFile,
    String? token,
    String? operatorId,
    String? pieceCode,
    String? lot,
    String sourceType = 'gallery',
    String mode = 'quick',
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    try {
      final jobId = await _startAnalysisWithFile(
        imageFile: imageFile,
        token: token,
        operatorId: operatorId,
        pieceCode: pieceCode,
        lot: lot,
        sourceType: sourceType,
        mode: mode,
      );
      final inspection = await _waitForResult(
        jobId: jobId,
        token: token,
        timeout: timeout,
        pollInterval: pollInterval,
      );

      return AnalysisRunResult(
        inspection: inspection,
        usedFallback: false,
        message: 'Analyse terminée avec succès.',
      );
    } on _AnalysisEndpointUnavailable {
      final fallback = await _fallbackLastInspection();
      return AnalysisRunResult(
        inspection: fallback,
        usedFallback: true,
        message:
            'Endpoints /analysis non disponibles. Affichage du dernier résultat.',
      );
    }
  }

  Future<String> _startAnalysisWithFile({
    required File imageFile,
    String? token,
    String? operatorId,
    String? pieceCode,
    String? lot,
    String sourceType = 'gallery',
    String mode = 'quick',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_apiService.baseUrl}/analysis/upload'),
    );

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ),
    );

    request.fields['source_type'] = sourceType;
    request.fields['mode'] = mode;
    if (operatorId != null && operatorId.trim().isNotEmpty) {
      request.fields['operator_id'] = operatorId.trim();
    }
    if (pieceCode != null && pieceCode.trim().isNotEmpty) {
      request.fields['piece_code'] = pieceCode.trim();
    }
    if (lot != null && lot.trim().isNotEmpty) {
      request.fields['lot'] = lot.trim();
    }

    try {
      final response = await request.send().timeout(
            const Duration(seconds: 30),
          );

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 404) {
        throw _AnalysisEndpointUnavailable();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Échec téléchargement image (${response.statusCode}).',
        );
      }

      final data = jsonDecode(responseBody);
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Réponse analyse invalide');
      }

      final jobId = data['job_id']?.toString();
      if (jobId == null || jobId.isEmpty) {
        throw const ApiException('job_id manquant dans la réponse');
      }
      return jobId;
    } catch (e) {
      if (e is _AnalysisEndpointUnavailable) rethrow;
      throw ApiException('Erreur upload image: $e');
    }
  }

  Future<String> _startAnalysis({
    String? token,
    String? operatorId,
    String? pieceCode,
    String? lot,
    String mode = 'quick',
  }) async {
    final body = <String, dynamic>{
      'source_type': 'camera',
      'mode': mode,
    };
    if (operatorId != null && operatorId.trim().isNotEmpty) {
      body['operator_id'] = operatorId.trim();
    }
    if (pieceCode != null && pieceCode.trim().isNotEmpty) {
      body['piece_code'] = pieceCode.trim();
    }
    if (lot != null && lot.trim().isNotEmpty) {
      body['lot'] = lot.trim();
    }

    final response = await _client
        .post(
          Uri.parse('${_apiService.baseUrl}/analysis/start'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      throw _AnalysisEndpointUnavailable();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Échec démarrage analyse (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Réponse analyse invalide');
    }

    final jobId = data['job_id']?.toString();
    if (jobId == null || jobId.isEmpty) {
      throw const ApiException('job_id manquant dans la réponse');
    }
    return jobId;
  }

  Future<InspectionResult> _waitForResult({
    required String jobId,
    String? token,
    required Duration timeout,
    required Duration pollInterval,
  }) async {
    final startedAt = DateTime.now();

    while (DateTime.now().difference(startedAt) < timeout) {
      final statusResp = await _client
          .get(
            Uri.parse('${_apiService.baseUrl}/analysis/jobs/$jobId'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));

      if (statusResp.statusCode == 404) {
        throw _AnalysisEndpointUnavailable();
      }
      if (statusResp.statusCode >= 400) {
        throw ApiException(
          'Statut analyse indisponible (${statusResp.statusCode}).',
        );
      }

      final statusData = jsonDecode(statusResp.body);
      if (statusData is! Map<String, dynamic>) {
        throw const ApiException('Réponse statut invalide');
      }

      final status = (statusData['status']?.toString() ?? '').toLowerCase();

      if (status == 'done' || status == 'success' || status == 'completed') {
        return _fetchResult(jobId: jobId, token: token);
      }

      if (status == 'failed' || status == 'error') {
        final msg = statusData['error']?.toString() ?? 'Analyse en échec';
        throw ApiException(msg);
      }

      await Future.delayed(pollInterval);
    }

    throw const ApiException('Timeout analyse. Réessayez.');
  }

  Future<InspectionResult> _fetchResult({
    required String jobId,
    String? token,
  }) async {
    final response = await _client
        .get(
          Uri.parse('${_apiService.baseUrl}/analysis/jobs/$jobId/result'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      throw _AnalysisEndpointUnavailable();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Résultat analyse indisponible (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Résultat analyse invalide');
    }
    return InspectionResult.fromJson(data);
  }

  Future<InspectionResult> _fallbackLastInspection() async {
    final list = await _apiService.getLatestInspections(n: 1);
    if (list.isEmpty) {
      throw const ApiException('Aucun résultat d\'inspection disponible.');
    }
    return list.first;
  }

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void dispose() {
    _client.close();
  }
}

class _AnalysisEndpointUnavailable implements Exception {}

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final service = AnalysisService(apiService);
  ref.onDispose(service.dispose);
  return service;
});
