import 'package:flutter/material.dart';

import '../../../../app/widgets/rift_avatar.dart';
import '../../domain/room.dart';

/// Médaillon d'un joueur : son avatar cadré sur le visage, ou son initiale.
class PlayAvatar extends StatelessWidget {
  const PlayAvatar({super.key, required this.user, this.size = 44});

  final PlayUser? user;
  final double size;

  @override
  Widget build(BuildContext context) => RiftAvatar(
    url: user?.avatarUrl,
    initial: user?.initial ?? '?',
    size: size,
    borderWidth: 1.5,
  );
}
