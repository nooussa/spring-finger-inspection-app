// lib/widgets/status_badge.dart

import 'package:flutter/material.dart';
import '../theme.dart';

/// Badge de statut coloré réutilisable.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool animate;
  final double? fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.animate = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, borderColor) = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (animate)
            _AnimatedDot(color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize ?? 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _getColors() {
    return switch (status.toUpperCase()) {
      'PASS' => (
          AppTheme.passGreen,
          AppTheme.passBgLight,
          AppTheme.passGreen.withValues(alpha: 0.3)
        ),
      'FAIL' => (
          AppTheme.failRed,
          AppTheme.failBgLight,
          AppTheme.failRed.withValues(alpha: 0.3)
        ),
      'LIVE' || 'RUNNING' => (
          AppTheme.passGreen,
          AppTheme.passBgLight,
          AppTheme.passGreen.withValues(alpha: 0.3)
        ),
      'OFF' || 'STOPPED' => (
          AppTheme.failRed,
          AppTheme.failBgLight,
          AppTheme.failRed.withValues(alpha: 0.3)
        ),
      'DÉRIVE' || 'DRIFT' => (
          AppTheme.warnOrange,
          AppTheme.orangeBgLight,
          AppTheme.warnOrange.withValues(alpha: 0.3)
        ),
      'WARN' || 'WARNING' => (
          AppTheme.warnOrange,
          AppTheme.orangeBgLight,
          AppTheme.warnOrange.withValues(alpha: 0.3)
        ),
      _ => (AppTheme.textSecondary, AppTheme.bgLight, AppTheme.border),
    };
  }
}

/// Point animé (clignotant) pour les badges LIVE
class _AnimatedDot extends StatefulWidget {
  final Color color;
  const _AnimatedDot({required this.color});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Badge de connexion API (RUNNING/STOPPED)
class ConnectionBadge extends StatelessWidget {
  final bool connected;

  const ConnectionBadge({
    super.key,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      status: connected ? 'RUNNING' : 'STOPPED',
      animate: connected,
    );
  }
}

/// Badge de dérive SPC
class DriftBadge extends StatelessWidget {
  final bool driftDetected;

  const DriftBadge({
    super.key,
    required this.driftDetected,
  });

  @override
  Widget build(BuildContext context) {
    if (!driftDetected) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.orangeBgLight,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.warnOrange.withValues(alpha: 0.3), width: 0.5),
      ),
      child: const Text(
        'DÉRIVE',
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.warnOrange,
        ),
      ),
    );
  }
}
