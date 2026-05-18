// lib/screens/dashboard_screen.dart
// ✅ OVERFLOW CORRIGÉ : suppression du height:1.3 + split subtitle + padding bottom 20

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
            _buildHeader(context, isConnected),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildKpiCards(pass, fail, rate, total),
                    const SizedBox(height: 12),
                    _buildSpcCard(spcState, context),
                    const SizedBox(height: 12),
                    _buildLiveFeed(inspectionsAsync, total, context),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.9),
            AppTheme.failRed.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Starz Quality Control',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Ligne 3 · Station A',
                style: TextStyle(fontSize: 11, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
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
          );

          final headerLine = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildLogo(),
                        const SizedBox(width: 10),
                        Expanded(child: titleBlock),
                        const SizedBox(width: 8),
                        actionButtons,
                      ],
                    ),
                    const SizedBox(height: 8),
                    _LiveBadge(isLive: isConnected),
                  ],
                )
              : Row(
                  children: [
                    _buildLogo(),
                    const SizedBox(width: 10),
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    _LiveBadge(isLive: isConnected),
                    const SizedBox(width: 8),
                    actionButtons,
                  ],
                );

          return headerLine;
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.memory,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildKpiCards(int pass, int fail, double rate, int total) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // ← clé : pas d'étirement
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KpiCard(
                title: 'CONFORMES',
                value: '$pass',
                line1: 'pièces OK',
                line2: '= session préc.',
                color: AppTheme.passGreen,
              ),
              const SizedBox(height: 10),
              _KpiCard(
                title: 'CONFORMITÉ',
                value: '${(rate * 100).toStringAsFixed(0)}%',
                line1: 'Objectif : 95%',
                line2: '',
                color: AppTheme.warnOrange,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KpiCard(
                title: 'REBUTS',
                value: '$fail',
                line1: 'hors tolérance',
                line2: '+2 vs session préc.',
                color: AppTheme.failRed,
              ),
              const SizedBox(height: 10),
              _KpiCard(
                title: 'TOTAL INSPECTÉ',
                value: '$total',
                line1: 'pièces · session',
                line2: 'en cours',
                color: AppTheme.primaryBlue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSpcCard(dynamic spcState, BuildContext context) {
    final pitches = spcState.pitches as List<double>;

    return _GradientBorderBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SPC — PITCH (MM)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/spc'),
                child: const Text(
                  'Défauts →',
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
          SizedBox(
            height: 160,
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
          const SizedBox(height: 12),
          const _LegendItemText(
            color: AppTheme.failRed,
            label: 'UCL / LCL : limites de contrôle',
          ),
          const SizedBox(height: 4),
          const _LegendItemText(
            color: AppTheme.primaryBlue,
            label: 'CL : ligne cible (2.788 mm)',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLiveFeed(
    AsyncValue<List<InspectionResult>> inspectionsAsync,
    int total,
    BuildContext context,
  ) {
    return _GradientBorderBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FLUX EN DIRECT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 10),
          inspectionsAsync.when(
            data: (inspections) {
              if (inspections.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
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
                padding: EdgeInsets.all(16),
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

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

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

// ─────────────────────────────────────────────────────────────────────────────
// ✅ CORRIGÉ :
//   • subtitle splitté en line1 + line2 (plus de \n)
//   • height: 1.3 SUPPRIMÉ des TextStyle (c'était la vraie cause du +5.6px)
//   • padding bottom = 20 (was 10)
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String line1;
  final String line2;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.line1,
    required this.line2,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight =
            constraints.maxHeight.isFinite && constraints.maxHeight < 140;
        final padding = EdgeInsets.fromLTRB(11, 10, 11, isTight ? 14 : 20);
        final titleSize = isTight ? 9.0 : 10.0;
        final valueSize = isTight ? 24.0 : 26.0;
        final lineSize = isTight ? 9.0 : 10.0;
        final valueGap = isTight ? 4.0 : 6.0;
        final lineGap = isTight ? 1.0 : 2.0;

        return _GradientBorderBox(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barre colorée
              Container(
                width: double.infinity,
                height: 3,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Titre
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Valeur principale
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
              SizedBox(height: valueGap),
              // Ligne 1 (ex: "pièces OK")
              Text(
                line1,
                style: TextStyle(
                  fontSize: lineSize,
                  color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Ligne 2 optionnelle (ex: "= session préc.")
              if (line2.isNotEmpty) ...[
                SizedBox(height: lineGap),
                Text(
                  line2,
                  style: TextStyle(
                    fontSize: lineSize,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  final bool isLive;
  const _LiveBadge({required this.isLive});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: (widget.isLive ? AppTheme.passGreen : AppTheme.failRed)
                    .withValues(
                        alpha: widget.isLive ? (0.5 + _ctrl.value * 0.5) : 1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
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

// ─────────────────────────────────────────────────────────────────────────────
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
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inspection.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'pitch ${inspection.pitchMeanMm.toStringAsFixed(3)} mm',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  if (inspection.nMissing > 0 || inspection.nBent > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Wrap(
                        spacing: 5,
                        children: [
                          if (inspection.nMissing > 0)
                            _DefectTag(
                              label:
                                  '${inspection.nMissing} manquant${inspection.nMissing > 1 ? 's' : ''}',
                              color: AppTheme.warnOrange,
                            ),
                          if (inspection.nBent > 0)
                            _DefectTag(
                              label:
                                  '${inspection.nBent} plié${inspection.nBent > 1 ? 's' : ''}',
                              color: AppTheme.primaryBlue,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _formatTime(inspection.timestamp),
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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

// ─────────────────────────────────────────────────────────────────────────────
class _DefectTag extends StatelessWidget {
  final String label;
  final Color color;

  const _DefectTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

// ─────────────────────────────────────────────────────────────────────────────
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

    double py(double v) =>
        size.height - 20 - ((v - minV) / range) * (size.height - 32);
    double px(int i) =>
        34 + (i * (size.width - 40) / (pitches.length - 1).clamp(1, 999));

    final limitPaint = Paint()
      ..color = AppTheme.failRed.withValues(alpha: 0.8)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final clPaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.8)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    _drawDashedLine(
        canvas, Offset(34, py(ucl)), Offset(size.width, py(ucl)), limitPaint);
    _drawDashedLine(
        canvas, Offset(34, py(lcl)), Offset(size.width, py(lcl)), limitPaint);
    _drawDashedLine(
        canvas, Offset(34, py(cl)), Offset(size.width, py(cl)), clPaint);

    _drawLabel(canvas, 'UCL', 2, py(ucl) - 10, AppTheme.failRed);
    _drawLabel(canvas, 'CL', 2, py(cl) - 10, AppTheme.primaryBlue);
    _drawLabel(canvas, 'LCL', 2, py(lcl) - 10, AppTheme.failRed);

    final curvePath = Path();
    for (int i = 0; i < pitches.length; i++) {
      final x = px(i);
      final y = py(pitches[i]);
      if (i == 0) {
        curvePath.moveTo(x, y);
      } else {
        curvePath.lineTo(x, y);
      }
    }

    final fillPath = Path.from(curvePath)
      ..lineTo(px(pitches.length - 1), size.height - 20)
      ..lineTo(px(0), size.height - 20)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.failRed.withValues(alpha: 0.08),
            AppTheme.primaryBlue.withValues(alpha: 0.08),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      curvePath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.failRed.withValues(alpha: 0.9),
            AppTheme.primaryBlue.withValues(alpha: 0.9),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    for (int i = 0; i < pitches.length; i++) {
      final x = px(i);
      final y = py(pitches[i]);

      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()
          ..color = AppTheme.primaryBlue
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );

      final xLabel = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}',
          style: const TextStyle(
            fontSize: 8,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      xLabel.paint(canvas, Offset(x - xLabel.width / 2, size.height - 10));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 3.0;
    const dashSpace = 2.0;
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
      text: TextSpan(
        text: text,
        style:
            TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
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
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
