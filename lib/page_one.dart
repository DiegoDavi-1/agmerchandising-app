import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'core/logging/app_logger_v2.dart';

class UmWidget extends StatefulWidget {
  const UmWidget({super.key});

  static String routeName = 'Um';
  static String routePath = '/um';

  @override
  State<UmWidget> createState() => _UmWidgetState();
}

class _UmWidgetState extends State<UmWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Controladores de texto
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Visibilidade da senha
  bool passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (loginController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      _showError('Preencha login e senha');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        loginController.text.trim(),
        passwordController.text,
      );

      if (result['success'] == true && mounted) {
        appLogger.info('✓ Login realizado: ${result['user']?['name'] ?? loginController.text.trim()}');
        Navigator.pushReplacementNamed(context, '/menu');
      } else if (mounted) {
        _showError(result['error']?.toString() ?? 'Login inválido');
      }
    } catch (e) {
      appLogger.error('Erro ao fazer login', error: e);
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Esconde teclado
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Fundo com degradê preto
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    const Color(0xFF1a1a1a),
                    const Color(0xFF2d1b4e),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            // Conteúdo da tela
            Column(
              children: [
                // Logo no topo
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 32,
                    right: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/logo_ag.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E88E5), Color(0xFF1E88E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.shopping_cart,
                              size: 100,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Título
                      Text(
                        'Ag Merchandising',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Conteúdo scrollável abaixo da logo
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Subtítulo
                          Text(
                            'Caso não possua uma conta, solicite a um administrador.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Campo de login
                          TextFormField(
                            controller: loginController,
                            autofocus: true,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Login',
                              labelStyle: GoogleFonts.poppins(color: Colors.white),
                              filled: true,
                              fillColor: const Color(0xFF544A56),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFFABA4AD), width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFF9C3FE4), width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          // Campo de senha
                          TextFormField(
                            controller: passwordController,
                            autofocus: true,
                            obscureText: !passwordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: GoogleFonts.poppins(color: Colors.white),
                              filled: true,
                              fillColor: const Color(0xFF544A56),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFFABA4AD), width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFF9C3FE4), width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  passwordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    passwordVisible = !passwordVisible;
                                  });
                                },
                              ),
                            ),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          // Botão Sign Up
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9C3FE4), Color(0xFFC65647)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: MaterialButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Entrar',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
