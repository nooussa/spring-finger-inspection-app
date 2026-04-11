import 'package:flutter/material.dart';
import '../theme.dart';

class GradientBorderBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GradientBorderBox({
    super.key, 
    required this.child, 
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          colors: [
            AppTheme.failRed.withValues(alpha: 0.6),
            AppTheme.primaryBlue.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(11),
        ),
        child: child,
      ),
    );
  }
}
