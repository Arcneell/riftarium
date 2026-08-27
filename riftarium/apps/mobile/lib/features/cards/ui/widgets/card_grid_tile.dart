import 'package:flutter/material.dart';

import '../../../../app/widgets/card_image.dart';
import '../../domain/card.dart';

/// Vignette de la cartothèque : visuel, nom et code collector.
class CardGridTile extends StatelessWidget {
  const CardGridTile({
    super.key,
    required this.card,
    required this.imageHeight,
    required this.onPressed,
  });

  final RiftCard card;
  final double imageHeight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owned = card.ownedQty ?? 0;
    return Semantics(
      button: true,
      label: '${card.name}, ${card.displayCode}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: CardImage(card: card)),
                  if (owned > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: _OwnedBadge(quantity: owned),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              card.displayCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nombre d'exemplaires possédés, discret sur le coin du visuel.
class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '×$quantity',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
