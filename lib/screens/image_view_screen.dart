// lib/screens/image_view_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/inspection_result.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/gradient_border_box.dart';

class ImageViewScreen extends ConsumerWidget {
  const ImageViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Récupérer l'inspection depuis les extras du GoRouter
    final extra = GoRouterState.of(context).extra;
    final inspection = extra is InspectionResult ? extra : null;

    if (inspection == null) {
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Détails',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: const Center(
          child: Text(
            'Aucune inspection sélectionnée',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final apiService = ref.read(apiServiceProvider);

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(inspection.displayName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          StatusBadge(status: inspection.verdict),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image ou placeholder
            _buildImageSection(inspection, apiService),

            // Détails de l'inspection
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainInfoCard(inspection),
                  const SizedBox(height: 16),
                  _buildComprehensiveTableCard(inspection),
                  if (inspection.fingers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildFingersCard(inspection),
                  ],
                  if (inspection.operator != null) ...[
                    const SizedBox(height: 16),
                    _buildOperatorCard(inspection),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(
      InspectionResult inspection, ApiService apiService) {
    final hasImage =
        inspection.imagePath != null && inspection.imagePath!.isNotEmpty;

    return Container(
      height: 220,
      width: double.infinity,
      color: AppTheme.bgWhite,
      child: hasImage
          ? Image.network(
              '${apiService.baseUrl}/images/${inspection.imagePath}',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildPlaceholder(inspection),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.passGreen,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            )
          : _buildPlaceholder(inspection),
    );
  }

  Widget _buildPlaceholder(InspectionResult inspection) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            inspection.isPass
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            size: 64,
            color: inspection.isPass
                ? AppTheme.passGreen.withValues(alpha: 0.5)
                : AppTheme.failRed.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Image non disponible',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfoCard(InspectionResult inspection) {
    return GradientBorderBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INFORMATIONS GÉNÉRALES',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Verdict',
            value: inspection.verdict,
            valueColor:
                inspection.isPass ? AppTheme.passGreen : AppTheme.failRed,
          ),
          const Divider(color: AppTheme.border, height: 16),
          _InfoRow(
            label: 'Timestamp',
            value: _formatDateTime(inspection.timestamp),
          ),
          if (inspection.piece != null) ...[
            const Divider(color: AppTheme.border, height: 16),
            _InfoRow(
              label: 'Code pièce',
              value: inspection.piece!.pieceCode ?? '—',
            ),
            if (inspection.piece!.lot != null) ...[
              const Divider(color: AppTheme.border, height: 16),
              _InfoRow(
                label: 'Lot',
                value: inspection.piece!.lot!,
              ),
            ],
          ],
          const Divider(color: AppTheme.border, height: 16),
          _InfoRow(
            label: 'ID',
            value: inspection.id,
          ),
        ],
      ),
    );
  }

  Widget _buildComprehensiveTableCard(InspectionResult inspection) {
    return GradientBorderBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ANALYSE DÉTAILLÉE : TOLÉRANCES & RÉSULTATS',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 16),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: const TableBorder(
              horizontalInside: BorderSide(color: AppTheme.border, width: 0.5),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(0.5),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppTheme.bgLight),
                children: [
                  _headerCell('Critère'),
                  _headerCell('Tolérance attendue'),
                  _headerCell('Résultat obtenu'),
                  _headerCell(''),
                ],
              ),
              _buildTableRow(
                'Pitch (Écart moyen)',
                '2.500 ± 0.1 mm',
                '${inspection.pitchMeanMm.toStringAsFixed(3)} mm',
                (inspection.pitchMeanMm >= 2.400 &&
                        inspection.pitchMeanMm <= 2.600) ||
                    inspection.pitchMeanMm == 0.0,
              ),
              _buildTableRow(
                'Largeur PCB',
                '7.5 ± 0.1 mm',
                '${inspection.totalWidthMm.toStringAsFixed(2)} mm',
                (inspection.totalWidthMm >= 7.4 &&
                        inspection.totalWidthMm <= 7.6) ||
                    inspection.totalWidthMm == 0.0,
              ),
              _buildTableRow(
                'Doigts détectés (Springs)',
                '4',
                '${inspection.nbFingers}',
                inspection.nbFingers == 4,
              ),
              _buildTableRow(
                'Composants pliés',
                '0',
                '${inspection.nBent}',
                inspection.nBent == 0,
              ),
              _buildTableRow(
                'Composants manquants',
                '0',
                '${inspection.nMissing}',
                inspection.nMissing == 0,
              ),
              if (inspection.nbAlertes > 0)
                _buildTableRow(
                  'Alertes (autres)',
                  '0',
                  '${inspection.nbAlertes}',
                  false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  TableRow _buildTableRow(
      String label, String tolerance, String result, bool isPass) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(tolerance,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(result,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isPass ? AppTheme.textPrimary : AppTheme.failRed,
              )),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Icon(
              isPass ? Icons.check_circle : Icons.cancel,
              color: isPass ? AppTheme.passGreen : AppTheme.failRed,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFingersCard(InspectionResult inspection) {
    return GradientBorderBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOIGTS (${inspection.fingers.length})',
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          ...inspection.fingers.take(10).map((f) => _FingerRow(finger: f)),
          if (inspection.fingers.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... et ${inspection.fingers.length - 10} autres',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorCard(InspectionResult inspection) {
    final op = inspection.operator!;
    return GradientBorderBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OPÉRATEUR',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.passGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: AppTheme.passGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.displayName ?? op.login ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (op.role != null)
                      Text(
                        op.role!,
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
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppTheme.textPrimary,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FingerRow extends StatelessWidget {
  final FingerData finger;

  const _FingerRow({required this.finger});

  @override
  Widget build(BuildContext context) {
    final hasIssue =
        finger.missing || finger.bent || !finger.pitchOk || !finger.tiltOk;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: hasIssue
            ? AppTheme.failRed.withValues(alpha: 0.05)
            : AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasIssue
              ? AppTheme.failRed.withValues(alpha: 0.2)
              : AppTheme.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${finger.fingerNum}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: hasIssue ? AppTheme.failRed : AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'pitch: ${finger.pitchMm.toStringAsFixed(3)} mm',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                ),
                Text(
                  'tilt: ${finger.tiltDeg.toStringAsFixed(1)}°',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (finger.missing)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.failRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'MANQ',
                style: TextStyle(fontSize: 8, color: AppTheme.failRed),
              ),
            ),
          if (finger.bent)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.warnOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'PLIÉ',
                style: TextStyle(fontSize: 8, color: AppTheme.warnOrange),
              ),
            ),
        ],
      ),
    );
  }
}
