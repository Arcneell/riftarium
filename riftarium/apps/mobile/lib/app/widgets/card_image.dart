import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../features/cards/domain/card.dart';
import '../design/banners.dart';
import '../design/foil.dart';
import '../design/shimmer.dart';
import '../theme.dart';

/// Cache disque des visuels : 30 jours, 4 000 fichiers. Les URL sont
/// redimensionnées côté CDN (`w=`) : une vignette pèse ~20 Ko au lieu du PNG
/// complet, et l'image plein format n'est demandée que sur la fiche.
final riftImageCache = CacheManager(
  Config(
    'riftarium-images',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 4000,
  ),
);

/// Largeurs demandées au CDN selon l'usage.
abstract final class CardArtSize {
  static const tile = 360;
  static const detail = 860;
  static const zoom = 1200;
}

/// Précharge les vignettes d'une liste (page suivante d'une grille) : le
/// défilement ne montre alors jamais de squelette.
Future<void> precacheCardThumbs(
  BuildContext context,
  Iterable<RiftCard> cards, {
  int width = CardArtSize.tile,
}) async {
  const batchSize = 4;
  final urls = [
    for (final card in cards)
      if ((card.imageUrl ?? '').isNotEmpty) card.imageUrl!,
  ];
  // Par lots : quatre requêtes en parallèle remplissent le cache bien plus
  // vite qu'une file d'attente, sans saturer le réseau ni le décodeur.
  for (var start = 0; start < urls.length; start += batchSize) {
    if (!context.mounted) return;
    await Future.wait([
      for (final url in urls.skip(start).take(batchSize))
        precacheImage(
          CachedNetworkImageProvider(
            cardThumb(url, width: width),
            cacheManager: riftImageCache,
          ),
          context,
          onError: (_, _) {},
        ),
    ]);
  }
}

/// Visuel d'une carte. Ratio 5/7 (7/5 pour les champs de bataille), coins
/// arrondis, squelette pendant le chargement, fondu à l'arrivée, reflet foil
/// optionnel, `heroTag` pour la transition grille → fiche.
class CardImage extends StatelessWidget {
  const CardImage({
    super.key,
    required this.card,
    this.width,
    this.borderRadius = RiftRadius.card,
    this.fit = BoxFit.cover,
    this.thumbWidth = CardArtSize.tile,
    this.foil = false,
    this.foilIntensity = 1,
    this.heroTag,
    this.shadow = false,
  });

  final RiftCard card;
  final double? width;
  final double borderRadius;
  final BoxFit fit;

  /// Largeur demandée au CDN (pixels).
  final int thumbWidth;

  /// Reflet animé (carte possédée, variante foil).
  final bool foil;
  final double foilIntensity;

  /// Même tag dans la grille et la fiche → transition partagée.
  final Object? heroTag;
  final bool shadow;

  static const portraitRatio = 5 / 7;

  @override
  Widget build(BuildContext context) {
    final url = card.imageUrl;
    final ratio = card.isLandscape ? 1 / portraitRatio : portraitRatio;
    final radius = BorderRadius.circular(borderRadius);

    Widget image = url == null || url.isEmpty
        ? _Placeholder(card: card)
        : CachedNetworkImage(
            imageUrl: cardThumb(url, width: thumbWidth),
            cacheManager: riftImageCache,
            fit: fit,
            fadeInDuration: RiftMotion.base,
            fadeOutDuration: RiftMotion.quick,
            // Décodage à la taille utile : mémoire et défilement plus légers.
            memCacheWidth: thumbWidth,
            placeholder: (context, url) => Shimmer(borderRadius: borderRadius),
            errorWidget: (context, url, error) => _Placeholder(card: card),
          );

    image = ClipRRect(
      borderRadius: radius,
      child: AspectRatio(aspectRatio: ratio, child: image),
    );

    if (foil) {
      image = FoilOverlay(
        intensity: foilIntensity,
        rainbow: card.foil,
        borderRadius: borderRadius,
        child: image,
      );
    }

    if (shadow) {
      // Lumière de vitrine : la carte émet un halo de la couleur de son
      // domaine, en plus de l'ombre portée (miroir du survol web).
      final halo = RiftColors.domain(
        card.domains.isEmpty ? '' : card.domains.first,
      );
      image = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            ...RiftShadows.soft,
            BoxShadow(color: halo.withValues(alpha: 0.24), blurRadius: 26),
          ],
        ),
        child: image,
      );
    }

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return width == null ? image : SizedBox(width: width, child: image);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            RiftColors.goldSoft.withValues(alpha: 0.35),
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Text(
        card.name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: text.displaySmall.copyWith(fontSize: 13),
      ),
    );
  }
}
