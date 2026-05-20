// lib/screens/create_account_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  late final TextEditingController _empCtrl;
  late final TextEditingController _loginCtrl;
  late final TextEditingController _pwdCtrl;
  late final TextEditingController _pwd2Ctrl;
  String? _error;
  bool _loading = false;
  Map<String, dynamic>? _employeePreview;

  @override
  void initState() {
    super.initState();
    _empCtrl = TextEditingController();
    _loginCtrl = TextEditingController();
    _pwdCtrl = TextEditingController();
    _pwd2Ctrl = TextEditingController();

    _empCtrl.addListener(_onEmpChanged);
  }

  @override
  void dispose() {
    _empCtrl.removeListener(_onEmpChanged);
    _empCtrl.dispose();
    _loginCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  void _onEmpChanged() {
    final v = _empCtrl.text.trim();
    if (v.isEmpty) {
      setState(() => _employeePreview = null);
      return;
    }
    _fetchEmployee(v);
  }

  Future<void> _fetchEmployee(String empId) async {
    try {
      final api = ref.read(apiServiceProvider);
      final emp = await api.getEmployee(empId: empId);
      if (!mounted) return;
      setState(() => _employeePreview = emp);
    } catch (e) {
      if (!mounted) return;
      setState(() => _employeePreview = null);
    }
  }

  Future<void> _doCreate() async {
    final empId = _empCtrl.text.trim();
    final login = _loginCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    final pwd2 = _pwd2Ctrl.text;

    if (empId.isEmpty || login.isEmpty || pwd.isEmpty || pwd2.isEmpty) {
      setState(() => _error = 'Tous les champs sont requis');
      return;
    }
    if (pwd != pwd2) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    if (pwd.length < 4) {
      setState(() => _error = 'Mot de passe trop court (min 4 caractères)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final user = await api.createAccount(empId: empId, login: login, password: pwd);
      if (!mounted) return;
      // Show success dialog and navigate back to login
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Compte créé'),
          content: Text('Compte créé avec succès. Login : ${user.login}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
      if (!mounted) return;
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erreur réseau: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.22),
              AppTheme.failRed.withValues(alpha: 0.16),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue.withValues(alpha: 0.95),
                                AppTheme.failRed.withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                          child: const Icon(Icons.person_add_alt_1_outlined,
                              color: Colors.white, size: 34),
                        ),
                        const Text(
                          'Créer mon compte',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Votre ID employé détermine automatiquement votre rôle.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _empCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ID Employé (badge)',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_employeePreview != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.blueBgLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_outlined,
                                    color: AppTheme.primaryBlue),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _employeePreview!['full_name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        _employeePreview!['poste'] ?? '',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  (_employeePreview!['role'] ?? '')
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _loginCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Login souhaité',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pwdCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pwd2Ctrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmer mot de passe',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                          ),
                          onSubmitted: (_) => _doCreate(),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.failBgLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.failRed),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppTheme.failRed),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_error!)),
                              ],
                            ),
                          ),
                        if (_error != null) const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _doCreate,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppTheme.primaryBlue,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('CRÉER LE COMPTE'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('← Retour connexion'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
