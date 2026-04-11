// lib/screens/camera_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:typed_data';
import '../theme.dart';
import '../services/api_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  Stream<Uint8List>? _frameStream;
  bool _error = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final apiService = ref.read(apiServiceProvider);
    final streamUrl = apiService.cameraStreamUrl;
    setState(() {
      _error = false;
      _initializing = true;
      _frameStream = _mjpegStream(streamUrl);
    });
  }

  Stream<Uint8List> _mjpegStream(String url) async* {
    setState(() => _initializing = false);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      List<int> buffer = [];

      await for (final chunk in response) {
        buffer.addAll(chunk);
        int start = -1;
        for (int i = 0; i < buffer.length - 1; i++) {
          if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
            start = i;
          }
          if (start != -1 && buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
            yield Uint8List.fromList(buffer.sublist(start, i + 2));
            buffer = buffer.sublist(i + 2);
            start = -1;
            break;
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = true);
      }
    }
  }

  void _retry() {
    _initStream();
  }

  @override
  Widget build(BuildContext context) {
    final apiService = ref.watch(apiServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.9),
                AppTheme.failRed.withValues(alpha: 0.9),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: const Text('Caméra live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          _LiveBadge(error: _error),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Flux vidéo
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _error
                    ? _buildError()
                    : _frameStream == null || _initializing
                        ? _buildWaiting()
                        : StreamBuilder<Uint8List>(
                            stream: _frameStream,
                            builder: (context, snap) {
                              if (!snap.hasData) return _buildWaiting();
                              return Image.memory(
                                snap.data!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              );
                            },
                          ),
              ),
            ),
          ),

          // Barre infos bas
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const _InfoChip(label: 'SOURCE', value: 'Basler'),
                    _divider(),
                    const _InfoChip(label: 'FORMAT', value: 'MJPEG'),
                    _divider(),
                    const _InfoChip(label: 'FPS', value: '30'),
                    _divider(),
                    const _InfoChip(label: 'RÉSOL.', value: '1200px'),
                  ],
                ),
                const Divider(color: AppTheme.border, height: 16),
                Row(
                  children: [
                    const Icon(Icons.link,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        apiService.cameraStreamUrl,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.passGreen),
          SizedBox(height: 16),
          Text(
            'Connexion à la caméra...',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            'Vérifiez que api_server.py tourne',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 52, color: AppTheme.failRed),
          const SizedBox(height: 16),
          const Text(
            'Caméra non disponible',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'api_server.py non démarré\nou IP incorrecte',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _retry,
                child: const Text('Réessayer',
                    style: TextStyle(color: AppTheme.passGreen)),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('Paramètres',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 0.5, height: 28, color: AppTheme.border);
}

// Badge LIVE
class _LiveBadge extends StatefulWidget {
  final bool error;
  const _LiveBadge({required this.error});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.error ? AppTheme.failRed : AppTheme.passGreen;
    final bg = widget.error ? const Color(0xFF1A0707) : const Color(0xFF0F1A12);
    final border =
        widget.error ? const Color(0xFF3D0F0F) : const Color(0xFF1A3D22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          widget.error
              ? Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                )
              : FadeTransition(
                  opacity: _anim,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
          const SizedBox(width: 5),
          Text(
            widget.error ? 'OFF' : 'LIVE',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

// Info chip
class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppTheme.textSecondary,
            letterSpacing: 0.06,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
