import 'package:flutter/material.dart';

import '../../../app/widgets/card_image.dart';
import '../../cards/domain/card.dart';
import '../domain/deck.dart';

/// Briques d'affichage communes aux trois écrans de decks.

/// Montant en euros à la française : `12,50 €`. Null si le prix est inconnu.
String? formatEur(double? amount) {
  if (amount == null) return null;
  return '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
}

/// Libellé du format : le site parle de decks « légaux » et « illégaux ».
String formatLabel(String format) => format == 'free' ? 'illégal' : 'légal';

/// Pastille « Légal » / « Illégal » avec la raison en clair.
class DeckLegalBadge extends StatelessWidget {
  const DeckLegalBadge({super.key, required this.legal, required this.reason});

  /// Deck au format officiel dont tous les contrôles passent.
  final bool legal;
  final String reason;

  /// Pastille d'un deck complet (format + contrôles de l'API).
  factory DeckLegalBadge.forDeck(Deck deck) => DeckLegalBadge(
    legal: deck.isLegal,
    reason: _reason(deck.isTournament, deck.isLegal),
  );

  /// Pastille d'un deck du listing communautaire (`legal` calculé par l'API).
  factory DeckLegalBadge.forCommunity(CommunityDeck deck) => DeckLegalBadge(
    legal: deck.legal,
    reason: _reason(deck.format != 'free', deck.legal),
  );

  static String _reason(bool tournament, bool legal) {
    if (!tournament) {
      return 'Format libre : ce deck ne suit pas les règles officielles.';
    }
    return legal
        ? 'Toutes les règles officielles de construction sont respectées.'
        : 'Ce deck ne respecte pas encore toutes les règles de construction.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = legal ? scheme.primary : scheme.error;
    return Tooltip(
      message: reason,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          legal ? '✓ Légal' : '✕ Illégal',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Vignette de la légende d'un deck (ou un cadre « Sans légende »).
class DeckCover extends StatelessWidget {
  const DeckCover({super.key, required this.legend, this.width = 64});

  final RiftCard? legend;
  final double width;

  @override
  Widget build(BuildContext context) {
    final card = legend;
    if (card != null) return CardImage(card: card, width: width);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: CardImage.portraitRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              'Sans\nlégende',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compteur avec icône : likes, vues.
class DeckStat extends StatelessWidget {
  const DeckStat({
    super.key,
    required this.icon,
    required this.value,
    this.onPressed,
    this.active = false,
    this.semanticLabel,
  });

  final IconData icon;
  final int value;
  final VoidCallback? onPressed;
  final bool active;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.error : scheme.onSurfaceVariant;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$value', style: TextStyle(fontSize: 13, color: color)),
      ],
    );
    if (onPressed == null) {
      return Semantics(label: semanticLabel, child: content);
    }
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Semantics(button: true, label: semanticLabel, child: content),
      ),
    );
  }
}

/// Fiche d'un deck personnel (écran « Mes decks »).
class MyDeckTile extends StatelessWidget {
  const MyDeckTile({
    super.key,
    required this.deck,
    required this.onOpen,
    required this.onDelete,
  });

  final Deck deck;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final legend = deck.legend;
    final price = formatEur(deck.totalEur);
    final meta = <String>[
      '${deck.cardCount} cartes',
      ?price,
      deck.isPublic ? 'public' : 'privé',
      if (deck.isPending) 'en modération',
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeckCover(legend: legend),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deck.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DeckLegalBadge.forDeck(deck),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      legend?.name ?? 'Légende à choisir',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(meta.join(' · '), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DeckStat(
                          icon: Icons.favorite_outline,
                          value: deck.likes,
                          semanticLabel: '${deck.likes} j’aime',
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: onDelete,
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fiche d'un deck public (écran « Communauté »).
class CommunityDeckTile extends StatelessWidget {
  const CommunityDeckTile({
    super.key,
    required this.deck,
    required this.onOpen,
    required this.onLike,
  });

  final CommunityDeck deck;
  final VoidCallback onOpen;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = deck.missingCards;
    final missingCost = formatEur(deck.missingCostEur);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeckCover(legend: deck.legend),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deck.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DeckLegalBadge.forCommunity(deck),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${deck.legend?.name ?? 'Sans légende'} · par ${deck.owner}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${deck.cardCount} cartes',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (missing != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        missing == 0
                            ? 'Complet ✓'
                            : '$missing manquante(s)${missingCost == null ? '' : ' (~$missingCost)'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DeckStat(
                          icon: deck.likedByMe
                              ? Icons.favorite
                              : Icons.favorite_outline,
                          value: deck.likes,
                          active: deck.likedByMe,
                          onPressed: onLike,
                          semanticLabel: deck.likedByMe
                              ? 'Ne plus aimer'
                              : 'Aimer ce deck',
                        ),
                        const SizedBox(width: 12),
                        DeckStat(
                          icon: Icons.visibility_outlined,
                          value: deck.views,
                          semanticLabel: '${deck.views} vue(s)',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
