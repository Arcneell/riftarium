import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../cards/domain/card.dart';
import '../../cards/domain/card_labels.dart';

/// Feuille de résultat affichée au bas de l'écran de scan.
///
/// Volontairement sans Riverpod ni routeur : tout arrive en paramètre, ce qui
/// permet de la monter seule dans un test de widget (la caméra, elle, n'est pas
/// testable).
class ScanResultSheet extends StatelessWidget {
  const ScanResultSheet({
    super.key,
    required this.card,
    required this.code,
    required this.addedQty,
    required this.adding,
    required this.addError,
    required this.onAdd,
    required this.onOpenCard,
    required this.onNext,
  });

  final RiftCard card;

  /// Code lu, tel qu'imprimé (« OGN 209/298 »).
  final String? code;

  /// Exemplaires ajoutés depuis cet écran de résultat.
  final int addedQty;
  final bool adding;
  final String? addError;

  final VoidCallback onAdd;
  final VoidCallback onOpenCard;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = card.priceEur;
    final owned = card.ownedQty ?? 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardImage(card: card, width: 62),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code ?? card.displayCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price == null
                          ? 'Prix estimé indisponible'
                          : 'Prix estimé ${formatEuro(price)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: kRiftariumGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owned == 0
                          ? 'Pas encore dans ta collection'
                          : 'Dans ta collection : $owned',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (addError != null) ...[
            const SizedBox(height: 10),
            Text(
              addError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (addedQty > 0) ...[
            const SizedBox(height: 10),
            Text(
              addedQty == 1
                  ? '1 exemplaire ajouté.'
                  : '$addedQty exemplaires ajoutés.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          AdaptiveFilledButton(
            label: '+1 dans ma collection',
            loading: adding,
            onPressed: onAdd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AdaptiveTextButton(label: 'Fiche', onPressed: onOpenCard),
              AdaptiveTextButton(
                label: 'Scanner la suivante',
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
