import 'package:flutter/material.dart';
import 'package:inspection_app/theme.dart';

class ImageViewScreen extends StatelessWidget {
  const ImageViewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
          child: Text('Image — à construire',
              style: TextStyle(color: AppTheme.textSecondary))),
    );
  }
}