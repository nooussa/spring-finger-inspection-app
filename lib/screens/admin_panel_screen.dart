import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../theme.dart';

const Color _adminPurple = Color(0xFF6C4AB6);
const Color _adminBlue = AppTheme.primaryBlue;
const Color _dangerRed = Color(0xFFD32F2F);
const Color _successGreen = Color(0xFF2E7D32);
const Set<String> _adminPostes = {
  'admin',
  'manager',
  'responsable',
  'superviseur',
};
const List<String> _posteOptions = [
  'ingenieur',
  'assistant',
  'chef_ligne',
  'responsable',
  'superviseur',
  'manager',
  'admin',
];

class AdminPanelGate extends ConsumerStatefulWidget {
  final OperatorUser? initialUser;

  const AdminPanelGate({super.key, this.initialUser});

  @override
  ConsumerState<AdminPanelGate> createState() => _AdminPanelGateState();
}

class _AdminPanelGateState extends ConsumerState<AdminPanelGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authUserProvider);
      if (user == null) {
        context.go('/login');
      } else if (!user.isAdmin) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.initialUser ?? ref.watch(authUserProvider);
    if (user == null || !user.isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AdminPanelScreen(initialUser: user);
  }
}

class AdminPanelScreen extends ConsumerStatefulWidget {
  final OperatorUser? initialUser;

  const AdminPanelScreen({super.key, this.initialUser});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  final TextEditingController _operatorSearchCtrl = TextEditingController();
  final TextEditingController _employeeSearchCtrl = TextEditingController();
  final TextEditingController _employeeIdCtrl = TextEditingController();
  final TextEditingController _employeeNameCtrl = TextEditingController();

  final List<_AdminOperator> _operators = [];
  final List<_AdminEmployee> _employees = [];

  bool _loading = false;
  String? _selectedOperatorId;
  String? _selectedEmployeeId;
  String _selectedPoste = _posteOptions.first;

  @override
  void initState() {
    super.initState();
    _operatorSearchCtrl.addListener(() => setState(() {}));
    _employeeSearchCtrl.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _operatorSearchCtrl.dispose();
    _employeeSearchCtrl.dispose();
    _employeeIdCtrl.dispose();
    _employeeNameCtrl.dispose();
    super.dispose();
  }

  ApiService get _api => ref.read(apiServiceProvider);

  String? get _token => ref.read(authTokenProvider);

  OperatorUser? get _currentUser => ref.read(authUserProvider);

  OperatorUser? get _effectiveUser => widget.initialUser ?? _currentUser;

  Future<void> _loadData() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Session introuvable');
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getOperators(token: token),
        _api.getEmployees(token: token),
      ]);

      if (!mounted) return;
      setState(() {
        _operators
          ..clear()
          ..addAll(results[0].map(_AdminOperator.fromJson));
        _employees
          ..clear()
          ..addAll(results[1].map(_AdminEmployee.fromJson));
      });
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _matchesQuery(String query, Iterable<String> values) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return values.any((value) => value.toLowerCase().contains(needle));
  }

  List<_AdminOperator> get _filteredOperators {
    return _operators.where((op) {
      return _matchesQuery(_operatorSearchCtrl.text, [
        op.id,
        op.login,
        op.role,
        op.poste,
        op.employeeId,
        op.displayName,
      ]);
    }).toList();
  }

  List<_AdminEmployee> get _filteredEmployees {
    return _employees.where((emp) {
      return _matchesQuery(_employeeSearchCtrl.text, [
        emp.empId,
        emp.fullName,
        emp.poste,
        emp.role,
        emp.active ? 'actif' : 'inactif',
      ]);
    }).toList();
  }

  _AdminOperator? get _selectedOperator {
    if (_selectedOperatorId == null) return null;
    return _operators
        .where((op) => op.id == _selectedOperatorId)
        .cast<_AdminOperator?>()
        .firstWhere(
          (op) => op != null,
          orElse: () => null,
        );
  }

  _AdminEmployee? get _selectedEmployee {
    if (_selectedEmployeeId == null) return null;
    return _employees
        .where((emp) => emp.empId == _selectedEmployeeId)
        .cast<_AdminEmployee?>()
        .firstWhere(
          (emp) => emp != null,
          orElse: () => null,
        );
  }

  Future<bool> _confirmDeleteOperator(_AdminOperator operator) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer compte'),
            content: Text('Supprimer le compte "${operator.login}" ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _dangerRed),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteSelectedOperator() async {
    final token = _token;
    final operator = _selectedOperator;
    final currentLogin = _currentUser?.login;
    if (token == null || operator == null) return;
    if (operator.login == currentLogin) {
      _showSnack('Vous ne pouvez pas supprimer votre propre compte');
      return;
    }
    final ok = await _confirmDeleteOperator(operator);
    if (!ok) return;

    try {
      await _api.deleteOperator(token: token, operatorId: operator.id);
      _showSnack('Compte supprimé');
      setState(() => _selectedOperatorId = null);
      await _loadData();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _openResetPasswordDialog() async {
    final token = _token;
    final operator = _selectedOperator;
    if (token == null || operator == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newPassword = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser mot de passe'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
            ),
            validator: (value) {
              if (value == null || value.trim().length < 4) {
                return 'Min 4 caractères';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newPassword == null || newPassword.isEmpty) return;

    try {
      await _api.resetPassword(
        token: token,
        operatorId: operator.id,
        newPassword: newPassword,
      );
      _showSnack('Mot de passe réinitialisé');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _deactivateSelectedEmployee() async {
    final token = _token;
    final employee = _selectedEmployee;
    if (token == null || employee == null) return;

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Désactiver employé'),
            content:
                Text('Désactiver "${employee.fullName}" (${employee.empId}) ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _dangerRed),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Désactiver'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    try {
      await _api.deactivateEmployee(token: token, employeeId: employee.empId);
      _showSnack('Employé désactivé');
      setState(() => _selectedEmployeeId = null);
      await _loadData();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _addEmployee() async {
    final token = _token;
    if (token == null) return;

    final empId = _employeeIdCtrl.text.trim();
    final name = _employeeNameCtrl.text.trim();
    final poste = _selectedPoste.trim();

    if (empId.isEmpty || name.isEmpty || poste.isEmpty) {
      _showSnack('Tous les champs sont requis');
      return;
    }

    try {
      await _api.addEmployee(
        token: token,
        empId: empId,
        name: name,
        poste: poste,
      );
      _showSnack('Employé ajouté');
      _employeeIdCtrl.clear();
      _employeeNameCtrl.clear();
      setState(() {
        _selectedPoste = _posteOptions.first;
      });
      await _loadData();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Color get _rolePreviewColor =>
      _adminPostes.contains(_selectedPoste) ? _adminPurple : _adminBlue;

  String get _rolePreviewLabel =>
      _adminPostes.contains(_selectedPoste) ? 'ADMIN' : 'OPERATOR';

  @override
  Widget build(BuildContext context) {
    final currentLogin = _effectiveUser?.login ?? '';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          toolbarHeight: 72,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Gestion des comptes'),
              SizedBox(height: 2),
              Text(
                'Comptes opérateurs, annuaire employé et création rapide',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.bgWhite,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    'Connecté : ${currentLogin.isEmpty ? '-' : currentLogin}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Opérateurs'),
              Tab(text: 'Employés'),
              Tab(text: '+ Ajouter employé'),
            ],
          ),
        ),
        body: _loading && _operators.isEmpty && _employees.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildOperatorsTab(currentLogin),
                  _buildEmployeesTab(),
                  _buildAddEmployeeTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOperatorsTab(String currentLogin) {
    final items = _filteredOperators;
    final selected = _selectedOperator;
    final canDelete = selected != null && selected.login != currentLogin;

    return Column(
      children: [
        _TabHeader(
          title: 'Comptes créés',
          countLabel: '${items.length} comptes',
          searchHint: 'Rechercher un compte',
          controller: _operatorSearchCtrl,
          onRefresh: _loadData,
        ),
        Expanded(
          child: _AdminTableShell(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: MaterialStateProperty.all(
                        AppTheme.blueBgLight,
                      ),
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Login')),
                        DataColumn(label: Text('Rôle')),
                        DataColumn(label: Text('Poste')),
                        DataColumn(label: Text('ID Employé')),
                        DataColumn(label: Text('Nom complet')),
                      ],
                      rows: items.map((op) {
                        final isSelected = op.id == _selectedOperatorId;
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (_) {
                            setState(() {
                              _selectedOperatorId = op.id;
                            });
                          },
                          cells: [
                            DataCell(_tableCell(op.id, width: 110)),
                            DataCell(_tableCell(op.login, width: 150)),
                            DataCell(_tableCell(
                              op.role.toUpperCase(),
                              width: 110,
                              style: TextStyle(
                                color: op.role == 'admin'
                                    ? _adminPurple
                                    : _adminBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            )),
                            DataCell(_tableCell(op.poste, width: 140)),
                            DataCell(_tableCell(
                              op.employeeId.isEmpty ? '—' : op.employeeId,
                              width: 140,
                            )),
                            DataCell(_tableCell(op.displayName, width: 220)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _ActionStrip(
          children: [
            FilledButton.icon(
              onPressed: canDelete ? _deleteSelectedOperator : null,
              style: FilledButton.styleFrom(backgroundColor: _dangerRed),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer compte'),
            ),
            FilledButton.icon(
              onPressed: selected == null ? null : _openResetPasswordDialog,
              style: FilledButton.styleFrom(backgroundColor: _adminBlue),
              icon: const Icon(Icons.lock_reset_outlined),
              label: const Text('Réinitialiser mot de passe'),
            ),
            if (selected != null && !canDelete)
              const Text(
                'Impossible de supprimer votre propre compte',
                style: TextStyle(
                  color: _dangerRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeesTab() {
    final items = _filteredEmployees;

    return Column(
      children: [
        _TabHeader(
          title: 'Annuaire employés',
          countLabel: '${items.length} employés',
          searchHint: 'Rechercher un employé',
          controller: _employeeSearchCtrl,
          onRefresh: _loadData,
        ),
        Expanded(
          child: _AdminTableShell(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 760),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: MaterialStateProperty.all(
                        AppTheme.blueBgLight,
                      ),
                      columns: const [
                        DataColumn(label: Text('ID Employé')),
                        DataColumn(label: Text('Nom complet')),
                        DataColumn(label: Text('Poste')),
                        DataColumn(label: Text('Rôle')),
                        DataColumn(label: Text('Actif')),
                      ],
                      rows: items.map((emp) {
                        final isSelected = emp.empId == _selectedEmployeeId;
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (_) {
                            setState(() {
                              _selectedEmployeeId = emp.empId;
                            });
                          },
                          cells: [
                            DataCell(_tableCell(emp.empId, width: 140)),
                            DataCell(_tableCell(emp.fullName, width: 240)),
                            DataCell(_tableCell(emp.poste, width: 140)),
                            DataCell(_tableCell(
                              emp.role.toUpperCase(),
                              width: 110,
                              style: TextStyle(
                                color: emp.role == 'admin'
                                    ? _adminPurple
                                    : _adminBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            )),
                            DataCell(
                                _tableCell(emp.active ? '✅' : '❌', width: 70)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _ActionStrip(
          children: [
            FilledButton.icon(
              onPressed: _selectedEmployee == null
                  ? null
                  : _deactivateSelectedEmployee,
              style: FilledButton.styleFrom(backgroundColor: _dangerRed),
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Désactiver employé'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddEmployeeTab() {
    final roleColor = _rolePreviewColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            elevation: 0,
            color: AppTheme.bgWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.border, width: 0.6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajouter un employé',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cet employé pourra ensuite créer son compte dans l’application.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _employeeIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ID Employé (badge)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _employeeNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedPoste,
                    decoration: const InputDecoration(labelText: 'Poste'),
                    items: _posteOptions
                        .map(
                          (poste) => DropdownMenuItem(
                            value: poste,
                            child: Text(poste),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedPoste = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '→ Rôle attribué : ${_rolePreviewLabel}',
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addEmployee,
                      style: FilledButton.styleFrom(
                        backgroundColor: _adminPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('＋ Ajouter l\'employé'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableCell(
    String text, {
    double? width,
    TextStyle? style,
  }) {
    final cell = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    if (width == null) {
      return cell;
    }

    return SizedBox(width: width, child: cell);
  }
}

class _TabHeader extends StatelessWidget {
  final String title;
  final String countLabel;
  final String searchHint;
  final TextEditingController controller;
  final VoidCallback onRefresh;

  const _TabHeader({
    required this.title,
    required this.countLabel,
    required this.searchHint,
    required this.controller,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Chip(
                      label: Text(countLabel),
                      backgroundColor: AppTheme.blueBgLight,
                      labelStyle: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rafraîchir',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.bgWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTableShell extends StatelessWidget {
  final Widget child;

  const _AdminTableShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.6),
      ),
      child: child,
    );
  }
}

class _ActionStrip extends StatelessWidget {
  final List<Widget> children;

  const _ActionStrip({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class _AdminOperator {
  final String id;
  final String login;
  final String role;
  final String poste;
  final String employeeId;
  final String displayName;

  _AdminOperator({
    required this.id,
    required this.login,
    required this.role,
    required this.poste,
    required this.employeeId,
    required this.displayName,
  });

  factory _AdminOperator.fromJson(Map<String, dynamic> json) {
    return _AdminOperator(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      login: json['login']?.toString() ?? '',
      role: json['role']?.toString() ?? 'operator',
      poste: json['poste']?.toString() ?? '—',
      employeeId: json['employee_id']?.toString() ?? '—',
      displayName: json['display_name']?.toString() ?? '—',
    );
  }
}

class _AdminEmployee {
  final String empId;
  final String fullName;
  final String poste;
  final String role;
  final bool active;

  _AdminEmployee({
    required this.empId,
    required this.fullName,
    required this.poste,
    required this.role,
    required this.active,
  });

  factory _AdminEmployee.fromJson(Map<String, dynamic> json) {
    return _AdminEmployee(
      empId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      poste: json['poste']?.toString() ?? '—',
      role: json['role']?.toString() ?? 'operator',
      active: json['active'] == true,
    );
  }
}
