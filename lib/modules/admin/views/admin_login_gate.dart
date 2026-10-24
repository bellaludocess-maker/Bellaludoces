import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/bella_brand_logo.dart';
import '../../../core/widgets/sunflower_developer_badge.dart';

/// Portão de autenticação do Aplicativo Administrativo exclusivo da Dona.
/// Garante que apenas pessoas autorizadas acessem o cadastro e estoque.
class AdminLoginGate extends StatefulWidget {
  final Widget authenticatedChild;
  final String requiredPin;

  const AdminLoginGate({
    super.key,
    required this.authenticatedChild,
    this.requiredPin = '2026',
  });

  @override
  State<AdminLoginGate> createState() => _AdminLoginGateState();
}

class _AdminLoginGateState extends State<AdminLoginGate> {
  final _pinController = TextEditingController();
  bool _isAuthenticated = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _handleUnlock() {
    if (_pinController.text.trim() == widget.requiredPin) {
      setState(() {
        _isAuthenticated = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Senha/PIN incorreto. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return widget.authenticatedChild;
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BellaBrandLogo(size: 92)),
                    const SizedBox(height: 16),
                    Text(
                      'Painel Gestor Exclusivo',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Acesso restrito para administração do catálogo da ${AppConstants.storeName}.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      key: const ValueKey('admin_pin_input'),
                      controller: _pinController,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _handleUnlock(),
                      decoration: InputDecoration(
                        labelText: 'Senha / PIN da Loja',
                        hintText: 'Digite a senha de acesso',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        errorText: _errorMessage,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      key: const ValueKey('admin_unlock_button'),
                      onPressed: _handleUnlock,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Entrar no Painel Administrativo'),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: SunflowerDeveloperBadge(
                        compact: true,
                        labelPrefix: 'Tecnologia por',
                        actionHint: 'Suporte e Sistemas • Fale Conosco',
                      ),
                    ),
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
