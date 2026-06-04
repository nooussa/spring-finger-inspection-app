

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers/inspection_provider.dart';
import '../services/api_service.dart';
import '../widgets/feed_item.dart';
import '../widgets/gradient_border_box.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inspectionFilterProvider);
    final filteredAsync = ref.watch(filteredInspectionsProvider);
    final totalCount = ref.watch(totalCountProvider);
    final apiService = ref.watch(apiServiceProvider);

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
        title: Row(
          children: [
            const Text('Historique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalCount',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [

          _buildFilterBar(ref, filter),

          Expanded(
            child: filteredAsync.when(
              data: (inspections) {
                if (inspections.isEmpty) {
                  return _buildEmptyState(filter);
                }
                return RefreshIndicator(
                  color: AppTheme.passGreen,
                  backgroundColor: AppTheme.bgWhite,
                  onRefresh: () async {
                    ref.invalidate(inspectionHistoryProvider(100));
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: inspections.length,
                    itemBuilder: (context, index) {
                      final inspection = inspections[index];
                      final imageUrl = inspection.imagePath == null ||
                              inspection.imagePath!.isEmpty
                          ? null
                          : '${apiService.baseUrl}/images/${inspection.imagePath}';
                      return FeedItem(
                        inspection: inspection,
                        imageUrl: imageUrl,
                        onTap: () => context.push('/image', extra: inspection),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.passGreen),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.failRed),
                      const SizedBox(height: 16),
                      const Text(
                        'Erreur de chargement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$e',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(inspectionHistoryProvider(100)),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, InspectionFilter current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.bgWhite,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _FilterChip(
            label: 'Tout',
            selected: current == InspectionFilter.all,
            onTap: () => ref.read(inspectionFilterProvider.notifier).state =
                InspectionFilter.all,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'PASS',
            selected: current == InspectionFilter.pass,
            color: AppTheme.passGreen,
            onTap: () => ref.read(inspectionFilterProvider.notifier).state =
                InspectionFilter.pass,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'FAIL',
            selected: current == InspectionFilter.fail,
            color: AppTheme.failRed,
            onTap: () => ref.read(inspectionFilterProvider.notifier).state =
                InspectionFilter.fail,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(InspectionFilter filter) {
    final message = switch (filter) {
      InspectionFilter.all => 'Aucune inspection enregistrée',
      InspectionFilter.pass => 'Aucune inspection PASS',
      InspectionFilter.fail => 'Aucune inspection FAIL',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les inspections apparaîtront ici\nune fois réalisées.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: GradientBorderBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? chipColor : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
