

import 'package:flutter/material.dart';
import '../theme.dart';

class KpiRow extends StatelessWidget {
  final int passCount;
  final int failCount;
  final double yieldRate;
  final bool isEmpty;

  const KpiRow({
    super.key,
    required this.passCount,
    required this.failCount,
    required this.yieldRate,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'PASS',
            value: isEmpty ? '—' : '$passCount',
            color: AppTheme.passGreen,
            bgColor: AppTheme.passBgLight,
            borderColor: AppTheme.passGreen.withValues(alpha: 0.3),
            isEmpty: isEmpty,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: 'FAIL',
            value: isEmpty ? '—' : '$failCount',
            color: AppTheme.failRed,
            bgColor: AppTheme.failBgLight,
            borderColor: AppTheme.failRed.withValues(alpha: 0.3),
            isEmpty: isEmpty,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: 'YIELD',
            value: isEmpty ? '—' : '${(yieldRate * 100).toStringAsFixed(0)}%',
            color: _getYieldColor(yieldRate),
            bgColor: AppTheme.bgWhite,
            borderColor: AppTheme.border,
            isEmpty: isEmpty,
          ),
        ),
      ],
    );
  }

  Color _getYieldColor(double rate) {
    if (isEmpty) return AppTheme.textSecondary;
    if (rate >= 0.95) return AppTheme.passGreen;
    if (rate >= 0.88) return AppTheme.warnOrange;
    return AppTheme.failRed;
  }
}

class _KpiCard extends StatefulWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool isEmpty;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.isEmpty = false,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  String _previousValue = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(_KpiCard old) {
    super.didUpdateWidget(old);
    if (widget.value != _previousValue && !widget.isEmpty) {
      _ctrl.forward().then((_) => _ctrl.reverse());
      _previousValue = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.color.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color:
                        widget.isEmpty ? AppTheme.textSecondary : widget.color,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
