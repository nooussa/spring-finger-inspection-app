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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.9),
            AppTheme.failRed.withValues(alpha: 0.9)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.memory,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starz Quality Control',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Contrôle Qualité — Ligne 3 · Station A',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
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
            icon: const Icon(Icons.light_mode_outlined, color: Colors.white),
            onPressed: () {},
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
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
        // SPC Curve Chart
        _buildSpcCard(spcState, context),
      ],
    );
  }

  Widget _buildSpcCard(dynamic spcState, BuildContext context) {
    final pitches = spcState.pitches as List<double>;

    return _GradientBorderBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ÉVOLUTION SPC — PITCH (MM)',
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
                  'Défauts globaux →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: pitches.length < 2
                ? const Center(
                    child: Text(
                      'En attente de données suffisantes...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : CustomPaint(
                    painter: _SpcChartPainter(pitches: pitches),
                    size: Size.infinite,
                  ),
          ),
          const SizedBox(height: 16),
          // Légende des abréviations
          const Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendItemText(color: AppTheme.failRed, label: 'UCL: Upper Control Limit (Max)'),
              _LegendItemText(color: AppTheme.primaryBlue, label: 'CL: Center Line (Cible)'),
              _LegendItemText(color: AppTheme.failRed, label: 'LCL: Lower Control Limit (Min)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveFeed(AsyncValue<List<InspectionResult>> inspectionsAsync, int total, BuildContext context) {
    return _GradientBorderBox(
      padding: const EdgeInsets.all(16),
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

class _GradientBorderBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GradientBorderBox({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          colors: [
            AppTheme.failRed.withValues(alpha: 0.6),
            AppTheme.primaryBlue.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(11),
        ),
        child: child,
      ),
    );
  }
}

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
    return _GradientBorderBox(
      padding: const EdgeInsets.all(12),
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

    double py(double v) => size.height - 25 - ((v - minV) / range) * (size.height - 40);
    double px(int i) => 40 + (i * (size.width - 50) / (pitches.length - 1).clamp(1, 999));

    // 1. Tracer les lignes horizontales (LCL, CL, UCL)
    final limitPaint = Paint()
      ..color = AppTheme.failRed.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final clPaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, Offset(40, py(ucl)), Offset(size.width, py(ucl)), limitPaint);
    _drawDashedLine(canvas, Offset(40, py(lcl)), Offset(size.width, py(lcl)), limitPaint);
    _drawDashedLine(canvas, Offset(40, py(cl)), Offset(size.width, py(cl)), clPaint);

    // Labels UCL, CL, LCL
    _drawLabel(canvas, 'UCL', 5, py(ucl) - 12, AppTheme.failRed);
    _drawLabel(canvas, 'CL', 5, py(cl) - 12, AppTheme.primaryBlue);
    _drawLabel(canvas, 'LCL', 5, py(lcl) - 12, AppTheme.failRed);

    // 2. Préparer le parcours des points sans lissage (ligne droite)
    final curvePath = Path();
    for (int i = 0; i < pitches.length; i++) {
      final x = px(i);
      final y = py(pitches[i]);
      if (i == 0) {
        curvePath.moveTo(x, y);
      } else {
        curvePath.lineTo(x, y); // Pas lissé = trait droit industriel
      }
    }

    // 3. Ombrage de fond sous la ligne
    final fillPath = Path.from(curvePath)
      ..lineTo(px(pitches.length - 1), size.height - 25)
      ..lineTo(px(0), size.height - 25)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.failRed.withValues(alpha: 0.15),
          AppTheme.primaryBlue.withValues(alpha: 0.15),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);

    // 4. Ligne Principale
    final gradient = LinearGradient(
      colors: [
        AppTheme.failRed.withValues(alpha: 0.9),
        AppTheme.primaryBlue.withValues(alpha: 0.9),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..shader = gradient
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round // jointures droites mais adoucies
      ..style = PaintingStyle.stroke;
      
    canvas.drawPath(curvePath, linePaint);

    // 5. Points et Axes (X labels)
    for (int i = 0; i < pitches.length; i++) {
      final x = px(i);
      final y = py(pitches[i]);
      
      canvas.drawCircle(
        Offset(x, y),
        4.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(x, y),
        4.5,
        Paint()
          ..color = AppTheme.primaryBlue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Label X (PIECE i)
      final xLabel = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}',
          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      xLabel.paint(canvas, Offset(x - xLabel.width / 2, size.height - 12));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
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
      text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LegendItemText extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItemText({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
