// lib/screens/camera_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inspection_result.dart';
import '../providers/analysis_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

enum _CameraSource { idle, live, photo, gallery }

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  // Lot par défaut vide — l'utilisateur saisira le lot manuellement.
  static const String _defaultLotCode = '';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _lotController = TextEditingController();

  Stream<Uint8List>? _liveStream;
  Timer? _clockTimer;
  Uint8List? _latestLiveFrame;

  late final AnimationController _liveBlinkController;
  late final Animation<double> _liveBlinkOpacity;

  bool _cameraConnected = false;
  bool _cameraTesting = false;
  bool _liveOn = false;
  bool _liveAnalyzeOn = false;
  bool _arduinoDetected = false;
  String? _arduinoPortLabel;
  String _arduinoStatusText = 'Arduino: not detected';
  Color _arduinoStatusColor = AppTheme.warnOrange;
  IconData _arduinoStatusIcon = Icons.usb_off_outlined;
  Timer? _arduinoStatusResetTimer;
  Timer? _liveAnalyzeTimer;
  bool _liveStreamError = false;
  bool _pieceWasSaved = false;
  String? _lastLiveVerdictSent;
  int _lotLookupToken = 0;

  _CameraSource _source = _CameraSource.idle;
  File? _localImage;
  String? _annotatedImageUrl;
  String _clockText = '';
  int _pieceCounter = 1;
  String _lotCode = _defaultLotCode;

  @override
  void initState() {
    super.initState();
    _clockText = _formatClock(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _clockText = _formatClock(DateTime.now()));
    });

    _liveBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _liveBlinkOpacity =
        Tween<double>(begin: 0.25, end: 1.0).animate(_liveBlinkController);

    Future.microtask(() => _restorePieceCounterForLot(_lotCode));
  }

  @override
  void dispose() {
    _liveAnalyzeTimer?.cancel();
    _lotController.dispose();
    _clockTimer?.cancel();
    _arduinoStatusResetTimer?.cancel();
    _liveBlinkController.dispose();
    super.dispose();
  }

  String _formatClock(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String get _activeLotName =>
      _lotCode.isEmpty ? 'Lot (non défini)' : 'Lot $_lotCode';

  String get _currentPieceCode =>
      _lotCode.isEmpty ? '$_pieceCounter' : '$_lotCode.$_pieceCounter';

  Future<void> _handleLotChanged(String value) async {
    final lot = value.trim();
    final nextLot = lot.isEmpty ? _defaultLotCode : lot;

    setState(() {
      _lotCode = nextLot;
      _pieceCounter = 1;
    });

    await _restorePieceCounterForLot(nextLot);
  }

  Future<void> _restorePieceCounterForLot(String lot) async {
    final normalizedLot = lot.trim();
    if (normalizedLot.isEmpty) return;

    final token = ++_lotLookupToken;
    int nextCounter = 1;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSaved = prefs.getInt('last_piece_counter_$normalizedLot');
      if (lastSaved != null && lastSaved > 0) {
        nextCounter = lastSaved + 1;
      }
    } catch (_) {}

    try {
      final api = ref.read(apiServiceProvider);
      final inspections = await api.getLatestInspections(n: 200);
      var maxCounter = 0;
      for (final inspection in inspections) {
        final pieceCode = inspection.piece?.pieceCode?.trim();
        if (pieceCode == null || !pieceCode.startsWith('$normalizedLot.')) {
          continue;
        }
        final suffix = pieceCode.substring(pieceCode.lastIndexOf('.') + 1);
        final counter = int.tryParse(suffix);
        if (counter != null && counter > maxCounter) {
          maxCounter = counter;
        }
      }
      if (maxCounter > 0) {
        nextCounter = maxCounter + 1;
      }
    } catch (_) {
      // Keep the local fallback value.
    }

    if (!mounted || token != _lotLookupToken) return;
    setState(() {
      _lotCode = normalizedLot.isEmpty ? _defaultLotCode : normalizedLot;
      _pieceCounter = nextCounter;
      // Only update the controller text when we have a non-empty lot code.
      if (normalizedLot.isNotEmpty && _lotController.text != _lotCode) {
        _lotController.value = TextEditingValue(
          text: _lotCode,
          selection: TextSelection.collapsed(offset: _lotCode.length),
        );
      }
    });
  }

  Future<void> _persistPieceCounterForLot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_piece_counter_$_lotCode', _pieceCounter);
    } catch (_) {}
  }

  String _inspectionImageUrl(InspectionResult result) {
    final api = ref.read(apiServiceProvider);
    return '${api.baseUrl}/inspections/${result.id}/image';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setArduinoNotDetected() {
    if (!mounted) return;
    _arduinoStatusResetTimer?.cancel();
    setState(() {
      _arduinoPortLabel = null;
      _arduinoStatusText = 'Arduino: not detected';
      _arduinoStatusColor = AppTheme.warnOrange;
      _arduinoStatusIcon = Icons.usb_off_outlined;
    });
  }

  void _setArduinoConnected(String portText) {
    if (!mounted) return;
    _arduinoStatusResetTimer?.cancel();
    setState(() {
      _arduinoPortLabel = portText.trim();
      _arduinoStatusText = 'Arduino: connected — $_arduinoPortLabel';
      _arduinoStatusColor = AppTheme.passGreen;
      _arduinoStatusIcon = Icons.usb_outlined;
    });
  }

  void _flashArduinoVerdictSent() {
    if (!mounted) return;
    if (!_arduinoDetected) return;

    _arduinoStatusResetTimer?.cancel();
    setState(() {
      _arduinoStatusText = 'Arduino: verdict sent';
      _arduinoStatusColor = AppTheme.passGreen;
      _arduinoStatusIcon = Icons.check_circle_outline;
    });

    _arduinoStatusResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        final port = _arduinoPortLabel;
        if (port != null && port.isNotEmpty) {
          _arduinoStatusText = 'Arduino: connected — $port';
          _arduinoStatusColor = AppTheme.passGreen;
          _arduinoStatusIcon = Icons.usb_outlined;
        } else {
          _arduinoStatusText = 'Arduino: not detected';
          _arduinoStatusColor = AppTheme.warnOrange;
          _arduinoStatusIcon = Icons.usb_off_outlined;
        }
      });
    });
  }

  void _resetAnalysisPreview() {
    _annotatedImageUrl = null;
    ref.read(analysisControllerProvider.notifier).reset();
  }

  void _advancePieceIfNeeded() {
    if (_pieceWasSaved) {
      _pieceWasSaved = false;
    }
  }

  void _stopLive({bool keepConnection = true}) {
    _liveAnalyzeTimer?.cancel();
    _liveAnalyzeTimer = null;
    _liveOn = false;
    _liveAnalyzeOn = false;
    _liveStream = null;
    _liveStreamError = false;
    _lastLiveVerdictSent = null;
    _latestLiveFrame = null;
    if (!keepConnection) {
      _cameraConnected = false;
    }
    if (_source == _CameraSource.live) {
      _source = _CameraSource.idle;
    }
    if (mounted) setState(() {});
  }

  Future<void> _probeCameraConnection() async {
    final api = ref.read(apiServiceProvider);
    final url = api.cameraFrameUrl;

    setState(() {
      _cameraTesting = true;
      _liveStreamError = false;
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(url));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      client.close(force: true);

      if (!mounted) return;
      setState(() {
        _cameraConnected = ok;
      });

      if (ok) {
        _startLive();
      }

      _showMessage(
          ok ? 'Caméra connectée et flux lancé' : 'Caméra non disponible');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraConnected = false;
      });
      _showMessage('Impossible de connecter la caméra');
    } finally {
      if (mounted) {
        setState(() => _cameraTesting = false);
      }
    }
  }

  static int _indexOfJpegStart(List<int> data) {
    for (var i = 0; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD8) {
        return i;
      }
    }
    return -1;
  }

  static int _indexOfJpegEnd(List<int> data, int start) {
    for (var i = start; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD9) {
        return i;
      }
    }
    return -1;
  }

  Stream<Uint8List> _mjpegStream(String url) async* {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      while (mounted && _liveOn) {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Flux caméra indisponible (${response.statusCode})');
        }

        final buffer = <int>[];
        await for (final chunk in response) {
          buffer.addAll(chunk);
          while (true) {
            final start = _indexOfJpegStart(buffer);
            if (start == -1) {
              if (buffer.length > 1) {
                buffer.removeRange(0, buffer.length - 1);
              }
              break;
            }
            if (start > 0) {
              buffer.removeRange(0, start);
            }
            final end = _indexOfJpegEnd(buffer, 2);
            if (end == -1) {
              break;
            }
            final frame = Uint8List.fromList(buffer.sublist(0, end + 2));
            buffer.removeRange(0, end + 2);
            if (frame.isNotEmpty) {
              yield frame;
            }
          }
        }

        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveStreamError = true;
          _cameraConnected = false;
        });
      }
    } finally {
      client.close(force: true);
    }
  }

  void _startLive() {
    final api = ref.read(apiServiceProvider);
    ref.read(analysisControllerProvider.notifier).reset();
    setState(() {
      _source = _CameraSource.live;
      _localImage = null;
      _annotatedImageUrl = null;
      _liveStreamError = false;
      _liveOn = true;
      _liveStream = _mjpegStream(api.cameraStreamUrl);
      _cameraConnected = true;
      _pieceWasSaved = false;
      _lastLiveVerdictSent = null;
      _latestLiveFrame = null;
    });
  }

  void _startLiveAnalyzeLoop() {
    _liveAnalyzeTimer?.cancel();
    _liveAnalyzeTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_liveOn || !_liveAnalyzeOn) {
        return;
      }
      final analysisState = ref.read(analysisControllerProvider);
      if (analysisState.phase == AnalysisPhase.running) {
        return;
      }
      if (_latestLiveFrame == null) {
        return;
      }
      await _analyzeLiveFrame();
    });
  }

  void _toggleLiveAnalyze() {
    if (!_liveOn) {
      _showMessage('Activez d’abord le mode live caméra');
      return;
    }

    setState(() {
      _liveAnalyzeOn = !_liveAnalyzeOn;
    });

    if (_liveAnalyzeOn) {
      _startLiveAnalyzeLoop();
      _showMessage('Analyse live activée');
    } else {
      _liveAnalyzeTimer?.cancel();
      _liveAnalyzeTimer = null;
      _showMessage('Analyse live arrêtée');
    }
  }

  void _toggleLive() {
    if (_liveOn) {
      if (_source == _CameraSource.live) {
        setState(() {
          _annotatedImageUrl = null;
          _latestLiveFrame = null;
        });
      }
      return;
    }
    _startLive();
  }

  Future<void> _pickAndAnalyze(
      ImageSource source, _CameraSource cameraSource) async {
    final pickedFile =
        await _picker.pickImage(source: source, imageQuality: 95);
    if (pickedFile == null || !mounted) return;

    _advancePieceIfNeeded();
    _stopLive();
    ref.read(analysisControllerProvider.notifier).reset();

    setState(() {
      _source = cameraSource;
      _localImage = File(pickedFile.path);
      _annotatedImageUrl = null;
      _pieceWasSaved = false;
    });
  }

  Future<void> _pickCapture() async {
    await _pickAndAnalyze(ImageSource.camera, _CameraSource.photo);
  }

  Future<void> _pickGallery() async {
    await _pickAndAnalyze(ImageSource.gallery, _CameraSource.gallery);
  }

  Future<void> _analyzeCurrent() async {
    final analysisState = ref.read(analysisControllerProvider);
    if (analysisState.phase == AnalysisPhase.running) return;

    if (_liveOn) {
      await _analyzeLiveFrame();
      return;
    }

    final token = ref.read(authTokenProvider);

    if (_localImage != null) {
      await ref.read(analysisControllerProvider.notifier).runFromFile(
            imageFile: _localImage!,
            token: token,
          );
      await _syncAfterAnalysis(fromLive: false);
      return;
    }

    if (_cameraConnected) {
      await ref.read(analysisControllerProvider.notifier).run(token: token);
      await _syncAfterAnalysis(fromLive: false, fromCamera: true);
      return;
    }

    _showMessage('Capture or open an image first');
  }

  Future<void> _analyzeLiveFrame() async {
    final frame = _latestLiveFrame;
    if (frame == null) {
      _showMessage('Capture or open an image first');
      return;
    }

    _advancePieceIfNeeded();

    final tempFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}pcb_live_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(frame, flush: true);

    try {
      final token = ref.read(authTokenProvider);
      await ref.read(analysisControllerProvider.notifier).runFromFile(
            imageFile: tempFile,
            token: token,
          );
      await _syncAfterAnalysis(fromLive: true);
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _syncAfterAnalysis({
    required bool fromLive,
    bool fromCamera = false,
  }) async {
    if (!mounted) return;

    final state = ref.read(analysisControllerProvider);
    if (state.phase != AnalysisPhase.success || state.result == null) {
      return;
    }

    final result = state.result!;
    _pieceWasSaved = true;

    if (fromCamera && _source == _CameraSource.idle) {
      _source = _CameraSource.photo;
    }

    if (fromLive) {
      _source = _CameraSource.live;
    }

    setState(() {
      _annotatedImageUrl = _inspectionImageUrl(result);
    });

    await _persistPieceCounterForLot();

    if (mounted) {
      setState(() {
        _pieceCounter += 1;
        _pieceWasSaved = true;
      });
    }

    await _sendArduinoVerdictIfNeeded(result.verdict, fromLive: fromLive);
  }

  Future<void> _sendArduinoVerdictIfNeeded(
    String verdict, {
    required bool fromLive,
  }) async {
    if (!_arduinoDetected) return;

    final normalizedVerdict = verdict.trim().toUpperCase();
    if (normalizedVerdict != 'PASS' && normalizedVerdict != 'FAIL') {
      return;
    }

    if (fromLive) {
      if (_lastLiveVerdictSent == normalizedVerdict) {
        return;
      }
    }

    final api = ref.read(apiServiceProvider);
    final sent = await api.sendArduinoVerdict(normalizedVerdict);
    if (!mounted) return;

    if (sent) {
      if (fromLive) {
        _lastLiveVerdictSent = normalizedVerdict;
      }
      _flashArduinoVerdictSent();
      return;
    }

    _setArduinoNotDetected();
  }

  Future<void> _detectArduino() async {
    final api = ref.read(apiServiceProvider);
    try {
      final msg = await api.detectArduino();
      if (!mounted) return;
      setState(() => _arduinoDetected = true);
      _setArduinoConnected(msg);
      _showMessage(msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _arduinoDetected = false);
      _setArduinoNotDetected();
      _showMessage(e.toString());
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _stopLive(keepConnection: false);
    ref.read(analysisControllerProvider.notifier).reset();

    ref.read(authTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;
    final api = ref.read(apiServiceProvider);
    await api.clearAuth();

    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiServiceProvider);
    final analysisState = ref.watch(analysisControllerProvider);
    final isAnalyzing = analysisState.phase == AnalysisPhase.running;
    final verdictBarColor = analysisState.result == null
        ? const Color(0xFFC9D2DC)
        : analysisState.result!.isPass
            ? AppTheme.passGreen
            : AppTheme.failRed;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.92),
                AppTheme.failRed.withValues(alpha: 0.92),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Row(
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.precision_manufacturing_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'PCB Inspector',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _currentPieceCode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _activeLotName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _cameraConnected
                                    ? AppTheme.passGreen
                                    : AppTheme.warnOrange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _clockText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 3, color: verdictBarColor),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImageZone(
                source: _source,
                liveOn: _liveOn,
                liveStreamError: _liveStreamError,
                liveBlinkOpacity: _liveBlinkOpacity,
                liveStream: _liveStream,
                localImage: _localImage,
                annotatedImageUrl: _annotatedImageUrl,
                onLiveFrame: (frame) => _latestLiveFrame = frame,
                onCameraLive: _toggleLive,
                onCapture: _pickCapture,
                onGallery: _pickGallery,
                onOpenResult: analysisState.result == null
                    ? null
                    : () => context.push('/image', extra: analysisState.result),
              ),
              const SizedBox(height: 12),
              _ActionBar(
                isAnalyzing: isAnalyzing,
                liveOn: _liveOn,
                liveAnalyzeOn: _liveAnalyzeOn,
                cameraTesting: _cameraTesting,
                onConnectCamera: _probeCameraConnection,
                onAnalyze: _analyzeCurrent,
                onToggleLiveAnalyze: _toggleLiveAnalyze,
                onDetectArduino: _detectArduino,
              ),
              const SizedBox(height: 12),
              _PieceCard(
                lotController: _lotController,
                pieceCode: _currentPieceCode,
                saved: _pieceWasSaved,
                onLotChanged: _handleLotChanged,
              ),
              const SizedBox(height: 12),
              _VerdictCard(
                state: analysisState,
                annotatedImageUrl: _annotatedImageUrl,
              ),
              const SizedBox(height: 12),
              _MeasurementsCard(state: analysisState),
              const SizedBox(height: 12),
              _AlertsCard(state: analysisState),
              const SizedBox(height: 12),
              if (_arduinoDetected)
                const _FooterHint(
                  icon: Icons.usb_outlined,
                  text: 'Arduino détecté et prêt à recevoir les verdicts',
                ),
              const SizedBox(height: 8),
              _ArduinoStatusChip(
                text: _arduinoStatusText,
                color: _arduinoStatusColor,
                icon: _arduinoStatusIcon,
              ),
              const SizedBox(height: 8),
              _FooterHint(
                icon: Icons.link_outlined,
                text: api.cameraStreamUrl,
                mono: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageZone extends StatelessWidget {
  final _CameraSource source;
  final bool liveOn;
  final bool liveStreamError;
  final Animation<double> liveBlinkOpacity;
  final Stream<Uint8List>? liveStream;
  final File? localImage;
  final String? annotatedImageUrl;
  final ValueChanged<Uint8List>? onLiveFrame;
  final VoidCallback onCameraLive;
  final VoidCallback onCapture;
  final VoidCallback onGallery;
  final VoidCallback? onOpenResult;

  const _ImageZone({
    required this.source,
    required this.liveOn,
    required this.liveStreamError,
    required this.liveBlinkOpacity,
    required this.liveStream,
    required this.localImage,
    required this.annotatedImageUrl,
    this.onLiveFrame,
    required this.onCameraLive,
    required this.onCapture,
    required this.onGallery,
    required this.onOpenResult,
  });

  String get _badgeLabel => switch (source) {
        _CameraSource.live => 'LIVE',
        _CameraSource.photo => 'PHOTO',
        _CameraSource.gallery => 'GALLERY',
        _CameraSource.idle => '',
      };

  Color get _badgeColor => switch (source) {
        _CameraSource.live => AppTheme.failRed,
        _CameraSource.photo => AppTheme.primaryBlue,
        _CameraSource.gallery => const Color(0xFF8B5CF6),
        _CameraSource.idle => Colors.transparent,
      };

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (liveOn && annotatedImageUrl != null) {
      content = Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              annotatedImageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const _ImagePlaceholder(
                title: 'Image d\'analyse non disponible',
                subtitle: 'Connect camera or open an image',
                icon: Icons.broken_image_outlined,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const _ImagePlaceholder(
                  title: 'Chargement de l\'annotation...',
                  subtitle: 'Patientez un instant',
                  icon: Icons.hourglass_bottom,
                );
              },
            ),
          ),
          if (onOpenResult != null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onOpenResult),
              ),
            ),
        ],
      );
    } else if (liveOn) {
      content = liveStreamError
          ? const _ImagePlaceholder(
              title: 'Caméra non disponible',
              subtitle: 'Connect camera or open an image',
              icon: Icons.videocam_off_outlined,
            )
          : liveStream == null
              ? const _ImagePlaceholder(
                  title: 'Connexion caméra...',
                  subtitle: 'Connect camera or open an image',
                  icon: Icons.hourglass_bottom,
                )
              : StreamBuilder<Uint8List>(
                  stream: liveStream,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const _ImagePlaceholder(
                        title: 'Connexion caméra...',
                        subtitle: 'Connect camera or open an image',
                        icon: Icons.hourglass_bottom,
                      );
                    }
                    if (onLiveFrame != null) {
                      onLiveFrame!(snap.data!);
                    }
                    return Image.memory(
                      snap.data!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    );
                  },
                );
    } else if (annotatedImageUrl != null) {
      content = Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              annotatedImageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const _ImagePlaceholder(
                title: 'Image d\'analyse non disponible',
                subtitle: 'Connect camera or open an image',
                icon: Icons.broken_image_outlined,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const _ImagePlaceholder(
                  title: 'Chargement de l\'annotation...',
                  subtitle: 'Patientez un instant',
                  icon: Icons.hourglass_bottom,
                );
              },
            ),
          ),
          if (onOpenResult != null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onOpenResult),
              ),
            ),
        ],
      );
    } else if (localImage != null) {
      content = Image.file(
        localImage!,
        fit: BoxFit.contain,
      );
    } else {
      content = const _ImagePlaceholder(
        title: 'Connect camera or open an image',
        subtitle: 'Live feed, capture or gallery image',
        icon: Icons.photo_camera_outlined,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: content,
              ),
            ),
            if (_badgeLabel.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: _SourceBadge(
                  label: _badgeLabel,
                  color: _badgeColor,
                  live: source == _CameraSource.live,
                  blinkOpacity: liveBlinkOpacity,
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _ImageActionsRow(
                onCameraLive: onCameraLive,
                onCapture: onCapture,
                onGallery: onGallery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ImagePlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 54, color: AppTheme.textSecondary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool live;
  final Animation<double> blinkOpacity;

  const _SourceBadge({
    required this.label,
    required this.color,
    required this.live,
    required this.blinkOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.95), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          live
              ? FadeTransition(
                  opacity: blinkOpacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.failRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageActionsRow extends StatelessWidget {
  final VoidCallback onCameraLive;
  final VoidCallback onCapture;
  final VoidCallback onGallery;

  const _ImageActionsRow({
    required this.onCameraLive,
    required this.onCapture,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(String label, IconData icon, Color bg, VoidCallback onTap) {
      return FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg.withValues(alpha: 0.94),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          button('Camera live', Icons.videocam_outlined, AppTheme.primaryBlue,
              onCameraLive),
          const SizedBox(width: 10),
          button('Capture', Icons.camera_alt_outlined, const Color(0xFF0EA5E9),
              onCapture),
          const SizedBox(width: 10),
          button('Gallery', Icons.image_outlined, const Color(0xFF8B5CF6),
              onGallery),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool isAnalyzing;
  final bool liveOn;
  final bool liveAnalyzeOn;
  final bool cameraTesting;
  final VoidCallback onConnectCamera;
  final VoidCallback onAnalyze;
  final VoidCallback onToggleLiveAnalyze;
  final VoidCallback onDetectArduino;

  const _ActionBar({
    required this.isAnalyzing,
    required this.liveOn,
    required this.liveAnalyzeOn,
    required this.cameraTesting,
    required this.onConnectCamera,
    required this.onAnalyze,
    required this.onToggleLiveAnalyze,
    required this.onDetectArduino,
  });

  @override
  Widget build(BuildContext context) {
    Widget action(String label, IconData icon, Color color, VoidCallback onTap,
        {bool disabled = false, Widget? trailing}) {
      return FilledButton.icon(
        onPressed: disabled ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: trailing ?? Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          action(
            'Connect camera',
            Icons.cast_connected_outlined,
            AppTheme.primaryBlue,
            onConnectCamera,
            disabled: cameraTesting,
            trailing: cameraTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          action(
            'Analyser',
            isAnalyzing ? Icons.hourglass_bottom : Icons.analytics_outlined,
            AppTheme.primaryBlue,
            onAnalyze,
            disabled: isAnalyzing,
          ),
          const SizedBox(width: 10),
          action(
            liveAnalyzeOn ? 'Analyse Live OFF' : 'Analyse Live ON',
            liveAnalyzeOn
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            liveOn ? const Color(0xFF2E7D32) : AppTheme.textSecondary,
            onToggleLiveAnalyze,
            disabled: !liveOn,
          ),
          const SizedBox(width: 10),
          action(
            'Detect Arduino',
            Icons.usb_outlined,
            const Color(0xFF4B5563),
            onDetectArduino,
          ),
        ],
      ),
    );
  }
}

class _PieceCard extends StatelessWidget {
  final TextEditingController lotController;
  final String pieceCode;
  final bool saved;
  final ValueChanged<String> onLotChanged;

  const _PieceCard({
    required this.lotController,
    required this.pieceCode,
    required this.saved,
    required this.onLotChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PIÈCE IDENTIFIÉE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saisir le lot',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: lotController,
                        onChanged: onLotChanged,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'A-2025',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kv('Piece code', pieceCode),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            saved
                ? 'Inspection enregistrée, prochaine pièce prête.'
                : 'Lecture seule',
            style: TextStyle(
              fontSize: 11,
              color: saved ? AppTheme.passGreen : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  final AnalysisState state;
  final String? annotatedImageUrl;

  const _VerdictCard({
    required this.state,
    required this.annotatedImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    final isPass = result?.isPass ?? false;
    final verdictColor = result == null
        ? AppTheme.textSecondary
        : isPass
            ? AppTheme.passGreen
            : AppTheme.failRed;

    final causes = <String>{
      ...?result?.causes,
      ...?result?.alerts,
    }.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VERDICT',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                result == null
                    ? Icons.remove_circle_outline
                    : isPass
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                color: verdictColor,
                size: 38,
              ),
              const SizedBox(width: 10),
              Text(
                result == null ? '—' : result.verdict,
                style: TextStyle(
                  color: verdictColor,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              if (result != null) ...[
                const SizedBox(width: 8),
                Text(
                  isPass ? '✓' : '✗',
                  style: TextStyle(
                    color: verdictColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          if (state.usedFallback) ...[
            const SizedBox(height: 8),
            const Text(
              'Mode compatibilité: dernier résultat affiché.',
              style: TextStyle(
                color: AppTheme.warnOrange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (causes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              causes.join(' | '),
              style: const TextStyle(
                color: AppTheme.failRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (annotatedImageUrl != null && result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Annotations disponibles dans la zone image.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeasurementsCard extends StatelessWidget {
  final AnalysisState state;

  const _MeasurementsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final result = state.result;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MESURES',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: result == null
                ? const Center(
                    child: Text(
                      'Aucune mesure',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Scrollbar(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _MeasurementRow(
                            label: 'Pitch F1→F2',
                            value: _pitchValue(result, 0),
                            isOk: _pitchOk(result, 0),
                            missing: _pairMissing(result, 1, 2),
                          ),
                          _MeasurementRow(
                            label: 'Pitch F2→F3',
                            value: _pitchValue(result, 1),
                            isOk: _pitchOk(result, 1),
                            missing: _pairMissing(result, 2, 3),
                          ),
                          _MeasurementRow(
                            label: 'Pitch F3→F4',
                            value: _pitchValue(result, 2),
                            isOk: _pitchOk(result, 2),
                            missing: _pairMissing(result, 3, 4),
                          ),
                          _MeasurementRow(
                            label: 'Total F1→F4',
                            value: _totalValue(result),
                            isOk: _pairMissing(result, 1, 4)
                                ? null
                                : result.totalWidthOk,
                            missing: _pairMissing(result, 1, 4),
                          ),
                          const SizedBox(height: 8),
                          _MeasurementRow(
                            label: 'Tilt F1',
                            value: _fingerValue(result, 1,
                                (f) => '${f.tiltDeg.toStringAsFixed(2)}°'),
                            isOk: _fingerOk(result, 1, (f) => f.tiltOk),
                            missing: _fingerMissing(result, 1),
                          ),
                          _MeasurementRow(
                            label: 'Tilt F2',
                            value: _fingerValue(result, 2,
                                (f) => '${f.tiltDeg.toStringAsFixed(2)}°'),
                            isOk: _fingerOk(result, 2, (f) => f.tiltOk),
                            missing: _fingerMissing(result, 2),
                          ),
                          _MeasurementRow(
                            label: 'Tilt F3',
                            value: _fingerValue(result, 3,
                                (f) => '${f.tiltDeg.toStringAsFixed(2)}°'),
                            isOk: _fingerOk(result, 3, (f) => f.tiltOk),
                            missing: _fingerMissing(result, 3),
                          ),
                          _MeasurementRow(
                            label: 'Tilt F4',
                            value: _fingerValue(result, 4,
                                (f) => '${f.tiltDeg.toStringAsFixed(2)}°'),
                            isOk: _fingerOk(result, 4, (f) => f.tiltOk),
                            missing: _fingerMissing(result, 4),
                          ),
                          const SizedBox(height: 8),
                          _MeasurementRow(
                            label: 'Hauteur F1',
                            value: _fingerValue(result, 1,
                                (f) => '${f.heightMm.toStringAsFixed(3)} mm'),
                            isOk: _fingerMissing(result, 1) ? null : true,
                            missing: _fingerMissing(result, 1),
                          ),
                          _MeasurementRow(
                            label: 'Hauteur F2',
                            value: _fingerValue(result, 2,
                                (f) => '${f.heightMm.toStringAsFixed(3)} mm'),
                            isOk: _fingerMissing(result, 2) ? null : true,
                            missing: _fingerMissing(result, 2),
                          ),
                          _MeasurementRow(
                            label: 'Hauteur F3',
                            value: _fingerValue(result, 3,
                                (f) => '${f.heightMm.toStringAsFixed(3)} mm'),
                            isOk: _fingerMissing(result, 3) ? null : true,
                            missing: _fingerMissing(result, 3),
                          ),
                          _MeasurementRow(
                            label: 'Hauteur F4',
                            value: _fingerValue(result, 4,
                                (f) => '${f.heightMm.toStringAsFixed(3)} mm'),
                            isOk: _fingerMissing(result, 4) ? null : true,
                            missing: _fingerMissing(result, 4),
                          ),
                          const SizedBox(height: 8),
                          _MeasurementRow(
                            label: 'Fingers présents',
                            value: '${result.nbFingers}/4',
                            isOk: result.nbFingers == 4,
                          ),
                          _MeasurementRow(
                            label: 'Spring missing',
                            value: '${result.nMissing}',
                            isOk: result.nMissing == 0,
                          ),
                          _MeasurementRow(
                            label: 'Spring bent',
                            value: '${result.nBent}',
                            isOk: result.nBent == 0,
                          ),
                          _MeasurementRow(
                            label: 'mpp',
                            value: '${result.mpp.toStringAsFixed(5)} mm/px',
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _fingerMissing(InspectionResult result, int fingerNum) {
    final finger = _finger(result, fingerNum);
    return finger == null || finger.missing;
  }

  String _fingerValue(
    InspectionResult result,
    int fingerNum,
    String Function(FingerData) formatter,
  ) {
    final finger = _finger(result, fingerNum);
    if (finger == null || finger.missing) return '— MISSING';
    return formatter(finger);
  }

  bool? _fingerOk(
    InspectionResult result,
    int fingerNum,
    bool Function(FingerData) getter,
  ) {
    final finger = _finger(result, fingerNum);
    if (finger == null || finger.missing) return null;
    return getter(finger);
  }

  String _pitchValue(InspectionResult result, int index) {
    if (index >= result.pitchesMm.length) return '— MISSING';
    return '${result.pitchesMm[index].toStringAsFixed(3)} mm';
  }

  bool? _pitchOk(InspectionResult result, int index) {
    if (index >= result.pitchesOk.length) return null;
    return result.pitchesOk[index];
  }

  String _totalValue(InspectionResult result) {
    if (_pairMissing(result, 1, 4)) return '— MISSING';
    return '${result.totalWidthMm.toStringAsFixed(3)} mm';
  }

  bool _pairMissing(InspectionResult result, int a, int b) {
    return _fingerMissing(result, a) || _fingerMissing(result, b);
  }

  FingerData? _finger(InspectionResult result, int fingerNum) {
    for (final finger in result.fingers) {
      if (finger.fingerNum == fingerNum) return finger;
    }
    return null;
  }
}

class _AlertsCard extends StatelessWidget {
  final AnalysisState state;

  const _AlertsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    final alerts = <String>{
      ...?result?.alerts,
      ...?result?.causes,
    }.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALERTES',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (state.phase == AnalysisPhase.failure && state.error != null)
            Text(
              state.error!,
              style: const TextStyle(
                color: AppTheme.failRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (alerts.isEmpty)
            const Text(
              'No alerts',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alerts
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: AppTheme.failRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final String label;
  final String value;
  final bool? isOk;
  final bool missing;

  const _MeasurementRow({
    required this.label,
    required this.value,
    this.isOk,
    this.missing = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color valueColor = missing
        ? AppTheme.textSecondary
        : switch (isOk) {
            true => AppTheme.passGreen,
            false => AppTheme.failRed,
            null => AppTheme.textPrimary,
          };

    final IconData? icon = missing
        ? null
        : switch (isOk) {
            true => Icons.check_circle_outline,
            false => Icons.cancel_outlined,
            null => null,
          };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (icon != null) ...[
            Icon(icon, size: 16, color: valueColor),
            const SizedBox(width: 6),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool mono;

  const _FooterHint({
    required this.icon,
    required this.text,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArduinoStatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _ArduinoStatusChip({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
