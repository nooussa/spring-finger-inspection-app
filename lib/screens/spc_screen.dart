// lib/screens/spc_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers/spc_provider.dart';
import '../widgets/status_badge.dart';
// Pour SpcPainter

class SpcScreen extends ConsumerWidget {
  const SpcScreen({super.key});

  static const double _ucl = 1.25;
  static const double _lcl = 1.15;
  static const double _target = 1.20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spcState = ref.watch(extendedSpcStateProvider);
    final driftDetected = spcState.driftDetected;
    final lastPitch = spcState.lastPitch;
    final mean = spcState.mean;
    final outOfControl = spcState.outOfControlCount;
    final cp = spcState.cp;
    final cpk = spcState.cpk;
    final stdDev = spcState.standardDeviation;
    final count = spcState.count;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWhite,
        title: const Text('Contrôle SPC'),
        actions: [
          if (driftDetected) ...[
            const DriftBadge(driftDetected: true),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppTheme.textSecondary),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card résumé
            _buildSummaryCard(lastPitch, mean, outOfControl, count),
            const SizedBox(height: 16),

            // Graphique SPC grand format
            _buildLargeChart(spcState),
            const SizedBox(height: 16),

            // Stats Cp/Cpk
            _buildCapabilityCard(cp, cpk, stdDev),
            const SizedBox(height: 16),

            // Limites de contrôle
            _buildLimitsCard(),
            const SizedBox(height: 16),

            // Tableau des dernières valeurs
            _buildRecentValuesCard(spcState.pitches),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      double? lastPitch, double mean, int outOfControl, int count) {
    final isLastOk =
        lastPitch != null && lastPitch >= _lcl && lastPitch <= _ucl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RÉSUMÉ',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Dernier pitch',
                  value: lastPitch != null
                      ? '${lastPitch.toStringAsFixed(3)} mm'
                      : '—',
                  valueColor: lastPitch == null
                      ? AppTheme.textSecondary
                      : isLastOk
                          ? AppTheme.passGreen
                          : AppTheme.failRed,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Moyenne',
                  value: count > 0 ? '${mean.toStringAsFixed(3)} mm' : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Points analysés',
                  value: '$count',
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Hors contrôle',
                  value: '$outOfControl',
                  valueColor:
                      outOfControl > 0 ? AppTheme.failRed : AppTheme.passGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeChart(spcState) {
    final pitches = spcState.pitches as List<double>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CARTE DE CONTRÔLE — PITCH (mm)',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
                letterSpacing: 0.08,
              ),
            ),
            Text(
              '${pitches.length} points',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF080A0E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: pitches.length < 2
              ? const Center(
                  child: Text(
                    'En attente de données suffisantes...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CustomPaint(
                      painter: SpcPainter(
                        pitches: List.from(pitches),
                        ucl: _ucl,
                        lcl: _lcl,
                        target: _target,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCapabilityCard(double cp, double cpk, double stdDev) {
    Color getCpColor(double value) {
      if (value >= 1.33) return AppTheme.passGreen;
      if (value >= 1.0) return AppTheme.warnOrange;
      return AppTheme.failRed;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CAPABILITÉ PROCESSUS',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Cp',
                  value: cp > 0 ? cp.toStringAsFixed(2) : '—',
                  valueColor: cp > 0 ? getCpColor(cp) : AppTheme.textSecondary,
                  subtitle: cp >= 1.33
                      ? 'Excellent'
                      : cp >= 1.0
                          ? 'Acceptable'
                          : cp > 0
                              ? 'Insuffisant'
                              : null,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Cpk',
                  value: cpk > 0 ? cpk.toStringAsFixed(2) : '—',
                  valueColor:
                      cpk > 0 ? getCpColor(cpk) : AppTheme.textSecondary,
                  subtitle: cpk >= 1.33
                      ? 'Centré'
                      : cpk >= 1.0
                          ? 'Acceptable'
                          : cpk > 0
                              ? 'Décentré'
                              : null,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Écart-type (σ)',
                  value: stdDev > 0 ? stdDev.toStringAsFixed(4) : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIMITES DE CONTRÔLE',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.08,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LimitItem(
                  label: 'UCL',
                  value: '$_ucl mm',
                  color: AppTheme.failRed,
                ),
              ),
              Expanded(
                child: _LimitItem(
                  label: 'Target',
                  value: '$_target mm',
                  color: AppTheme.passGreen,
                ),
              ),
              Expanded(
                child: _LimitItem(
                  label: 'LCL',
                  value: '$_lcl mm',
                  color: AppTheme.failRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentValuesCard(List<double> pitches) {
    // Afficher les 20 dernières valeurs
    final recent =
        pitches.length > 20 ? pitches.sublist(pitches.length - 20) : pitches;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DERNIÈRES VALEURS',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.08,
                ),
              ),
              Text(
                '${recent.length} sur ${pitches.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Aucune donnée',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recent.reversed.map((pitch) {
                final isOk = pitch >= _lcl && pitch <= _ucl;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOk
                        ? AppTheme.passGreen.withValues(alpha: 0.1)
                        : AppTheme.failRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOk
                          ? AppTheme.passGreen.withValues(alpha: 0.3)
                          : AppTheme.failRed.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    pitch.toStringAsFixed(3),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isOk ? AppTheme.passGreen : AppTheme.failRed,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? subtitle;

  const _StatItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 9,
              color:
                  valueColor?.withValues(alpha: 0.7) ?? AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _LimitItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LimitItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SpcPainter extends CustomPainter {
  final List<double> pitches;
  final double ucl;
  final double lcl;
  final double target;

  SpcPainter({
    required this.pitches,
    required this.ucl,
    required this.lcl,
    required this.target,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pitches.isEmpty) return;

    final double minV = lcl - 0.1;
    final double maxV = ucl + 0.1;
    final double range = maxV - minV;

    double py(double v) => size.height - 20 - ((v - minV) / range) * (size.height - 40);
    double px(int i) => 30 + (i * (size.width - 50) / (pitches.length - 1).clamp(1, 999));

    // Draw horizontal lines (UCL, Target, LCL)
    final uclPaint = Paint()
      ..color = AppTheme.failRed
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final targetPaint = Paint()
      ..color = AppTheme.passGreen
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // UCL line (dashed)
    _drawDashedLine(canvas, Offset(30, py(ucl)), Offset(size.width - 10, py(ucl)), uclPaint);
    // LCL line (dashed)
    _drawDashedLine(canvas, Offset(30, py(lcl)), Offset(size.width - 10, py(lcl)), uclPaint);
    // Target line (dashed green)
    _drawDashedLine(canvas, Offset(30, py(target)), Offset(size.width - 10, py(target)), targetPaint);

    // Labels
    _drawLabel(canvas, 'UCL', 0, py(ucl) - 6, AppTheme.failRed);
    _drawLabel(canvas, 'LCL', 0, py(lcl) - 6, AppTheme.failRed);
    _drawLabel(canvas, 'CL', 0, py(target) - 6, AppTheme.passGreen);

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
