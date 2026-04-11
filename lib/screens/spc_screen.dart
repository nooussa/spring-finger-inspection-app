// lib/screens/spc_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers/inspection_provider.dart';

class SpcScreen extends ConsumerWidget {
  const SpcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInspections = ref.watch(inspectionListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.9),
                AppTheme.failRed.withValues(alpha: 0.9),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: const Text(
          'Aperçu Général des Défauts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
          child: asyncInspections.when(
            data: (inspections) {
              if (inspections.isEmpty) {
                return const Center(
                  child: Text(
                    'Aucune donnée d\'inspection.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }

              // Agrégation des défauts
              int totalPiecesCount = inspections.length;
              int defectivePiecesCount = inspections.where((i) => !i.isPass).length;
              int totalMissing = 0;
              int totalBent = 0;
              int totalAlertes = 0;
              Map<String, int> specificDefects = {};

              for (var i in inspections) {
                totalMissing += i.nMissing;
                totalBent += i.nBent;
                totalAlertes += i.nbAlertes;
                for (var d in i.defauts) {
                  specificDefects[d.typeDefaut] =
                      (specificDefects[d.typeDefaut] ?? 0) + 1;
                }
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.black45,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    color: AppTheme.bgWhite,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.analytics,
                            size: 48,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Synthèse des Défauts',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$defectivePiecesCount pièces défectueuses sur $totalPiecesCount inspectées',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Liste des défauts
                          _DefectRow(
                            title: 'Composants Manquants',
                            count: totalMissing,
                            icon: Icons.highlight_off,
                            color: AppTheme.failRed,
                          ),
                          const SizedBox(height: 16),
                          _DefectRow(
                            title: 'Composants Pliés',
                            count: totalBent,
                            icon: Icons.turn_right,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(height: 16),
                          _DefectRow(
                            title: 'Alertes dimensionnelles',
                            count: totalAlertes,
                            icon: Icons.warning_amber_rounded,
                            color: AppTheme.warnOrange,
                          ),

                          if (specificDefects.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text(
                              'Détails spécifiques:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...specificDefects.entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      e.key,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textPrimary),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.bgLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${e.value}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (err, stack) => Center(
              child: Text(
                'Erreur: $err',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      );
  }
}

class _DefectRow extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _DefectRow({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
