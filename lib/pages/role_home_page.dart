import 'package:flutter/material.dart';
import '../menu_selection_page.dart';
import '../services/api_service.dart';
import 'supervisor_page.dart';

class RoleHomePage extends StatefulWidget {
  const RoleHomePage({
    super.key,
    this.loadUser = ApiService.getUserData,
    this.isAuthenticated = ApiService.isAuthenticated,
    this.supervisorHome = const SupervisorPage(),
    this.promoterHome = const MenuSelectionPage(),
  });

  final Future<Map<String, dynamic>?> Function() loadUser;
  final bool Function() isAuthenticated;
  final Widget supervisorHome;
  final Widget promoterHome;

  @override
  State<RoleHomePage> createState() => _RoleHomePageState();
}

class _RoleHomePageState extends State<RoleHomePage> {
  Widget? _destination;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    setState(() {
      _destination = null;
      _error = null;
    });
    try {
      if (!widget.isAuthenticated()) {
        throw StateError('Sessão expirada. Faça login novamente.');
      }
      final user = await widget.loadUser();
      if (!mounted) return;
      final role = user?['role']?.toString().trim().toLowerCase();
      if (role == null || role.isEmpty) {
        throw StateError('Perfil indisponível. Faça login novamente.');
      }
      if (role != 'supervisor' &&
          role != 'promoter' &&
          role != 'promotor' &&
          role != 'user') {
        throw StateError('Este perfil não tem acesso ao aplicativo de campo.');
      }
      setState(() {
        _destination =
            role == 'supervisor' ? widget.supervisorHome : widget.promoterHome;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_destination != null) return _destination!;
    return Scaffold(
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _loadRole,
                    child: const Text('Tentar novamente'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await ApiService.logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Não foi possível sair: $error')),
                          );
                        }
                      }
                    },
                    child: const Text('Voltar ao login'),
                  ),
                ]),
              ),
      ),
    );
  }
}
