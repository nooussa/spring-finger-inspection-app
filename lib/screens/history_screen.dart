import 'package:flutter/material.dart';
import 'package:inspection_app/theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
          child: Text('Historique — à construire',
              style: TextStyle(color: AppTheme.textSecondary))),
    );
  }
}