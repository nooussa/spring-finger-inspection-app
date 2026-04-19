// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../services/api_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;
  Map<String, dynamic>? _healthData;

  @override
  void initState() {
    super.initState();
    final apiService = ref.read(apiServiceProvider);
    _urlController = TextEditingController(text: apiService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final apiService = ref.read(apiServiceProvider);
    await apiService.setBaseUrl(_urlController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL sauvegardée'),
          backgroundColor: AppTheme.passGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _healthData = null;
    });

    final apiService = ref.read(apiServiceProvider);
    // Sauvegarder d'abord l'URL
    await apiService.setBaseUrl(_urlController.text);

    try {
      final health = await apiService.checkHealth();
      setState(() {
        _testing = false;
        _testSuccess = true;
        _testResult = 'Connexion réussie!';
        _healthData = health;
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testSuccess = false;
        _testResult = 'Échec: $e';
        _healthData = null;
      });
    }
  }

  void _logout() {
    ref.read(authTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Paramètres',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section serveur
            _buildSectionTitle('SERVEUR API'),
            const SizedBox(height: 12),
            _buildServerCard(apiService),
            const SizedBox(height: 24),

            // Section infos DB
            if (_healthData != null) ...[
              _buildSectionTitle('BASE DE DONNÉES'),
              const SizedBox(height: 12),
              _buildDbInfoCard(),
              const SizedBox(height: 24),
            ],

            // Section à propos
            _buildSectionTitle('À PROPOS'),
            const SizedBox(height: 12),
            _buildAboutCard(),
            const SizedBox(height: 24),

            // Bouton déconnexion
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        color: AppTheme.textSecondary,
        letterSpacing: 0.08,
      ),
    );
  }

  Widget _buildServerCard(ApiService apiService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'URL du serveur',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'PC local: http://127.0.0.1:8000  |  Android émulateur: http://10.0.2.2:8000  |  Téléphone: http://IP_DU_PC:8000',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'http://localhost:8000',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: AppTheme.bgWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.passGreen),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onSubmitted: (_) => _saveUrl(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saveUrl,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: const Text('Sauvegarder'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _testing ? null : _testConnection,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.passGreen,
                    foregroundColor: AppTheme.bgWhite,
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.bgWhite,
                          ),
                        )
                      : const Text('Tester'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testSuccess
                    ? AppTheme.passGreen.withValues(alpha: 0.1)
                    : AppTheme.failRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testSuccess
                      ? AppTheme.passGreen.withValues(alpha: 0.3)
                      : AppTheme.failRed.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle : Icons.error,
                    color: _testSuccess ? AppTheme.passGreen : AppTheme.failRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _testSuccess
                            ? AppTheme.passGreen
                            : AppTheme.failRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDbInfoCard() {
    final dbName =
        _healthData?['database'] ?? _healthData?['db_name'] ?? 'pcb_quality';
    final status = _healthData?['status'] ?? 'connected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Base de données', value: dbName.toString()),
          const Divider(color: AppTheme.border, height: 20),
          _InfoRow(
            label: 'Statut',
            value: status.toString().toUpperCase(),
            valueColor: status == 'connected' || status == 'ok'
                ? AppTheme.passGreen
                : AppTheme.failRed,
          ),
          if (_healthData?['version'] != null) ...[
            const Divider(color: AppTheme.border, height: 20),
            _InfoRow(
                label: 'Version API',
                value: _healthData!['version'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: const Column(
        children: [
          _InfoRow(label: 'Application', value: 'PCB Inspector'),
          Divider(color: AppTheme.border, height: 20),
          _InfoRow(label: 'Version', value: '1.0.0'),
          Divider(color: AppTheme.border, height: 20),
          _InfoRow(label: 'Projet', value: 'Contrôle Qualité PCB'),
          Divider(color: AppTheme.border, height: 20),
          _InfoRow(label: 'Technologie', value: 'Flutter + FastAPI'),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    final user = ref.watch(authUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.passGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.passGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? user.login,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        user.role ?? 'Opérateur',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.failRed,
              side: const BorderSide(color: AppTheme.failRed),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
