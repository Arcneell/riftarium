import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/banners.dart';
import '../theme.dart';
import 'card_image.dart';

/// Portrait rond d'un joueur : l'avatar est le visuel d'une légende, cadré sur
/// le visage comme sur le site (`.avatar img` : `object-position: 50% 16%`,
/// `scale(1.45)`). Sans avatar, l'initiale sur dégradé or.
class RiftAvatar extends StatelessWidget {
  const RiftAvatar({
    super.key,
    required this.url,
    required this.initial,
    this.size = 40,
    this.landscape = false,
    this.borderColor,
    this.borderWidth = 2,
    this.shadow = false,
  });

  final String? url;
  final String initial;
  final double size;

  /// Champ de bataille en avatar : cadrage `48% 42%`, `scale(1.7)`.
  final bool landscape;
  final Color? borderColor;
  final double borderWidth;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final image = url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: image == null ? RiftColors.goldGradient : null,
        color: image == null ? null : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: borderColor ?? RiftColors.goldSoft.withValues(alpha: 0.7),
          width: borderWidth,
        ),
        boxShadow: shadow ? RiftShadows.soft : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? _Initial(initial: initial, size: size)
          : ClipOval(
              child: Transform.scale(
                scale: landscape ? 1.7 : 1.45,
                // object-position 50% 16% → alignement vertical 16 % du haut.
                alignment: landscape
                    ? const Alignment(-0.04, -0.16)
                    : const Alignment(0, -0.68),
                child: CachedNetworkImage(
                  imageUrl: cardThumb(
                    image,
                    width: (size * 3).clamp(96, 600).round(),
                  ),
                  cacheManager: riftImageCache,
                  fit: BoxFit.cover,
                  alignment: landscape
                      ? const Alignment(-0.04, -0.16)
                      : const Alignment(0, -0.68),
                  errorWidget: (context, url, error) =>
                      _Initial(initial: initial, size: size),
                ),
              ),
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
      initial.isEmpty ? '?' : initial.substring(0, 1).toUpperCase(),
      style: TextStyle(
        fontFamily: RiftFonts.display,
        fontSize: size * 0.44,
        color: Colors.white,
      ),
    ),
  );
}
