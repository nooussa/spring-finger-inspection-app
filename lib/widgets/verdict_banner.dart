// lib/widgets/verdict_banner.dart
// Note: Ce widget n'est plus utilisé dans le nouveau design light.

import 'package:flutter/material.dart';
import '../theme.dart';

class VerdictBanner extends StatefulWidget {
  final double conformityRate;
  final int failCount;
  final double threshold;
  final bool isEmpty;

  const VerdictBanner({
    super.key,
    required this.conformityRate,
    required this.failCount,
    this.threshold = 0.95,
    this.isEmpty = false,
  });

  @override
  State<VerdictBanner> createState() => _VerdictBannerState();
}

class _VerdictBannerState extends State<VerdictBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  bool _previousIsOk = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VerdictBanner old) {
    super.didUpdateWidget(old);
    final isOk = _isProductionOk;
    if (_previousIsOk && !isOk && !widget.isEmpty) {
      _ctrl.forward().then((_) => _ctrl.reverse());
    }
    _previousIsOk = isOk;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isProductionOk =>
      widget.isEmpty || widget.conformityRate >= widget.threshold;

  @override
  Widget build(BuildContext context) {
    if (widget.isEmpty) {
      return _buildBanner(
        icon: Icons.hourglass_empty_rounded,
        label: 'EN ATTENTE',
        color: AppTheme.textSecondary,
        bgColor: AppTheme.bgLight,
        borderColor: AppTheme.border,
      );
    }

    final isOk = _isProductionOk;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: isOk ? 1.0 : _pulse.value,
          child: _buildBanner(
            icon: isOk ? Icons.check_circle_rounded : Icons.error_rounded,
            label: isOk ? 'PRODUCTION OK' : 'FAIL DÉTECTÉ',
            sublabel: isOk
                ? 'Taux: ${(widget.conformityRate * 100).toStringAsFixed(1)}%'
                : '${widget.failCount} défaut${widget.failCount > 1 ? 's' : ''} détecté${widget.failCount > 1 ? 's' : ''}',
            color: isOk ? AppTheme.passGreen : AppTheme.failRed,
            bgColor: isOk ? AppTheme.passBgLight : AppTheme.failBgLight,
            borderColor: (isOk ? AppTheme.passGreen : AppTheme.failRed).withValues(alpha: 0.3),
          ),
        );
      },
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required String label,
    String? sublabel,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
