import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../cards/domain/card.dart';
import '../domain/deck.dart';

/// Briques d'affichage communes aux écrans de decks : boîte de deck, segment
/// « Mes decks | Communauté », couverture de la légende, cœur animé.

/// Durée d'animation annulée quand le système demande moins de mouvement.
Duration riftDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

/// Colonnes d'une grille de cartes (règle 4 du système de design).
int cardColumns(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  if (size.width > size.height) return 4;
  return size.width < 340 ? 2 : 3;
}

/// Montant en euros à la française : `12,50 €`. Null si le prix est inconnu.
String? formatEur(double? amount) {
  if (amount == null) return null;
  return '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
}

/// Libellé du format : le site parle de decks « légaux » et « illégaux ».
String formatLabel(String format) => format == 'free' ? 'illégal' : 'légal';

/// Les six domaines de jeu, dans l'ordre du prisme.
const List<String> filterDomains = [
  'Fury',
  'Order',
  'Body',
  'Calm',
  'Mind',
  'Chaos',
];

/// Nom français d'un domaine (« Fury » → « Fureur »).
String domainLabel(String domain) => DomainChip.labels[domain] ?? domain;

/// Domaines d'un deck : ceux de sa légende, sinon ceux de ses cartes.
List<String> domainsOfDeck(Deck deck) {
  final legend = deck.legend;
  if (legend != null) {
    final colored = legend.domains
        .where((domain) => domain != 'Colorless')
        .toList();
    if (colored.isNotEmpty) return colored;
  }
  final all = <String>{};
  for (final entry in deck.cards) {
    all.addAll(entry.card.domains.where((domain) => domain != 'Colorless'));
  }
  return all.toList();
}

/// Les deux couleurs d'identité d'un deck (`--d1` / `--d2` du site) : les
/// domaines de la légende, complétés par l'or quand il en manque.
List<Color> domainPair(List<String> domains) {
  final colors = domains.map(RiftColors.domain).toList();
  return [
    colors.isEmpty ? RiftColors.gold : colors.first,
    colors.length > 1 ? colors[1] : RiftColors.gold,
  ];
}

/// Légalité affichée : libellé court et couleur.
class DeckLegalState {
  const DeckLegalState({required this.legal, required this.label});

  /// Deck au format officiel dont tous les contrôles passent.
  factory DeckLegalState.forDeck(Deck deck) =>
      DeckLegalState._of(deck.isTournament, deck.isLegal);

  /// Deck du listing communautaire (`legal` calculé par l'API).
  factory DeckLegalState.forCommunity(CommunityDeck deck) =>
      DeckLegalState._of(deck.format != 'free', deck.legal);

  factory DeckLegalState._of(bool tournament, bool legal) {
    if (!tournament) {
      return const DeckLegalState(legal: false, label: 'Illégal');
    }
    return DeckLegalState(legal: legal, label: legal ? 'Légal' : 'Illégal');
  }

  final bool legal;
  final String label;

  Color get color => legal ? RiftColors.calm : RiftColors.fury;
}

/// Pastille « Légal » / « Illégal ».
class DeckLegalBadge extends StatelessWidget {
  const DeckLegalBadge({super.key, required this.state});

  final DeckLegalState state;

  @override
  Widget build(BuildContext context) =>
      MonoBadge(label: state.label, color: state.color);
}

/// Couverture d'une boîte de deck : le visuel de la légende, légèrement
/// incliné au-dessus d'un halo aux couleurs des domaines (comme `DeckBox.vue`).
class DeckCover extends StatelessWidget {
  const DeckCover({
    super.key,
    required this.legend,
    this.domains = const [],
    this.width = 72,
    this.heroTag,
  });

  final RiftCard? legend;
  final List<String> domains;
  final double width;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final pair = domainPair(domains);
    final card = legend;
    return SizedBox(
      width: width + 12,
      child: Center(
        child: Transform.rotate(
          angle: -0.035,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RiftRadius.card),
              boxShadow: [
                BoxShadow(
                  color: pair.first.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
                BoxShadow(
                  color: pair.last.withValues(alpha: 0.26),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: card == null
                ? _EmptyCover(width: width, colors: pair)
                : CardImage(card: card, width: width, heroTag: heroTag),
          ),
        ),
      ),
    );
  }
}

/// Cadre « Sans légende » teinté des domaines connus du deck.
class _EmptyCover extends StatelessWidget {
  const _EmptyCover({required this.width, required this.colors});

  final double width;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: CardImage.portraitRatio,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.first.withValues(alpha: 0.35),
                colors.last.withValues(alpha: 0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(RiftRadius.card),
            border: Border.all(color: RiftColors.goldSoft),
          ),
          alignment: Alignment.center,
          child: Text(
            'Sans légende',
            textAlign: TextAlign.center,
            style: text.mono.copyWith(fontSize: 10.5),
          ),
        ),
      ),
    );
  }
}

/// Cœur animé : bascule le j'aime et affiche le total.
class LikeHeart extends StatelessWidget {
  const LikeHeart({
    super.key,
    required this.likes,
    required this.liked,
    this.onPressed,
    this.onDark = false,
  });

  final int likes;
  final bool liked;
  final VoidCallback? onPressed;

  /// Sur l'en-tête encre de la fiche : le cœur au repos passe en parchemin.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final resting = onDark ? RiftColors.goldSoft : text.muted;
    final color = liked ? RiftColors.chaos : resting;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: riftDuration(context, RiftMotion.quick),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            liked ? Icons.favorite : Icons.favorite_outline,
            key: ValueKey(liked),
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$likes',
          style: text.monoStrong.copyWith(color: color, fontSize: 12.5),
        ),
      ],
    );
    if (onPressed == null) {
      return Semantics(label: '$likes j’aime', child: content);
    }
    return PressScale(
      onTap: onPressed,
      child: Semantics(
        button: true,
        label: liked ? 'Ne plus aimer' : 'Aimer ce deck',
        child: Padding(padding: const EdgeInsets.all(4), child: content),
      ),
    );
  }
}

/// Compteur de vues.
class ViewCount extends StatelessWidget {
  const ViewCount({super.key, required this.views, this.onDark = false});

  final int views;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final color = onDark ? RiftColors.goldSoft : text.muted;
    return Semantics(
      label: '$views vue(s)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            '$views',
            style: text.monoStrong.copyWith(color: color, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Boîte de deck : couverture de la légende, nom Marcellus, domaines, format,
/// nombre de cartes, visibilité et compteurs. Transposition de `DeckBox.vue`.
class DeckBox extends StatelessWidget {
  const DeckBox({
    super.key,
    required this.deckId,
    required this.name,
    required this.legend,
    required this.domains,
    required this.legalState,
    required this.cardCount,
    required this.likes,
    required this.onOpen,
    this.author,
    this.visibility,
    this.pending = false,
    this.likedByMe = false,
    this.views,
    this.priceEur,
    this.missingCards,
    this.missingCostEur,
    this.onLike,
    this.onDelete,
  });

  /// Un de mes decks (`GET /decks/mine`).
  factory DeckBox.mine({
    Key? key,
    required Deck deck,
    required VoidCallback onOpen,
    required VoidCallback onDelete,
  }) => DeckBox(
    key: key,
    deckId: deck.id,
    name: deck.name,
    legend: deck.legend,
    domains: domainsOfDeck(deck),
    legalState: DeckLegalState.forDeck(deck),
    cardCount: deck.cardCount,
    likes: deck.likes,
    likedByMe: deck.likedByMe,
    visibility: deck.isPublic ? 'public' : 'privé',
    pending: deck.isPending,
    priceEur: deck.totalEur,
    onOpen: onOpen,
    onDelete: onDelete,
  );

  /// Un deck du listing communautaire.
  factory DeckBox.shared({
    Key? key,
    required CommunityDeck deck,
    required VoidCallback onOpen,
    required VoidCallback onLike,
  }) => DeckBox(
    key: key,
    deckId: deck.id,
    name: deck.name,
    legend: deck.legend,
    domains: deck.domains,
    legalState: DeckLegalState.forCommunity(deck),
    cardCount: deck.cardCount,
    likes: deck.likes,
    likedByMe: deck.likedByMe,
    views: deck.views,
    author: deck.owner,
    missingCards: deck.missingCards,
    missingCostEur: deck.missingCostEur,
    onOpen: onOpen,
    onLike: onLike,
  );

  final int deckId;
  final String name;
  final RiftCard? legend;
  final List<String> domains;
  final DeckLegalState legalState;
  final int cardCount;
  final int likes;
  final VoidCallback onOpen;
  final String? author;

  /// « public » ou « privé » ; nul sur un deck de la communauté.
  final String? visibility;
  final bool pending;
  final bool likedByMe;
  final int? views;
  final double? priceEur;

  /// Exemplaires manquants dans la collection du visiteur (null si anonyme).
  final int? missingCards;
  final double? missingCostEur;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final price = formatEur(priceEur);
    final missing = missingCards;
    final missingCost = formatEur(missingCostEur);
    final legendName = legend?.name;
    final subtitle = [
      legendName ?? 'Légende à choisir',
      if (author != null) 'par $author',
    ].join(' · ');

    return RiftPanel(
      raised: true,
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeckCover(legend: legend, domains: domains, heroTag: 'deck-$deckId'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: text.displaySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.mono.copyWith(
                    color: legendName == null ? text.muted : RiftColors.gold,
                  ),
                ),
                if (domains.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final domain in domains)
                        DomainChip(domain: domain, compact: true),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    DeckLegalBadge(state: legalState),
                    MonoBadge(label: '$cardCount cartes'),
                    if (price != null) MonoBadge(label: price),
                    if (visibility != null) MonoBadge(label: visibility!),
                    if (pending)
                      const MonoBadge(
                        label: 'en modération',
                        color: RiftColors.order,
                      ),
                    if (missing != null)
                      MonoBadge(
                        label: missing == 0
                            ? 'Complet ✓'
                            : '$missing manquante(s)'
                                  '${missingCost == null ? '' : ' ~$missingCost'}',
                        color: missing == 0
                            ? RiftColors.body
                            : RiftColors.order,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    LikeHeart(
                      likes: likes,
                      liked: likedByMe,
                      onPressed: onLike,
                    ),
                    if (views != null) ...[
                      const SizedBox(width: 12),
                      ViewCount(views: views!),
                    ],
                    const Spacer(),
                    if (onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        tooltip: 'Supprimer',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: text.muted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille d'un choix (filtre, format, onglet de l'éditeur).
///
/// Sans `onTap`, la pastille n'est qu'un libellé : c'est le parent (menu
/// déroulant) qui capte le geste.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.leading,
    this.menu = false,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Vignette placée avant le libellé (légende choisie).
  final Widget? leading;

  /// Ajoute le chevron des pastilles qui ouvrent un menu.
  final bool menu;

  /// Occupe toute la largeur disponible (choix de format d'un formulaire).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? RiftColors.gold : scheme.outline;
    final label0 = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.bodyStrong.copyWith(
        fontSize: 13.5,
        color: selected ? RiftColors.goldDeep : text.ink,
      ),
    );
    final pill = Container(
      padding: EdgeInsets.fromLTRB(leading == null ? 12 : 5, 6, 12, 6),
      decoration: BoxDecoration(
        color: selected ? RiftColors.gold.withValues(alpha: 0.16) : null,
        border: Border.all(color: color, width: selected ? 1.4 : 1),
        borderRadius: BorderRadius.circular(RiftRadius.full),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 7)],
          if (leading == null && icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: selected ? RiftColors.goldDeep : text.muted,
            ),
            const SizedBox(width: 6),
          ],
          expand ? Expanded(child: label0) : Flexible(child: label0),
          if (menu) ...[
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: text.muted),
          ],
        ],
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(onTap: onTap, child: pill),
    );
  }
}

/// Pastille de domaine sélectionnable : la couleur du domaine, atténuée tant
/// qu'elle n'est pas retenue, cerclée d'or une fois active.
class DomainFilterChip extends StatelessWidget {
  const DomainFilterChip({
    super.key,
    required this.domain,
    required this.selected,
    required this.onTap,
  });

  final String domain;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: riftDuration(context, RiftMotion.quick),
          opacity: selected ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RiftRadius.full),
              border: Border.all(
                color: selected ? RiftColors.gold : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: DomainChip(domain: domain),
          ),
        ),
      ),
    );
  }
}

/// Les deux faces de l'onglet Decks.
enum DecksTab { mine, community }

/// Segment épinglé sous la bannière : la communauté reste à un tap, quel que
/// soit l'endroit de la liste où l'on se trouve.
class DecksSegment extends StatelessWidget {
  const DecksSegment({super.key, required this.current});

  final DecksTab current;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _DecksSegmentDelegate(current: current),
  );
}

class _DecksSegmentDelegate extends SliverPersistentHeaderDelegate {
  const _DecksSegmentDelegate({required this.current});

  final DecksTab current;

  static const _height = 72.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      height: _height,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent
                ? theme.colorScheme.outline
                : Colors.transparent,
          ),
        ),
      ),
      child: SegmentedButton<DecksTab>(
        expandedInsets: EdgeInsets.zero,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: DecksTab.mine,
            label: Text(
              'Mes decks',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            icon: Icon(Icons.layers_outlined, size: 18),
          ),
          ButtonSegment(
            value: DecksTab.community,
            label: Text(
              'Communauté',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            icon: Icon(Icons.groups_2_outlined, size: 18),
          ),
        ],
        selected: {current},
        onSelectionChanged: (values) {
          final next = values.first;
          if (next == current) return;
          context.go(
            next == DecksTab.community ? AppRoutes.community : AppRoutes.decks,
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DecksSegmentDelegate oldDelegate) =>
      oldDelegate.current != current;
}

/// Invite de connexion habillée : le segment reste au-dessus, la communauté
/// donc consultable sans compte.
class SignInPanel extends StatelessWidget {
  const SignInPanel({
    super.key,
    required this.title,
    required this.message,
    this.returnTo,
  });

  final String title;
  final String message;

  /// Chemin de retour après connexion (par défaut : l'écran courant).
  final String? returnTo;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final from = returnTo ?? GoRouterState.of(context).matchedLocation;
    return RiftPanel(
      raised: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: RiftColors.gold, size: 28),
          const SizedBox(height: 12),
          Text(title, style: text.displayMedium.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text(message, style: text.body),
          const SizedBox(height: 18),
          GoldButton(
            label: 'Se connecter',
            icon: Icons.login_outlined,
            onPressed: () => context.go(AppRoutes.loginFrom(from)),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.register),
              child: const Text('Créer un compte'),
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide : une invitation à agir, jamais un constat.
class InvitePanel extends StatelessWidget {
  const InvitePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 34, color: RiftColors.goldSoft),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.displayMedium.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: text.small),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
