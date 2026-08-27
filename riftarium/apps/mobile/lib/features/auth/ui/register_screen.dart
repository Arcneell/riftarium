import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../core/api_exception.dart';
import '../application/auth_controller.dart';
import 'login_screen.dart';

/// Mêmes bornes que `RegisterIn` côté API (`app/schemas.py`) : la validation
/// locale évite un aller-retour, le serveur reste seul juge.
final _handlePattern = RegExp(r'^[A-Za-z0-9_\-]+$');

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _confirmAge = false;
  bool _acceptTerms = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    final handle = _handle.text.trim();
    if (handle.length < 3 || handle.length > 32) {
      return 'Le pseudo fait entre 3 et 32 caractères.';
    }
    if (!_handlePattern.hasMatch(handle)) {
      return 'Le pseudo ne contient que des lettres, chiffres, _ et -.';
    }
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      return 'Indique une adresse e-mail valide.';
    }
    if (_password.text.length < 8) {
      return 'Le mot de passe fait au moins 8 caractères.';
    }
    if (!_confirmAge) {
      return "L'inscription est réservée aux personnes d'au moins 15 ans.";
    }
    if (!_acceptTerms) {
      return "Veuillez accepter les conditions d'utilisation et la politique "
          'de confidentialité.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signUp(
            handle: _handle.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            acceptTerms: _acceptTerms,
            confirmAge: _confirmAge,
          );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Créer un compte',
      body: AuthFormLayout(
        children: [
          const AuthHeader(
            subtitle: 'Un compte pour ta collection, tes decks et ta wishlist.',
          ),
          AutofillGroup(
            child: Column(
              children: [
                AdaptiveTextField(
                  controller: _handle,
                  label: 'Pseudo',
                  placeholder: '3 à 32 caractères',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newUsername],
                  autocorrect: false,
                ),
                const SizedBox(height: 16),
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
                  placeholder: '8 caractères minimum',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: _confirmAge,
            onChanged: (value) => setState(() => _confirmAge = value),
            title: const Text("J'ai au moins 15 ans."),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile.adaptive(
            value: _acceptTerms,
            onChanged: (value) => setState(() => _acceptTerms = value),
            title: const Text(
              "J'accepte les conditions d'utilisation et la politique de "
              'confidentialité.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthError(message: _error!),
          ],
          const SizedBox(height: 24),
          AdaptiveFilledButton(
            label: 'Créer mon compte',
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          AdaptiveTextButton(
            label: "J'ai déjà un compte",
            onPressed: _submitting ? null : () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
