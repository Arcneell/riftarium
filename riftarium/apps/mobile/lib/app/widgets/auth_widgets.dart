import 'package:flutter/material.dart';

import '../design/banners.dart';
import '../design/components.dart';
import '../design/page_banner.dart';
import '../design/reveal.dart';
import '../theme.dart';

/// Briques nées des écrans de connexion et reprises partout ailleurs : le
/// squelette de formulaire, le retour posé sur une bannière et le bandeau
/// d'erreur. Elles vivent ici, et non dans `features/auth`, parce que le
/// profil, les amis et le suivi des matchs s'en servent aussi.

/// Squelette commun à la connexion et à l'inscription : bannière cinématique
/// puis le formulaire dans un panneau posé sur le bas de l'illustration,
/// comme sur `AuthView.vue`.
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
                color: RiftColors.night.withValues(alpha: 0.45),
                border: Border.all(
                  color: RiftColors.onAccent.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 19,
                color: RiftColors.onAccent,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RiftColors.fury.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        border: Border.all(color: RiftColors.fury.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: RiftColors.furyText),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: text.small.copyWith(color: RiftColors.furyText),
            ),
          ),
        ],
      ),
    );
  }
}
