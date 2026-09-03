import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/components.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/web_links.dart';
import '../../../app/widgets/auth_widgets.dart';
import '../../../core/api_exception.dart';
import '../application/auth_controller.dart';

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

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Créer un compte',
      onBack: _back,
      children: [
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
        const SizedBox(height: 18),
        _Consents(
          confirmAge: _confirmAge,
          acceptTerms: _acceptTerms,
          onConfirmAge: (value) => setState(() => _confirmAge = value),
          onAcceptTerms: (value) => setState(() => _acceptTerms = value),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthError(message: _error!),
        ],
        const SizedBox(height: 22),
        GoldButton(
          label: 'Créer mon compte',
          icon: Icons.auto_awesome_outlined,
          loading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _submitting ? null : () => context.go(AppRoutes.login),
          child: const Text("J'ai déjà un compte"),
        ),
      ],
    );
  }
}

/// Les deux consentements exigés à l'inscription, dans un bloc à part : ce
/// n'est pas un réglage anodin, il doit se lire comme un engagement.
class _Consents extends StatelessWidget {
  const _Consents({
    required this.confirmAge,
    required this.acceptTerms,
    required this.onConfirmAge,
    required this.onAcceptTerms,
  });

  final bool confirmAge;
  final bool acceptTerms;
  final ValueChanged<bool> onConfirmAge;
  final ValueChanged<bool> onAcceptTerms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = riftText(context);
    final style = text.small.copyWith(color: text.ink);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            value: confirmAge,
            onChanged: onConfirmAge,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text("J'ai au moins 15 ans.", style: style),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          SwitchListTile.adaptive(
            value: acceptTerms,
            onChanged: onAcceptTerms,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              "J'accepte les conditions d'utilisation et la politique de "
              'confidentialité.',
              style: style,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => openWebPage(context, '/cgu'),
                  // Sans couleur : celle du TextButton (hex) reste appliquée.
                  child: const Text(
                    "Conditions d'utilisation",
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => openWebPage(context, '/confidentialite'),
                  child: const Text(
                    'Confidentialité',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
