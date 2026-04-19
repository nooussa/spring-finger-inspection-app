// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspection_result.dart';

/// Utilisateur opérateur authentifié
class OperatorUser {
  final String login;
  final String? displayName;
  final String? role;
  final String? employeeId;

  const OperatorUser({
    required this.login,
    this.displayName,
    this.role,
    this.employeeId,
  });

  factory OperatorUser.fromJson(Map<String, dynamic> json) {
    return OperatorUser(
      login: json['login'] as String? ?? '',
      displayName: json['display_name'] as String?,
      role: json['role'] as String?,
      employeeId: json['employee_id']?.toString(),
    );
  }

  /// Vérifie si l'utilisateur est admin
  bool get isAdmin {
    const adminRoles = [
      'chef_ligne',
      'responsable',
      'superviseur',
      'manager',
      'admin'
    ];
    return adminRoles.contains(role?.toLowerCase());
  }
}

/// Service API pour communiquer avec le backend FastAPI
class ApiService {
  static const String _defaultBaseUrl = 'http://localhost:8000';
  static const String _baseUrlKey = 'api_base_url';

  String _baseUrl = _defaultBaseUrl;
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// URL de base actuelle
  String get baseUrl => _baseUrl;

  /// Initialise le service et charge l'URL sauvegardée
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  /// Définit et sauvegarde l'URL de base
  Future<void> setBaseUrl(String url) async {
    // Nettoyer l'URL
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }

    _baseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  /// Authentification - login
  /// POST /auth/login avec { login, password }
  /// Si l'API n'a pas de route auth, fait GET /health et accepte tout login non vide (mode dev)
  Future<(String, OperatorUser)> login({
    required String login,
    required String password,
  }) async {
    final trimmedLogin = login.trim();
    if (trimmedLogin.isEmpty || password.isEmpty) {
      throw const ApiException('Login ou mot de passe vide');
    }

    try {
      // Essayer d'abord POST /auth/login
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'login': trimmedLogin, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String? ??
            'token-${DateTime.now().millisecondsSinceEpoch}';
        final user = data['user'] != null
            ? OperatorUser.fromJson(data['user'] as Map<String, dynamic>)
            : OperatorUser(login: trimmedLogin);
        return (token, user);
      } else if (response.statusCode == 401) {
        throw const ApiException('Identifiants invalides');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      // Si l'endpoint n'existe pas, fallback sur /health
    }

    // Mode développement : tester connexion avec /health
    try {
      final healthResponse = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (healthResponse.statusCode == 200) {
        // API accessible, accepter le login en mode dev
        return (
          'dev-token-$trimmedLogin-${DateTime.now().millisecondsSinceEpoch}',
          OperatorUser(
              login: trimmedLogin, displayName: trimmedLogin, role: 'operator'),
        );
      }
    } catch (e) {
      throw ApiException('Serveur non accessible: $_baseUrl');
    }

    throw const ApiException('Impossible de se connecter au serveur');
  }

  /// Récupère les N dernières inspections
  /// GET /inspections/latest?n=n
  Future<List<InspectionResult>> getLatestInspections({int n = 20}) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/inspections/latest?n=$n'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .map((json) =>
                  InspectionResult.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        throw const ApiException('Format de réponse invalide');
      } else {
        throw ApiException(
            'Erreur ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on TimeoutException {
      throw const ApiException('Timeout: serveur non disponible');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur réseau: $e');
    }
  }

  /// Récupère les statistiques globales
  /// GET /stats
  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/stats'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
            'Erreur ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on TimeoutException {
      throw const ApiException('Timeout: serveur non disponible');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur réseau: $e');
    }
  }

  /// Vérifie la santé du serveur
  /// GET /health
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('Serveur non disponible (${response.statusCode})');
      }
    } on TimeoutException {
      throw const ApiException('Timeout: serveur non accessible');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur réseau: $e');
    }
  }

  /// URL du flux caméra live
  String get cameraStreamUrl => '$_baseUrl/camera/live';

  /// URL WebSocket live
  String get webSocketLiveUrl {
    final baseUri = Uri.parse(_baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

    final normalizedPath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final wsPath =
        normalizedPath.isEmpty ? '/ws/live' : '$normalizedPath/ws/live';

    return Uri(
      scheme: scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: wsPath,
    ).toString();
  }

  void dispose() {
    _client.close();
  }
}

/// Exception personnalisée pour les erreurs API
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Provider singleton pour ApiService
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  // Initialisation async - sera fait au premier accès
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider pour l'utilisateur authentifié
final authUserProvider = StateProvider<OperatorUser?>((ref) => null);

/// Provider pour le token d'authentification
final authTokenProvider = StateProvider<String?>((ref) => null);

/// Provider dérivé: l'utilisateur est-il connecté?
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authTokenProvider) != null;
});
