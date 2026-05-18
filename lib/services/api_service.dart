// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  Map<String, dynamic> toJson() {
    return {
      'login': login,
      'display_name': displayName,
      'role': role,
      'employee_id': employeeId,
    };
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
  // Remplacer par l'IP LAN du PC qui exécute FastAPI.
  // Exemple: http://192.168.1.87:8000
  static const String _defaultBaseUrl = 'http://192.168.1.87:8000';
  static const String _baseUrlKey = 'api_base_url';
  static const String _authTokenKey = 'auth_token';
  static const String _authUserKey = 'auth_user';

  String _baseUrl = _defaultBaseUrl;
  final http.Client _client;
  Future<void>? _initFuture;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// URL de base actuelle
  String get baseUrl => _baseUrl;

  /// Initialise le service et charge l'URL sauvegardée
  Future<void> init() {
    _initFuture ??= _loadPrefs();
    return _initFuture!;
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_baseUrlKey);
    _baseUrl = _normalizeBaseUrl(savedUrl) ?? _defaultBaseUrl;
  }

  /// Définit et sauvegarde l'URL de base
  Future<void> setBaseUrl(String url) async {
    final cleanUrl = _normalizeBaseUrl(url);
    if (cleanUrl == null) {
      throw const ApiException('URL serveur invalide');
    }

    _baseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  String? _normalizeBaseUrl(String? url) {
    if (url == null) {
      return null;
    }

    var cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      return null;
    }

    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }

    return cleanUrl;
  }

  Future<void> saveAuth({
    required String token,
    required OperatorUser user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    await prefs.setString(_authUserKey, jsonEncode(user.toJson()));
  }

  Future<(String?, OperatorUser?)> loadAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey);
    final userJson = prefs.getString(_authUserKey);
    OperatorUser? user;
    if (userJson != null) {
      try {
        final data = jsonDecode(userJson) as Map<String, dynamic>;
        user = OperatorUser.fromJson(data);
      } catch (_) {
        user = null;
      }
    }
    return (token, user);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_authUserKey);
  }

  /// Garantit une URL de base valide.
  Future<String?> ensureBaseUrl({
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    await init();
    // Try a set of candidate base URLs and pick the first healthy one.
    final candidates = <String>[];

    // Start with the currently configured base URL
    candidates.add(_baseUrl);

    // Common local addresses to try when running on emulator or device
    if (!candidates.contains('http://127.0.0.1:8000')) {
      candidates.add('http://127.0.0.1:8000');
    }
    if (!candidates.contains('http://localhost:8000')) {
      candidates.add('http://localhost:8000');
    }

    // Android emulator maps host machine localhost to 10.0.2.2
    try {
      if (Platform.isAndroid) {
        const emulatorHost = 'http://10.0.2.2:8000';
        if (!candidates.contains(emulatorHost)) candidates.add(emulatorHost);
      }
    } catch (_) {
      // Platform may not be available in some contexts; ignore.
    }

    // Finally try the hardcoded default (useful for saved legacy configs)
    if (!candidates.contains(_defaultBaseUrl)) candidates.add(_defaultBaseUrl);

    for (final candidate in candidates) {
      if (await _isHealthy(candidate, timeout)) {
        _baseUrl = candidate;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_baseUrlKey, _baseUrl);
        return _baseUrl;
      }
    }

    return null;
  }

  Future<bool> _isHealthy(String baseUrl, Duration timeout) async {
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/health')).timeout(timeout);
      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } on FormatException {
      return false;
    }
  }

  // Public pour les tests de connexion
  Future<bool> testConnection(String baseUrl) =>
      _isHealthy(baseUrl, const Duration(seconds: 5));

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

  Map<String, String> _authorizedHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getOperators({
    required String token,
  }) async {
    return _getAdminList('/admin/operators', token);
  }

  Future<List<Map<String, dynamic>>> getEmployees({
    required String token,
  }) async {
    return _getAdminList('/admin/employees', token);
  }

  Future<List<Map<String, dynamic>>> _getAdminList(
    String path,
    String token,
  ) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Erreur ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      throw const ApiException('Format de réponse invalide');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur réseau: $e');
    }
  }

  Future<Map<String, dynamic>> addEmployee({
    required String token,
    required String empId,
    required String name,
    required String poste,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/admin/employees'),
            headers: _authorizedHeaders(token),
            body: jsonEncode({
              'emp_id': empId,
              'name': name,
              'poste': poste,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Erreur ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw const ApiException('Format de réponse invalide');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur réseau: $e');
    }
  }

  Future<void> deleteOperator({
    required String token,
    required String operatorId,
  }) async {
    await _simpleAdminCall(
      method: 'DELETE',
      path: '/admin/operators/$operatorId',
      token: token,
    );
  }

  Future<void> resetPassword({
    required String token,
    required String operatorId,
    required String newPassword,
  }) async {
    await _simpleAdminCall(
      method: 'PUT',
      path: '/admin/operators/$operatorId/password',
      token: token,
      body: {'new_password': newPassword},
    );
  }

  Future<void> deactivateEmployee({
    required String token,
    required String employeeId,
  }) async {
    await _simpleAdminCall(
      method: 'PUT',
      path: '/admin/employees/$employeeId/deactivate',
      token: token,
    );
  }

  Future<void> _simpleAdminCall({
    required String method,
    required String path,
    required String token,
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      late http.Response response;
      final headers = _authorizedHeaders(token);
      if (method == 'DELETE') {
        response = await _client
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 10));
      } else if (method == 'PUT') {
        response = await _client
            .put(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 10));
      } else {
        response = await _client
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final msg = response.body.trim();
        throw ApiException(msg.isNotEmpty
            ? msg
            : 'Erreur ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur réseau: $e');
    }
  }

  /// Changer le mot de passe de l'utilisateur connecté
  /// POST /auth/change-password
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      throw const ApiException('Mot de passe manquant');
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return;
      }

      if (response.statusCode == 401) {
        throw const ApiException('Non autorisé. Reconnectez-vous.');
      }

      if (response.statusCode == 404) {
        throw const ApiException(
            'Endpoint changement mot de passe indisponible');
      }

      throw ApiException(
        'Erreur ${response.statusCode}: ${response.reasonPhrase}',
      );
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

  /// Tentative de détection / statut Arduino côté backend.
  /// Tente plusieurs endpoints communs et renvoie un message lisible.
  Future<String> detectArduino(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final candidates = [
      '/arduino/detect',
      '/arduino/status',
      '/uart/detect',
      '/uart/status',
    ];

    for (final p in candidates) {
      final uri = Uri.parse('$_baseUrl$p');
      try {
        final resp = await _client.get(uri).timeout(timeout);
        if (resp.statusCode == 200) {
          final body = resp.body.trim();
          if (body.isEmpty) {
            return 'Arduino détecté';
          }

          try {
            final data = jsonDecode(body);
            if (data is Map<String, dynamic>) {
              if (data['success'] == true) {
                final port = data['port']?.toString().trim();
                if (port != null && port.isNotEmpty) {
                  return port;
                }
                final message = data['message']?.toString().trim();
                if (message != null && message.isNotEmpty) {
                  return message;
                }
                return 'Arduino détecté';
              }

              final error = data['error']?.toString().trim();
              if (error != null && error.isNotEmpty) {
                throw ApiException(error);
              }
            }
          } catch (_) {
            // Fallback texte brut.
          }

          return body;
        }
        // 404 means endpoint not present — try next
        if (resp.statusCode == 404) continue;
      } catch (_) {
        // ignore and try next
        continue;
      }
    }

    throw const ApiException('Endpoint Arduino indisponible sur le serveur');
  }

  /// Envoie un verdict PASS/FAIL au backend pour relais UART.
  Future<bool> sendArduinoVerdict(String verdict) async {
    final normalized = verdict.trim().toUpperCase();
    if (normalized != 'PASS' && normalized != 'FAIL') {
      return false;
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/arduino/verdict'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'verdict': normalized}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final body = response.body.trim();
      if (body.isEmpty) {
        return false;
      }

      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
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
