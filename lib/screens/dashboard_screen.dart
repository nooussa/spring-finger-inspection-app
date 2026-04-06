// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../models/inspection_result.dart';
import '../providers/inspection_provider.dart';
import '../providers/spc_provider.dart';
import '../services/inspection_db_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(passCountProvider);
    final fail = ref.watch(failCountProvider);
    final rate = ref.watch(conformityRateProvider);
    final spcState = ref.watch(spcStateProvider);
    final inspectionsAsync = ref.watch(inspectionListProvider);
    final isConnected = ref.watch(isApiConnectedProvider);

    final total = pass + fail;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            _buildHeader(context, isConnected),
            
            // CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 4 KPI CARDS
                    _buildKpiCards(pass, fail, rate, total),
                    const SizedBox(height: 16),
                    
                    // MAIN CONTENT (SPC + Feed)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 700) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildLeftColumn(spcState, pass, fail, rate, context),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 4,
                                child: _buildLiveFeed(inspectionsAsync, total, context),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildLeftColumn(spcState, pass, fail, rate, context),
                            const SizedBox(height: 16),
                            _buildLiveFeed(inspectionsAsync, total, context),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.bgWhite,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.memory, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          
          // Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspection PCB',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Contrôle Qualité — Ligne 3 · Station A',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Live badge
          _LiveBadge(isLive: isConnected),
          const SizedBox(width: 12),
          
          // Icons
          IconButton(
            icon: const Icon(Icons.light_mode_outlined, color: AppTheme.textSecondary),
            onPressed: () {},
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.textSecondary),
            onPressed: () {},
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            onPressed: () => context.push('/settings'),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards(int pass, int fail, double rate, int total) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'CONFORMES',
            value: '$pass',
            subtitle: 'pièces OK aujourd\'hui\n= session précédente',
            color: AppTheme.passGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'REBUTS',
            value: '$fail',
            subtitle: 'pièces hors tolérance\n+2 vs session préc.',
            color: AppTheme.failRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'TAUX DE\nCONFORMITÉ',
            value: '${(rate * 100).toStringAsFixed(0)}%',
            subtitle: 'Objectif : 95%',
            color: AppTheme.warnOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'TOTAL INSPECTÉ',
            value: '$total',
            subtitle: 'pièces · session en\ncours',
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildLeftColumn(dynamic spcState, int pass, int fail, double rate, BuildContext context) {
    return Column(
      children: [
        // SPC Chart
        _buildSpcCard(spcState, context),
        const SizedBox(height: 16),
        // Pass/Fail Summary
        _buildPassFailSummary(pass, fail, rate),
      ],
    );
  }

  Widget _buildSpcCard(dynamic spcState, BuildContext context) {
    final pitches = spcState.pitches as List<double>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CARTE SPC — PITCH (MM)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/spc'),
                child: const Text(
                  'Voir détail →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Chart
          SizedBox(
            height: 180,
            child: pitches.length < 2
                ? const Center(
                    child: Text(
                      'En attente de données...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : CustomPaint(
                    painter: _SpcChartPainter(pitches: pitches),
                    size: Size.infinite,
                  ),
          ),
          
          // Legend
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppTheme.passGreen, label: 'Pass', isCircle: true),
              SizedBox(width: 16),
              _LegendItem(color: AppTheme.failRed, label: 'Fail', isCircle: true),
              SizedBox(width: 16),
              _LegendItem(color: AppTheme.failRed, label: 'UCL / LCL', isDashed: true),
              SizedBox(width: 16),
              _LegendItem(color: AppTheme.primaryBlue, label: 'Tendance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassFailSummary(int pass, int fail, double rate) {
    final total = pass + fail;
    final passRate = total > 0 ? (pass / total * 100) : 0.0;
    final failRate = total > 0 ? (fail / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pass/Fail columns
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'PASS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pass',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.passGreen,
                      ),
                    ),
                    Text(
                      '${passRate.toStringAsFixed(1)}% conformes',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: AppTheme.border),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'FAIL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$fail',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.failRed,
                      ),
                    ),
                    Text(
                      '${failRate.toStringAsFixed(1)}% rebuts',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TAUX DE CONFORMITÉ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${(rate * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warnOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Background
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Fill
                      FractionallySizedBox(
                        widthFactor: rate.clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.passGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      // Target marker at 95%
                      Positioned(
                        left: constraints.maxWidth * 0.95,
                        child: Container(
                          width: 2,
                          height: 8,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Cible : 95%',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveFeed(AsyncValue<List<InspectionResult>> inspectionsAsync, int total, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FLUX EN DIRECT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Feed list
          inspectionsAsync.when(
            data: (inspections) {
              if (inspections.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'En attente...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return Column(
                children: inspections
                    .take(6)
                    .map((i) => _FeedItem(
                          inspection: i,
                          onTap: () => context.push('/image', extra: i),
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
            ),
            error: (e, _) => Text('Erreur: $e'),
          ),
        ],
      ),
    );
  }
}

// === WIDGETS ===

class _LiveBadge extends StatefulWidget {
  final bool isLive;
  const _LiveBadge({required this.isLive});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isLive ? AppTheme.passBgLight : AppTheme.failBgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isLive ? AppTheme.passGreen : AppTheme.failRed,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: (widget.isLive ? AppTheme.passGreen : AppTheme.failRed)
                    .withValues(alpha: widget.isLive ? (0.5 + _ctrl.value * 0.5) : 1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.isLive ? 'EN DIRECT' : 'HORS LIGNE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.isLive ? AppTheme.passGreen : AppTheme.failRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top colored border
          Container(
            width: double.infinity,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isCircle;
  final bool isDashed;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isCircle = false,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCircle)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          )
        else if (isDashed)
          CustomPaint(
            size: const Size(20, 2),
            painter: _DashedLinePainter(color: color),
          )
        else
          Container(
            width: 20,
            height: 2,
            color: color,
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    
    const dashWidth = 4.0;
    const dashSpace = 2.0;
    double x = 0;
    
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + dashWidth, size.height / 2), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeedItem extends StatelessWidget {
  final InspectionResult inspection;
  final VoidCallback? onTap;

  const _FeedItem({required this.inspection, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPass = inspection.isPass;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPass ? AppTheme.passBgLight : AppTheme.failBgLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPass ? 'PASS' : 'FAIL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isPass ? AppTheme.passGreen : AppTheme.failRed,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inspection.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'pitch ${inspection.pitchMeanMm.toStringAsFixed(3)} mm',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  // Defect tags
                  if (inspection.nMissing > 0 || inspection.nBent > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        children: [
                          if (inspection.nMissing > 0)
                            _DefectTag(
                              label: '${inspection.nMissing} manquant${inspection.nMissing > 1 ? 's' : ''}',
                              color: AppTheme.warnOrange,
                            ),
                          if (inspection.nBent > 0)
                            _DefectTag(
                              label: '${inspection.nBent} plié${inspection.nBent > 1 ? 's' : ''}',
                              color: AppTheme.primaryBlue,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Time
            Text(
              _formatTime(inspection.timestamp),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

class _DefectTag extends StatelessWidget {
  final String label;
  final Color color;

  const _DefectTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _SpcChartPainter extends CustomPainter {
  final List<double> pitches;
  
  static const double ucl = 3.020;
  static const double lcl = 2.350;
  static const double cl = 2.788;

  _SpcChartPainter({required this.pitches});

  @override
  void paint(Canvas canvas, Size size) {
    if (pitches.isEmpty) return;

    const double minV = lcl - 0.2;
    const double maxV = ucl + 0.2;
    const double range = maxV - minV;

    double py(double v) => size.height - 20 - ((v - minV) / range) * (size.height - 40);
    double px(int i) => 40 + (i * (size.width - 60) / (pitches.length - 1).clamp(1, 999));

    // Draw horizontal lines (UCL, CL, LCL)
    final uclPaint = Paint()
      ..color = AppTheme.failRed
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final clPaint = Paint()
      ..color = AppTheme.primaryBlue
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // UCL line (dashed)
    _drawDashedLine(canvas, Offset(40, py(ucl)), Offset(size.width - 10, py(ucl)), uclPaint);
    // LCL line (dashed)
    _drawDashedLine(canvas, Offset(40, py(lcl)), Offset(size.width - 10, py(lcl)), uclPaint);
    // CL line (dashed blue)
    _drawDashedLine(canvas, Offset(40, py(cl)), Offset(size.width - 10, py(cl)), clPaint);

    // Labels
    _drawLabel(canvas, 'UCL $ucl', 0, py(ucl) - 6, AppTheme.failRed);
    _drawLabel(canvas, 'CL $cl', 0, py(cl) - 6, AppTheme.primaryBlue);
    _drawLabel(canvas, 'LCL $lcl', 0, py(lcl) - 6, AppTheme.failRed);

    // Draw trend line
    if (pitches.length >= 2) {
      final path = Path();
      for (int i = 0; i < pitches.length; i++) {
        final x = px(i);
        final y = py(pitches[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.primaryBlue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    // Draw points
    for (int i = 0; i < pitches.length; i++) {
      final x = px(i);
      final y = py(pitches[i]);
      final isOk = pitches[i] >= lcl && pitches[i] <= ucl;
      
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = isOk ? AppTheme.passGreen : AppTheme.failRed,
      );
    }

    // X-axis labels (piece names)
    const labelStyle = TextStyle(fontSize: 9, color: AppTheme.textSecondary);
    for (int i = 0; i < pitches.length; i++) {
      final x = px(i);
      final tp = TextPainter(
        text: TextSpan(text: 'PIECE${i + 1}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 15));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = _sqrt(dx * dx + dy * dy);
    final unitX = dx / len;
    final unitY = dy / len;
    
    double drawn = 0;
    while (drawn < len) {
      final start = Offset(p1.dx + unitX * drawn, p1.dy + unitY * drawn);
      final end = Offset(
        p1.dx + unitX * (drawn + dashWidth).clamp(0, len),
        p1.dy + unitY * (drawn + dashWidth).clamp(0, len),
      );
      canvas.drawLine(start, end, paint);
      drawn += dashWidth + dashSpace;
    }
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  void _drawLabel(Canvas canvas, String text, double x, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 9, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
