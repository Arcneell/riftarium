import 'package:flutter/material.dart';

import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/rift_avatar.dart';
import '../../../../core/api_exception.dart';
import '../../domain/public_profile.dart';
import 'achievement_widgets.dart';

/// Message affichable d'une erreur : les appels API lèvent des [ApiException]
/// dont le texte est déjà rédigé en français.
String socialErrorMessage(
  Object? error, {
  String fallback = 'Contenu indisponible pour le moment.',
}) => error is ApiException ? error.message : fallback;

/// Section qu'un joueur garde pour lui : une ligne discrète, pas une erreur.
class HiddenNote extends StatelessWidget {
  const HiddenNote({
    super.key,
    this.message = 'Ce joueur garde ceci pour lui.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 15, color: text.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: text.small)),
        ],
      ),
    );
  }
}

/// Une ligne de joueur : médaillon, pseudo, une précision, et l'action de
/// droite (inviter dans un salon).
class SocialUserRow extends StatelessWidget {
  const SocialUserRow({
    super.key,
    required this.user,
    required this.onOpen,
    this.subtitle,
    this.trailing,
  });

  final SocialUser user;
  final VoidCallback onOpen;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final detail =
        subtitle ??
        (user.lastMatchAt == null
            ? 'Aucune partie suivie ensemble'
            : 'Dernière partie le ${formatSocialDate(user.lastMatchAt!)}');
    return RiftPanel(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          RiftAvatar(
            url: user.avatarUrl,
            initial: user.initial,
            size: 42,
            borderWidth: 1.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.title,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.small.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
