// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../models/inspection_result.dart';
import '../providers/inspection_provider.dart';
import '../providers/spc_provider.dart';
import '../services/inspection_db_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/feed_item.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const double _ucl = 1.25;
  static const double _lcl = 1.15;
  static const double _target = 1.20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(passCountProvider);
    final fail = ref.watch(failCountProvider);
    final rate = ref.watch(conformityRateProvider);
    final spcState = ref.watch(spcStateProvider);
    final inspectionsAsync = ref.watch(inspectionListProvider);
    final isConnected = ref.watch(isApiConnectedProvider);

    final total = pass + fail;
    final ratePct = total == 0 ? '—' : '${(rate * 100).toStringAsFixed(1)}%';

    final Color rateColor = total == 0
        ? AppTheme.textSecondary
        : rate >= 0.95
            ? AppTheme.passGreen
            : rate >= 0.88
                ? AppTheme.warnAmber
                : AppTheme.failRed;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isConnected),
              const SizedBox(height: 20),
              _buildMetrics(pass, fail, rate, total),
              const SizedBox(height: 14),
              _buildRateBar(ratePct, rateColor, rate, total),
              const SizedBox(height: 14),
              _buildSpcChart(spcState, isConnected),
              const SizedBox(height: 14),
              _buildFeed(inspectionsAsync, isConnected, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isConnected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inspection',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'PCB Quality Control',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            ConnectionBadge(connected: isConnected),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: AppTheme.textSecondary, size: 22),
              onPressed: () => context.push('/settings'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetrics(int pass, int fail, double rate, int total) {
    final isEmpty = total == 0;
    return Row(
      children: [
        Expanded(
          child: MetricCard.pass(
            value: pass,
            sub: isEmpty
                ? '— %'
                : '${(rate * 100).toStringAsFixed(1)}% conform.',
            isEmpty: isEmpty,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard.fail(
            value: fail,
            sub: isEmpty
                ? '— %'
                : '${(100 - rate * 100).toStringAsFixed(1)}% rebut',
            isEmpty: isEmpty,
          ),
        ),
      ],
    );
  }

  Widget _buildRateBar(String ratePct, Color color, double rate, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TAUX CONFORMITÉ',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
                letterSpacing: 0.06,
              ),
            ),
            Text(
              ratePct,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: total == 0 ? 0.0 : rate,
            minHeight: 6,
            backgroundColor: const Color(0xFF1A1D24),
            valueColor: AlwaysStoppedAnimation<Color>(
              total == 0 ? const Color(0xFF1A1D24) : color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpcChart(spcState, bool isConnected) {
    final pitches = spcState.pitches;
    final driftDetected = spcState.driftDetected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CARTE SPC — PITCH (mm)',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            DriftBadge(driftDetected: driftDetected),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF080A0E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1A1D24), width: 0.5),
          ),
          child: pitches.length < 2
              ? Center(
                  child: Text(
                    isConnected
                        ? 'En attente de données...'
                        : 'Non connecté à l\'API',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
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
      ],
    );
  }

  Widget _buildFeed(AsyncValue<List<InspectionResult>> inspectionsAsync,
      bool isConnected, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FLUX EN DIRECT',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        inspectionsAsync.when(
          data: (inspections) {
            if (inspections.isEmpty) {
              return _buildEmptyFeed(isConnected);
            }
            // Afficher les 10 premières
            final feed = inspections.take(10).toList();
            return Column(
              children: feed
                  .map((i) => FeedItem(
                        inspection: i,
                        onTap: () => context.push('/image', extra: i),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.passGreen),
            ),
          ),
          error: (e, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1A1D24), width: 0.5),
            ),
            child: Text(
              'Erreur: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.failRed,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFeed(bool isConnected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A1D24), width: 0.5),
      ),
      child: Text(
        isConnected
            ? 'En attente de la première pièce...'
            : 'Connectez-vous au serveur API\npour recevoir les résultats.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }
}

/// Painter SPC réutilisable (public)
class SpcPainter extends CustomPainter {
  final List<double> pitches;
  final double ucl, lcl, target;

  const SpcPainter({
    required this.pitches,
    required this.ucl,
    required this.lcl,
    required this.target,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double minV = 1.10;
    const double maxV = 1.30;
    const double range = maxV - minV;

    double py(double v) =>
        size.height - 6 - ((v - minV) / range) * (size.height - 12);

    final gridPaint = Paint()
      ..color = const Color(0xFF1A1D24)
      ..strokeWidth = 0.5;

    for (final v in [ucl, target, lcl]) {
      canvas.drawLine(Offset(0, py(v)), Offset(size.width, py(v)), gridPaint);
    }

    void drawLabel(String text, double v, Color color) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: 9, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(3, py(v) - 11));
    }

    drawLabel('UCL', ucl, const Color(0xFF2A6640));
    drawLabel('LCL', lcl, const Color(0xFF2A6640));

    if (pitches.length < 2) return;

    final path = Path();
    final step = size.width / (pitches.length - 1);

    for (int i = 0; i < pitches.length; i++) {
      final x = i * step;
      final y = py(pitches[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    for (int i = 0; i < pitches.length; i++) {
      final outOfCtrl = pitches[i] > ucl || pitches[i] < lcl;
      canvas.drawCircle(
        Offset(i * step, py(pitches[i])),
        outOfCtrl ? 3.5 : 2.0,
        Paint()
          ..color =
              outOfCtrl ? const Color(0xFFF87171) : const Color(0xFF378ADD),
      );
    }
  }

  @override
  bool shouldRepaint(SpcPainter old) => old.pitches.length != pitches.length;
}
