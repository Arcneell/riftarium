import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
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
          onPressed: () => showAdaptiveMessage(
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

/// Squelette commun à la connexion et à l'inscription : bannière cinématique
/// puis le formulaire dans un panneau parchemin posé sur le bas de
/// l'illustration, comme sur `AuthView.vue`.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          PageBanner(
            title: title,
            eyebrow: 'Riftarium',
            art: RiftBanners.home,
            expandedHeight: 200,
            focus: const Alignment(0.3, -0.2),
            leading: onBack == null
                ? null
                : BannerBackButton(onPressed: onBack!),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Reveal(
                    child: RiftPanel(
                      raised: true,
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Retour posé sur la bannière : pastille encre translucide pour rester lisible
/// quelle que soit l'illustration.
class BannerBackButton extends StatelessWidget {
  const BannerBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: 'Retour',
        child: Semantics(
          button: true,
          label: 'Retour',
          child: PressScale(
            onTap: onPressed,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RiftColors.inkStrong.withValues(alpha: 0.45),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 19,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'erreur : fureur pâle, texte lisible, jamais un rouge criard.
class AuthError extends StatelessWidget {
  const AuthError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RiftColors.fury.withValues(alpha: dark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        border: Border.all(color: RiftColors.fury.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: dark ? RiftColors.fury : RiftColors.furyText,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: text.small.copyWith(
                color: dark ? RiftColors.fury : RiftColors.furyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ouvre une page du site (CGU, confidentialité) dans le navigateur.
Future<void> openWebPage(BuildContext context, String path) async {
  final uri = Uri.parse('${AppConfig.webBaseUrl}$path');
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    await showAdaptiveMessage(
      context,
      title: 'Ouverture impossible',
      message: uri.toString(),
    );
  }
}
