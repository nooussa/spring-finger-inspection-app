// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _loginCtrl;
  late final TextEditingController _passCtrl;
  bool _loading = false;
  String? _error;
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _loginCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _restoreSession();
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryLogin() async {
    if (_loginCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Login et mot de passe requis');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final readyUrl = await api.ensureBaseUrl();
      if (!mounted) return;
      if (readyUrl == null) {
        setState(() {
          _checkingSession = false;
          _error = 'Serveur non configuré. Contactez l\'administrateur.';
        });
        return;
      }
      final (token, user) = await api.login(
        login: _loginCtrl.text,
        password: _passCtrl.text,
      );

      if (!mounted) return;

      // Stocker le token et l'utilisateur dans Riverpod
      ref.read(authTokenProvider.notifier).state = token;
      ref.read(authUserProvider.notifier).state = user;
      await api.saveAuth(token: token, user: user);

      if (!mounted) return;
      // Naviguer vers le dashboard
      context.go('/');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message.contains('Serveur non accessible')
            ? 'Serveur non configuré. Contactez l\'administrateur.'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Serveur non configuré. Contactez l\'administrateur.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _restoreSession() async {
    final api = ref.read(apiServiceProvider);
    await api.init();

    final readyUrl = await api.ensureBaseUrl();
    if (!mounted) return;
    if (readyUrl == null) {
      setState(() {
        _checkingSession = false;
      });
      return;
    }

    // If server reachable, check if any employee exists. If none, route to setup.
    try {
      final hasAny = await api.hasAnyEmployee();
      if (!mounted) return;
      if (!hasAny) {
        // Show setup screen before login
        context.go('/setup');
        return;
      }
    } catch (_) {
      // ignore - fallback to normal flow
    }

    // Si l'URL est locale, tenter une détection automatique
    final (token, user) = await api.loadAuth();
    if (token != null) {
      final ok = await api.testConnection(api.baseUrl);
      if (!mounted) return;
      if (ok) {
        ref.read(authTokenProvider.notifier).state = token;
        ref.read(authUserProvider.notifier).state = user;
        context.go('/');
        return;
      }
      await api.clearAuth();
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() {
        _checkingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.7),
                AppTheme.failRed.withValues(alpha: 0.7)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Connexion en cours...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.7),
              AppTheme.failRed.withValues(alpha: 0.7)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / Header
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.image,
                              color: AppTheme.primaryBlue,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Starz Quality',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Système de Contrôle Industriel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Login field
                      TextField(
                        controller: _loginCtrl,
                        enabled: !_loading,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Identifiant',
                          labelStyle: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                          hintText: 'Entrez votre identifiant',
                          hintStyle: TextStyle(
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.5),
                              fontSize: 14),
                          prefixIcon: const Icon(Icons.person_outline,
                              color: AppTheme.primaryBlue),
                          filled: true,
                          fillColor: AppTheme.bgLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Colors.transparent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Colors.transparent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password field
                      TextField(
                        controller: _passCtrl,
                        enabled: !_loading,
                        obscureText: true,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          labelStyle: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                          hintText: 'Entrez votre mot de passe',
                          hintStyle: TextStyle(
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.5),
                              fontSize: 14),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppTheme.failRed),
                          filled: true,
                          fillColor: AppTheme.bgLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Colors.transparent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Colors.transparent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppTheme.failRed, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _tryLogin(),
                      ),
                      const SizedBox(height: 28),

                      // Error message
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.failRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.failRed.withValues(alpha: 0.3),
                                width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.failRed, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: AppTheme.failRed,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) const SizedBox(height: 24),

                      // Login button with Gradient
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryBlue.withValues(alpha: 0.9),
                              AppTheme.failRed.withValues(alpha: 0.9)
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _tryLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'SE CONNECTER',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          const Text(
                            'Pas encore de compte ?',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => context.go('/create-account'),
                            child: const Text('Créer mon compte'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
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
