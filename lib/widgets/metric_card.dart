

import 'package:flutter/material.dart';
import '../theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final dynamic value; // int ou String
  final Color valueColor;
  final Color bgColor;
  final Color borderColor;
  final String sub;
  final bool isEmpty;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.bgColor,
    required this.borderColor,
    required this.sub,
    this.isEmpty = false,
  });

  factory MetricCard.pass({
    required int value,
    required String sub,
    bool isEmpty = false,
  }) {
    return MetricCard(
      label: 'PASS',
      value: value,
      valueColor: AppTheme.passGreen,
      bgColor: AppTheme.passBgLight,
      borderColor: AppTheme.passGreen.withValues(alpha: 0.3),
      sub: sub,
      isEmpty: isEmpty,
    );
  }

  factory MetricCard.fail({
    required int value,
    required String sub,
    bool isEmpty = false,
  }) {
    return MetricCard(
      label: 'FAIL',
      value: value,
      valueColor: AppTheme.failRed,
      bgColor: AppTheme.failBgLight,
      borderColor: AppTheme.failRed.withValues(alpha: 0.3),
      sub: sub,
      isEmpty: isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: valueColor.withValues(alpha: 0.6),
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? '—' : '$value',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: isEmpty ? AppTheme.textSecondary : valueColor,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: valueColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
