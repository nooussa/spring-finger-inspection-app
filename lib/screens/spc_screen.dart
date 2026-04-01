import 'package:flutter/material.dart';
import 'package:inspection_app/theme.dart';

class SpcScreen extends StatelessWidget {
  const SpcScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
          child: Text('SPC — à construire',
              style: TextStyle(color: AppTheme.textSecondary))),
    );
  }
}