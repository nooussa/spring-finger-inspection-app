import 'package:flutter/material.dart';
import 'package:inspection_app/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('Paramètres')),
      body: const Center(
          child: Text('Settings — à construire',
              style: TextStyle(color: AppTheme.textSecondary))),
    );
  }
}