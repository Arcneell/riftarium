import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/cards/domain/card.dart';

/// Visuel d'une carte, mis en cache sur l'appareil. Ratio 5/7 en portrait,
/// 7/5 pour les champs de bataille (orientation paysage).
class CardImage extends StatelessWidget {
  const CardImage({
    super.key,
    required this.card,
    this.width,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  final RiftCard card;
  final double? width;
  final double borderRadius;
  final BoxFit fit;

  static const portraitRatio = 5 / 7;

  @override
  Widget build(BuildContext context) {
    final url = card.imageUrl;
    final ratio = card.isLandscape ? 1 / portraitRatio : portraitRatio;
    Widget child = url == null || url.isEmpty
        ? _Placeholder(card: card)
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            placeholder: (context, url) => _Placeholder(card: card, dim: true),
            errorWidget: (context, url, error) => _Placeholder(card: card),
          );
    child = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(aspectRatio: ratio, child: child),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.card, this.dim = false});

  final RiftCard card;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: dim
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Text(
              card.name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
    );
  }
}
