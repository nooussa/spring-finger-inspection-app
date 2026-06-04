

import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/inspection_result.dart';

class LastInspectionCard extends StatelessWidget {
  final InspectionResult? inspection;
  final VoidCallback? onTap;

  const LastInspectionCard({
    super.key,
    this.inspection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (inspection == null) {
      return _buildEmptyCard();
    }

    final i = inspection!;
    final isPass = i.isPass;
    final color = isPass ? AppTheme.passGreen : AppTheme.failRed;
    final bgColor = isPass ? AppTheme.passBgLight : AppTheme.failBgLight;
    final borderColor = color.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.memory_rounded,
                      color: AppTheme.textSecondary,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'DERNIÈRE PIÈCE',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.08,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: Text(
                    i.verdict,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              i.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _MeasureItem(
                    label: 'Pitch',
                    value: '${i.pitchMeanMm.toStringAsFixed(2)} mm',
                    isOk: i.pitchMeanMm >= 1.15 && i.pitchMeanMm <= 1.25,
                  ),
                ),
                Expanded(
                  child: _MeasureItem(
                    label: 'Largeur',
                    value: '${i.totalWidthMm.toStringAsFixed(2)} mm',
                    isOk: i.totalWidthOk,
                  ),
                ),
                Expanded(
                  child: _MeasureItem(
                    label: 'Doigts',
                    value: '${i.nOk}/${i.nbFingers}',
                    isOk: i.nMissing == 0 && i.nBent == 0,
                  ),
                ),
              ],
            ),

            if (i.nMissing > 0 || i.nBent > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.failBgLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i.nMissing > 0) ...[
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.failRed, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${i.nMissing} manquant${i.nMissing > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.failRed,
                        ),
                      ),
                    ],
                    if (i.nMissing > 0 && i.nBent > 0)
                      const SizedBox(width: 12),
                    if (i.nBent > 0) ...[
                      const Icon(Icons.trending_down_rounded,
                          color: AppTheme.warnOrange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${i.nBent} plié${i.nBent > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.warnOrange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            color: AppTheme.textSecondary,
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            'En attente de la première inspection...',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isOk;

  const _MeasureItem({
    required this.label,
    required this.value,
    required this.isOk,
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
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isOk ? Icons.check_circle : Icons.cancel,
              color: isOk ? AppTheme.passGreen : AppTheme.failRed,
              size: 14,
            ),
          ],
        ),
      ],
    );
  }
}
