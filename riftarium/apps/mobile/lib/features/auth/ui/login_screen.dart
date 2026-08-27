import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
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
    return AdaptiveScaffold(
      title: 'Connexion',
      body: AuthFormLayout(
        children: [
          const AuthHeader(
            subtitle: 'Cartothèque, collection et decks Riftbound.',
          ),
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
            const SizedBox(height: 12),
            AuthError(message: _error!),
          ],
          const SizedBox(height: 24),
          AdaptiveFilledButton(
            label: 'Se connecter',
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          AdaptiveTextButton(
            label: 'Créer un compte',
            onPressed: _submitting
                ? null
                : () => context.go(AppRoutes.register),
          ),
          AdaptiveTextButton(
            label: 'Mot de passe oublié ?',
            onPressed: () => showAdaptiveMessage(
              context,
              title: 'Mot de passe oublié',
              message:
                  'La réinitialisation se fait depuis le site : '
                  '${AppConfig.webBaseUrl}/mot-de-passe-oublie',
            ),
          ),
        ],
      ),
    );
  }
}

/// Colonne centrée, largeur bornée, défilement quand le clavier est ouvert.
class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          const Text(
            'Riftarium',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: kRiftariumGold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class AuthError extends StatelessWidget {
  const AuthError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}
