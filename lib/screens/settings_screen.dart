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
  late final TextEditingController _currentCtrl;
  late final TextEditingController _newCtrl;
  late final TextEditingController _confirmCtrl;
  bool _changing = false;
  String? _changeMessage;
  bool _changeSuccess = false;

  @override
  void initState() {
    super.initState();
    _currentCtrl = TextEditingController();
    _newCtrl = TextEditingController();
    _confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() {
        _changeSuccess = false;
        _changeMessage = 'Tous les champs sont requis';
      });
      return;
    }

    if (next != confirm) {
      setState(() {
        _changeSuccess = false;
        _changeMessage = 'Les mots de passe ne correspondent pas';
      });
      return;
    }

    final token = ref.read(authTokenProvider);
    if (token == null) {
      setState(() {
        _changeSuccess = false;
        _changeMessage = 'Utilisateur non connecté';
      });
      return;
    }

    setState(() {
      _changing = true;
      _changeMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      await api.changePassword(
        token: token,
        currentPassword: current,
        newPassword: next,
      );

      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();

      setState(() {
        _changing = false;
        _changeSuccess = true;
        _changeMessage = 'Mot de passe mis à jour';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _changing = false;
        _changeSuccess = false;
        _changeMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _changing = false;
        _changeSuccess = false;
        _changeMessage = 'Erreur réseau';
      });
    }
  }

  Future<void> _logout() async {
    final api = ref.read(apiServiceProvider);
    await api.clearAuth();
    ref.read(authTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);

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
        title: const Text('Compte',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('INFORMATIONS COMPTE'),
            const SizedBox(height: 12),
            _buildAccountCard(user),
            const SizedBox(height: 24),
            _buildSectionTitle('SÉCURITÉ'),
            const SizedBox(height: 12),
            _buildPasswordCard(),
            const SizedBox(height: 24),
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

  Widget _buildAccountCard(OperatorUser? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          _InfoRow(
              label: 'Nom', value: user?.displayName ?? user?.login ?? '—'),
          const Divider(color: AppTheme.border, height: 20),
          _InfoRow(label: 'Identifiant', value: user?.login ?? '—'),
          const Divider(color: AppTheme.border, height: 20),
          _InfoRow(label: 'Rôle', value: user?.role ?? '—'),
          const Divider(color: AppTheme.border, height: 20),
          _InfoRow(label: 'Matricule', value: user?.employeeId ?? '—'),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe actuel',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmer le nouveau mot de passe',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _changing ? null : _changePassword,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: _changing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Mettre à jour'),
            ),
          ),
          if (_changeMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _changeSuccess
                    ? AppTheme.passGreen.withValues(alpha: 0.1)
                    : AppTheme.failRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _changeSuccess
                      ? AppTheme.passGreen.withValues(alpha: 0.3)
                      : AppTheme.failRed.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _changeSuccess ? Icons.check_circle : Icons.error,
                    color:
                        _changeSuccess ? AppTheme.passGreen : AppTheme.failRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _changeMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _changeSuccess
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

  Widget _buildLogoutButton() {
    return SizedBox(
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
