

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final TextEditingController _empId = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String _selectedPoste = 'ingenieur';
  String? _info;
  bool _loading = false;

  final List<String> _postes = [
    'ingenieur',
    'assistant',
    'chef_ligne',
    'responsable',
    'superviseur',
    'manager',
    'admin',
  ];

  ApiService get _api => ref.read(apiServiceProvider);

  Future<void> _addEmployee() async {
    final empId = _empId.text.trim();
    final name = _name.text.trim();
    if (empId.isEmpty || name.isEmpty) {
      setState(() => _info = 'Tous les champs sont requis');
      return;
    }
    setState(() {
      _loading = true;
      _info = null;
    });
    try {
      await _api.createFirstEmployee(empId: empId, name: name, poste: _selectedPoste);
      setState(() {
        _info = '✅ $name ajouté. Vous pouvez maintenant créer un compte.';
        _empId.clear();
        _name.clear();
        _selectedPoste = _postes.first;
      });
    } on ApiException catch (e) {
      setState(() => _info = e.message);
    } catch (e) {
      setState(() => _info = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premier lancement')),
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
                          'Premier lancement',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ajoutez le premier employé IT/RH avant de créer un compte.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _empId,
                          decoration: const InputDecoration(
                            labelText: 'ID Employé',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPoste,
                          items: _postes
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedPoste = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Poste',
                            prefixIcon: Icon(Icons.work_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_info != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.blueBgLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              _info!,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (_info != null) const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _addEmployee,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                : const Text('＋ Ajouter employé'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Continuer →'),
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
