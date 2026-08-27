import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../design/reveal.dart';
import '../router.dart';
import '../theme.dart';
import 'card_image.dart';

/// Avatar (ou silhouette) en haut à droite des bannières : ouvre le profil,
/// ou la connexion quand aucune session n'est ouverte. Même geste que le menu
/// du compte derrière l'avatar sur le site.
class ProfileAction extends StatelessWidget {
  const ProfileAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final auth = ref.watch(authControllerProvider);
        final profile = auth.profile;
        final avatar = profile?.avatarUrl;
        final initial = (profile?.handle ?? '').isEmpty
            ? null
            : profile!.handle[0].toUpperCase();
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: PressScale(
            onTap: () => context.push(
              auth.isSignedIn
                  ? AppRoutes.profile
                  : AppRoutes.loginFrom(
                      GoRouterState.of(context).matchedLocation,
                    ),
            ),
            child: Semantics(
              button: true,
              label: auth.isSignedIn ? 'Mon profil' : 'Se connecter',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: avatar == null ? RiftColors.goldGradient : null,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: RiftShadows.soft,
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar != null
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        cacheManager: riftImageCache,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            _Initial(initial: initial),
                      )
                    : auth.isSignedIn
                    ? _Initial(initial: initial)
                    : const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({this.initial});

  final String? initial;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initial ?? '?',
      style: const TextStyle(
        fontFamily: RiftFonts.display,
        fontSize: 16,
        color: Colors.white,
      ),
    ),
  );
}
