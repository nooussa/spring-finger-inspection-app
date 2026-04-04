// lib/widgets/feed_item.dart

import 'package:flutter/material.dart';
import '../models/inspection_result.dart';
import '../theme.dart';

/// Widget de ligne pour le flux d'inspections.
/// Affiche: badge PASS/FAIL, piece_code ou ID, pitch_mean_mm, timestamp.
class FeedItem extends StatelessWidget {
  final InspectionResult inspection;
  final VoidCallback? onTap;

  const FeedItem({
    super.key,
    required this.inspection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPass = inspection.isPass;
    final color = isPass ? AppTheme.passGreen : AppTheme.failRed;
    final bg = isPass ? const Color(0xFF071A0E) : const Color(0xFF1A0707);
    final border = isPass ? const Color(0xFF0F3D1E) : const Color(0xFF3D0F0F);

    final ts = _formatTime(inspection.timestamp);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111318),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1A1D24), width: 0.5),
        ),
        child: Row(
          children: [
            // Badge PASS/FAIL
            Container(
              width: 44,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Text(
                inspection.verdict,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Infos pièce
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inspection.displayName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'pitch ${inspection.pitchMeanMm.toStringAsFixed(3)} mm',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Infos défauts si présents
            if (inspection.nMissing > 0 || inspection.nBent > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (inspection.nMissing > 0)
                      Text(
                        '${inspection.nMissing} manq.',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.failRed,
                        ),
                      ),
                    if (inspection.nBent > 0)
                      Text(
                        '${inspection.nBent} pliés',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.warnAmber,
                        ),
                      ),
                  ],
                ),
              ),
            // Timestamp
            Text(
              ts,
              style: const TextStyle(
                fontSize: 10,
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

/// Widget simplifié pour le flux compact
class FeedItemCompact extends StatelessWidget {
  final InspectionResult inspection;
  final VoidCallback? onTap;

  const FeedItemCompact({
    super.key,
    required this.inspection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPass = inspection.isPass;
    final color = isPass ? AppTheme.passGreen : AppTheme.failRed;

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        isPass ? Icons.check_circle : Icons.cancel,
        color: color,
        size: 20,
      ),
      title: Text(
        inspection.displayName,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        'pitch ${inspection.pitchMeanMm.toStringAsFixed(3)} mm',
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      trailing: Text(
        _formatTime(inspection.timestamp),
        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
