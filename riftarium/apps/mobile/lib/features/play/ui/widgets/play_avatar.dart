import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../domain/room.dart';

/// Médaillon d'un joueur : son avatar, ou son initiale sur dégradé or.
class PlayAvatar extends StatelessWidget {
  const PlayAvatar({super.key, required this.user, this.size = 44});

  final PlayUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatar == null ? RiftColors.goldGradient : null,
        color: avatar == null ? null : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: RiftColors.goldSoft.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatar == null
          ? _Initial(initial: user?.initial ?? '?', size: size)
          : CachedNetworkImage(
              imageUrl: avatar,
              cacheManager: riftImageCache,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  _Initial(initial: user?.initial ?? '?', size: size),
            ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initial,
      style: TextStyle(
        fontFamily: RiftFonts.display,
        fontSize: size * 0.44,
        color: Colors.white,
      ),
    ),
  );
}
