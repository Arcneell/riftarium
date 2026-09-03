import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../design/reveal.dart';
import '../router.dart';
import '../theme.dart';
import 'rift_avatar.dart';

/// Avatar (ou silhouette) en haut à droite des bannières : ouvre le profil,
/// ou la connexion quand aucune session n'est ouverte. Même geste que le menu
/// du compte derrière l'avatar sur le site.
class ProfileAction extends StatelessWidget {
  const ProfileAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Sélection fine : l'état d'authentification change à chaque
        // rechargement du profil, l'avatar ne dépend que de ces trois valeurs.
        final (signedIn, handle, avatar) = ref.watch(
          authControllerProvider.select(
            (s) => (s.isSignedIn, s.profile?.handle, s.profile?.avatarUrl),
          ),
        );
        final initial = (handle ?? '').isEmpty
            ? null
            : handle![0].toUpperCase();
        // La bannière ajoute déjà 6 px après ses actions : pas de marge ici.
        return PressScale(
          onTap: () => signedIn
              ? context.go(AppRoutes.profile)
              : context.push(
                  AppRoutes.loginFrom(
                    GoRouterState.of(context).matchedLocation,
                  ),
                ),
          child: Semantics(
            button: true,
            label: signedIn ? 'Mon profil' : 'Se connecter',
            child: signedIn
                ? RiftAvatar(
                    url: avatar,
                    initial: initial ?? '?',
                    size: 36,
                    borderColor: Colors.white.withValues(alpha: 0.7),
                    borderWidth: 1.5,
                    shadow: true,
                  )
                : Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RiftColors.goldGradient,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                      boxShadow: RiftShadows.soft,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
