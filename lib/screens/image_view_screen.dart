// lib/screens/image_view_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/inspection_result.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/status_badge.dart';

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
          backgroundColor: AppTheme.bgWhite,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Détails'),
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
        backgroundColor: AppTheme.bgWhite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(inspection.displayName),
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
                  _buildMeasurementsCard(inspection),
                  const SizedBox(height: 16),
                  _buildDefectsCard(inspection),
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

  Widget _buildMeasurementsCard(InspectionResult inspection) {
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
            'MESURES',
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
                child: _MeasureItem(
                  label: 'Pitch moyen',
                  value: '${inspection.pitchMeanMm.toStringAsFixed(3)} mm',
                ),
              ),
              Expanded(
                child: _MeasureItem(
                  label: 'Largeur totale',
                  value: '${inspection.totalWidthMm.toStringAsFixed(2)} mm',
                  isOk: inspection.totalWidthOk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MeasureItem(
                  label: 'Nb doigts',
                  value: '${inspection.nbFingers}',
                ),
              ),
              Expanded(
                child: _MeasureItem(
                  label: 'MPP',
                  value: inspection.mpp.toStringAsFixed(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefectsCard(InspectionResult inspection) {
    final hasDefects = inspection.nMissing > 0 ||
        inspection.nBent > 0 ||
        inspection.nbAlertes > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasDefects
            ? AppTheme.failRed.withValues(alpha: 0.05)
            : AppTheme.passGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDefects
              ? AppTheme.failRed.withValues(alpha: 0.2)
              : AppTheme.passGreen.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DÉFAUTS',
            style: TextStyle(
              fontSize: 10,
              color: hasDefects ? AppTheme.failRed : AppTheme.passGreen,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DefectItem(
                  label: 'OK',
                  value: inspection.nOk,
                  color: AppTheme.passGreen,
                ),
              ),
              Expanded(
                child: _DefectItem(
                  label: 'Manquants',
                  value: inspection.nMissing,
                  color: inspection.nMissing > 0
                      ? AppTheme.failRed
                      : AppTheme.textSecondary,
                ),
              ),
              Expanded(
                child: _DefectItem(
                  label: 'Pliés',
                  value: inspection.nBent,
                  color: inspection.nBent > 0
                      ? AppTheme.warnOrange
                      : AppTheme.textSecondary,
                ),
              ),
              Expanded(
                child: _DefectItem(
                  label: 'Alertes',
                  value: inspection.nbAlertes,
                  color: inspection.nbAlertes > 0
                      ? AppTheme.warnOrange
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          // Liste des défauts détaillés
          if (inspection.defauts.isNotEmpty) ...[
            const Divider(color: AppTheme.border, height: 20),
            ...inspection.defauts.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.failRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Doigt ${d.fingerNum}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.failRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${d.typeDefaut}${d.description.isNotEmpty ? ' — ${d.description}' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      if (d.ecartMm != 0)
                        Text(
                          '${d.ecartMm.toStringAsFixed(2)} mm',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildFingersCard(InspectionResult inspection) {
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

class _MeasureItem extends StatelessWidget {
  final String label;
  final String value;
  final bool? isOk;

  const _MeasureItem({
    required this.label,
    required this.value,
    this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (isOk != null) ...[
              const SizedBox(width: 4),
              Icon(
                isOk! ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: isOk! ? AppTheme.passGreen : AppTheme.failRed,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DefectItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _DefectItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
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
            child: Text(
              'pitch: ${finger.pitchMm.toStringAsFixed(3)}',
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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
