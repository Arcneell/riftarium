import 'package:flutter/material.dart';

import '../../../../app/design/components.dart';
import '../../../../app/design/reveal.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../domain/card.dart';

/// Vignette de la cartothèque : le visuel d'abord, son code posé dessus, le
/// nom en Marcellus dessous. Une carte que l'on possède brille (reflet foil)
/// et porte sa quantité en pastille dorée.
class CardGridTile extends StatelessWidget {
  const CardGridTile({
    super.key,
    required this.card,
    required this.index,
    required this.imageHeight,
    required this.onPressed,
  });

  final RiftCard card;

  /// Rang dans la grille : décale la révélation en cascade.
  final int index;
  final double imageHeight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final owned = card.ownedQty ?? 0;
    // Le reflet foil tourne en boucle : quand le système demande moins
    // d'animations, on ne le pose pas du tout.
    final shine =
        (card.foil || owned > 0) && !MediaQuery.disableAnimationsOf(context);

    return Reveal(
      index: index,
      child: Semantics(
        button: true,
        label: owned > 0
            ? '${card.name}, ${card.displayCode}, $owned en collection'
            : '${card.name}, ${card.displayCode}',
        child: PressScale(
          onTap: onPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: imageHeight,
                child: Center(
                  // Les pastilles se posent sur le visuel lui-même : un champ
                  // de bataille est plus court que le créneau de la grille.
                  child: Stack(
                    children: [
                      CardImage(
                        card: card,
                        heroTag: 'card-${card.id}',
                        thumbWidth: CardArtSize.tile,
                        foil: shine,
                        foilIntensity: card.foil ? 1 : 0.6,
                      ),
                      // Pastille pleine : le code doit rester lisible quelle
                      // que soit l'illustration derrière.
                      Positioned(
                        left: 5,
                        bottom: 5,
                        child: MonoBadge(label: card.displayCode, filled: true),
                      ),
                      if (owned > 0)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: _OwnedBadge(quantity: owned),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.displaySmall.copyWith(fontSize: 13, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantité possédée : pastille or, la signature de la collection.
class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: RiftColors.goldGradient,
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        boxShadow: RiftShadows.soft,
      ),
      child: Text(
        '×$quantity',
        style: text.mono.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
