import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/banners.dart';
import '../design/components.dart';
import '../design/page_banner.dart';
import '../design/reveal.dart';
import '../router.dart';
import '../theme.dart';
import 'profile_action.dart';

/// Écran d'un onglet réservé aux comptes connectés (collection, decks, profil) :
/// bannière de la section, puis une invitation claire à se connecter.
class SignInRequired extends StatelessWidget {
  const SignInRequired({
    super.key,
    required this.title,
    required this.message,
    this.returnTo,
    this.art,
    this.eyebrow,
  });

  final String title;
  final String message;

  /// Chemin vers lequel revenir après connexion (par défaut : l'onglet courant).
  final String? returnTo;

  /// Illustration de la bannière (`RiftBanners.*`) ; cinématique par défaut.
  final String? art;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final from = returnTo ?? GoRouterState.of(context).matchedLocation;
    final text = riftText(context);
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          PageBanner(
            title: title,
            eyebrow: eyebrow,
            art: art ?? RiftBanners.home,
            actions: const [ProfileAction()],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            sliver: SliverToBoxAdapter(
              child: Reveal(
                child: RiftPanel(
                  raised: true,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compte requis'.toUpperCase(), style: text.eyebrow),
                      const SizedBox(height: 6),
                      Text(message, style: text.body),
                      const SizedBox(height: 18),
                      GoldButton(
                        label: 'Se connecter',
                        icon: Icons.login,
                        onPressed: () =>
                            context.push(AppRoutes.loginFrom(from)),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: const Text('Créer un compte'),
                        ),
                      ),
                    ],
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

/// Erreur de chargement : ce qui s'est passé, puis un bouton pour réessayer.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: RiftPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: text.muted),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: text.body),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                GhostButton(
                  label: 'Réessayer',
                  icon: Icons.refresh,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste vide : une invitation à agir, pas un constat.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.auto_awesome_outlined,
    this.action,
  });

  final String title;
  final String? detail;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RiftColors.gold.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 30, color: RiftColors.gold),
            ),
            const SizedBox(height: 14),
            Text(title, style: text.displaySmall, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!, textAlign: TextAlign.center, style: text.small),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Indicateur de chargement centré.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}
