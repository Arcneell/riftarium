import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/design/banners.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../domain/guides.dart';

/// Carte en grand, pincée/zoomée : le geste attendu quand on veut lire le
/// texte d'une carte posée sur un plateau minuscule.
Future<void> showGuideCardZoom(BuildContext context, GuideCard card) {
  if (card.image.isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    barrierColor: RiftColors.night.withValues(alpha: 0.86),
    builder: (context) => _CardZoom(card: card),
  );
}

class _CardZoom extends StatelessWidget {
  const _CardZoom({required this.card});

  final GuideCard card;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: InteractiveViewer(
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(RiftRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: cardThumb(card.image, width: CardArtSize.detail),
                    cacheManager: riftImageCache,
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        card.name,
                        style: text.displaySmall.copyWith(
                          color: RiftColors.onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              card.name,
              textAlign: TextAlign.center,
              style: text.mono.copyWith(color: RiftColors.goldSoft),
            ),
          ],
        ),
      ),
    );
  }
}
