import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/biometric_service.dart';

class BiometricAuthPage extends StatefulWidget {
  final Widget nextPage;

  const BiometricAuthPage({
    super.key,
    required this.nextPage,
  });

  @override
  State<BiometricAuthPage> createState() => _BiometricAuthPageState();
}

class _BiometricAuthPageState extends State<BiometricAuthPage> {
  final _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Tentar autenticar automaticamente ao iniciar
    Future.delayed(const Duration(milliseconds: 500), _authenticate);
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final isAuthenticated = await _biometricService.authenticate(
        reason: 'Autentique-se para acessar o aplicativo',
      );

      if (isAuthenticated && mounted) {
        // Autenticação bem-sucedida, navegar para próxima página
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.nextPage),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Autenticação falhou. Tente novamente.';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao autenticar: $e';
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone de impressão digital
              Icon(
                Icons.fingerprint,
                size: 80,
                color: const Color(0xFF9C3FE4),
              ),
              const SizedBox(height: 30),

              // Título
              Text(
                'Autenticação Biométrica',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Subtítulo
              Text(
                _isAuthenticating
                    ? 'Aguarde o reconhecimento...'
                    : 'Use sua impressão digital para continuar',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),

              // Indicador de progresso
              if (_isAuthenticating)
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Color(0xFF9C3FE4),
                    strokeWidth: 3,
                  ),
                ),

              // Mensagem de erro
              if (_errorMessage != null && !_isAuthenticating) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C3FE4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tentar Novamente',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
