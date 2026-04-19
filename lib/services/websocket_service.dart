import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/inspection_result.dart';
import 'api_service.dart';

class LiveSocketPayload {
  final Map<String, dynamic> stats;
  final List<InspectionResult> inspections;
  final DateTime receivedAt;

  const LiveSocketPayload({
    required this.stats,
    required this.inspections,
    required this.receivedAt,
  });
}

class WebSocketService {
  final ApiService _apiService;
  final StreamController<LiveSocketPayload> _controller =
      StreamController<LiveSocketPayload>.broadcast();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String? _activeToken;
  bool _connecting = false;
  bool _disposed = false;

  WebSocketService(this._apiService);

  Stream<LiveSocketPayload> stream({String? token}) {
    if (_activeToken != token) {
      _activeToken = token;
      _reconnectNow();
    } else {
      _ensureConnected();
    }
    return _controller.stream;
  }

  void _ensureConnected() {
    if (_disposed || _connecting || _channel != null) {
      return;
    }

    _connecting = true;

    final wsUrl = _activeToken == null || _activeToken!.isEmpty
        ? _apiService.webSocketLiveUrl
        : '${_apiService.webSocketLiveUrl}?token=${Uri.encodeComponent(_activeToken!)}';

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;

      channel.stream.listen(
        (message) {
          final payload = _parseMessage(message);
          if (payload != null && !_controller.isClosed) {
            _controller.add(payload);
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  LiveSocketPayload? _parseMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final stats = decoded['stats'];
      final inspectionsRaw = decoded['inspections'];

      if (stats is! Map<String, dynamic> || inspectionsRaw is! List) {
        return null;
      }

      final inspections = inspectionsRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(InspectionResult.fromJson)
          .toList();

      return LiveSocketPayload(
        stats: stats,
        inspections: inspections,
        receivedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  void _scheduleReconnect() {
    _channel?.sink.close();
    _channel = null;

    if (_disposed) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _ensureConnected);
  }

  void _reconnectNow() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _ensureConnected();
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _controller.close();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final service = WebSocketService(apiService);
  ref.onDispose(service.dispose);
  return service;
});
