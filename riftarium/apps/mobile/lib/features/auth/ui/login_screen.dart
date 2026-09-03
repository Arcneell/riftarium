import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/components.dart';
import '../../../app/router.dart';
import '../../../app/widgets/auth_widgets.dart';
import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Indique une adresse e-mail valide.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Indique ton mot de passe.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(email: email, password: password);
      // La redirection vers le profil est portée par le routeur.
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Connexion',
      onBack: context.canPop() ? context.pop : null,
      children: [
        AutofillGroup(
          child: Column(
            children: [
              AdaptiveTextField(
                controller: _email,
                label: 'E-mail',
                placeholder: 'toi@exemple.re',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              AdaptiveTextField(
                controller: _password,
                label: 'Mot de passe',
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthError(message: _error!),
        ],
        const SizedBox(height: 22),
        GoldButton(
          label: 'Se connecter',
          icon: Icons.login_outlined,
          loading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _submitting ? null : () => context.go(AppRoutes.register),
          child: const Text('Créer un compte'),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () => showAdaptiveMessage(
                  context,
                  title: 'Mot de passe oublié',
                  message:
                      'La réinitialisation se fait depuis le site : '
                      '${AppConfig.webBaseUrl}/mot-de-passe-oublie',
                ),
          child: const Text('Mot de passe oublié ?'),
        ),
      ],
    );
  }
}
