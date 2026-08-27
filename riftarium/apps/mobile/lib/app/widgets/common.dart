import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../adaptive.dart';
import '../router.dart';

/// Écran d'un onglet réservé aux comptes connectés (collection, decks, profil).
class SignInRequired extends StatelessWidget {
  const SignInRequired({
    super.key,
    required this.title,
    required this.message,
    this.returnTo,
  });

  final String title;
  final String message;

  /// Chemin vers lequel revenir après connexion (par défaut : l'onglet courant).
  final String? returnTo;

  @override
  Widget build(BuildContext context) {
    final from = returnTo ?? GoRouterState.of(context).matchedLocation;
    return AdaptiveScaffold(
      title: title,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              AdaptiveFilledButton(
                label: 'Se connecter',
                onPressed: () => context.go(AppRoutes.loginFrom(from)),
              ),
              AdaptiveTextButton(
                label: 'Créer un compte',
                onPressed: () => context.go(AppRoutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Erreur de chargement avec bouton de nouvel essai.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AdaptiveFilledButton(label: 'Réessayer', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste vide : icône, titre, détail optionnel.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? detail;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
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
