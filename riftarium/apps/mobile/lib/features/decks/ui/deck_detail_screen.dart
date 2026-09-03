import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/share_origin.dart';
import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../auth/application/auth_controller.dart';
import '../../cards/domain/card.dart';
import '../application/decks_controller.dart';
import '../domain/deck.dart';
import '../domain/deck_code.dart';
import '../domain/deck_rules.dart';
import '../domain/deck_share.dart';
import 'deck_editor_screen.dart';
import 'deck_widgets.dart';

/// Thème sombre figé : l'en-tête de la fiche est toujours sur fond encre, même
/// quand l'application est en clair — les pastilles doivent s'y accorder.
final _inkTheme = buildTheme();

/// Fiche d'un deck : en-tête encre, légalité, cartes par zone, actions.
class DeckDetailScreen extends ConsumerStatefulWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final int deckId;

  @override
  ConsumerState<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends ConsumerState<DeckDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Statistique de visite : lancée après le premier rendu, sans rien bloquer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deckActionsProvider).recordView(widget.deckId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider(widget.deckId));
    final handle = ref.watch(
      authControllerProvider.select((state) => state.profile?.handle),
    );

    return deck.when(
      loading: () => const Scaffold(body: SafeArea(child: LoadingView())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Deck')),
        body: ErrorView(
          message: error is ApiException
              ? error.message
              : 'Impossible de charger ce deck.',
          onRetry: () => ref.invalidate(deckProvider(widget.deckId)),
        ),
      ),
      data: (value) => _DeckView(deck: value, isOwner: value.owner == handle),
    );
  }
}

class _DeckView extends StatelessWidget {
  const _DeckView({required this.deck, required this.isOwner});

  final Deck deck;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final groups = groupDeck(deck.cards);
    final champion = championOf(deck.cards)?.card.id;
    final description = deck.description;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _DeckHeader(deck: deck),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            sliver: SliverToBoxAdapter(child: _Validation(deck: deck)),
          ),
          if (description != null && description.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              sliver: SliverToBoxAdapter(
                child: RiftPanel(child: Text(description, style: text.body)),
              ),
            ),
          for (final zone in deckZones)
            if (groups[zone.key]!.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionTitle(
                  title:
                      '${zone.label} · ${zoneCount(groups, zone.key)}'
                      '/${zone.target}${zone.key == 'main' ? '+' : ''}',
                ),
              ),
              _ZoneGrid(
                entries: groups[zone.key]!,
                landscape: zone.key == 'Battlefield',
                championId: champion,
              ),
            ],
          if (isOwner)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
              sliver: SliverToBoxAdapter(child: _MissingPanel(deck: deck)),
            ),
          if (deck.cards.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
              sliver: SliverToBoxAdapter(
                child: InvitePanel(
                  icon: Icons.style_outlined,
                  title: 'Deck vide',
                  message: 'Ce deck ne contient aucune carte.',
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
      bottomNavigationBar: _ActionBar(deck: deck, isOwner: isOwner),
    );
  }
}

/// En-tête encre : le visuel de la légende flouté en fond, la carte au premier
/// plan (transition partagée depuis la boîte de deck), le nom en Marcellus.
class _DeckHeader extends ConsumerWidget {
  const _DeckHeader({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legend = deck.legend;
    final domains = domainsOfDeck(deck);
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 300,
      backgroundColor: RiftColors.night,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: RiftColors.paper),
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Le nom ne rejoint la barre qu'une fois l'en-tête replié.
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final collapsed =
              settings != null &&
              settings.currentExtent <= settings.minExtent + 12;
          return AnimatedOpacity(
            duration: RiftMotion.quick,
            opacity: collapsed ? 1 : 0,
            child: Text(
              deck.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: riftText(
                context,
              ).displaySmall.copyWith(color: RiftColors.paper),
            ),
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            _HeaderBackdrop(legend: legend, domains: domains),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    RiftColors.night.withValues(alpha: 0.72),
                    RiftColors.night.withValues(alpha: 0.5),
                    RiftColors.night.withValues(alpha: 0.92),
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Theme(
                data: _inkTheme,
                child: _HeaderContent(
                  deck: deck,
                  legend: legend,
                  domains: domains,
                  onLike: () => _toggleLike(context, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(deckActionsProvider).toggleLike(deck.id);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Action impossible',
        message: error.message,
      );
    }
  }
}

/// Fond de l'en-tête : la légende agrandie et floutée, ou les domaines du deck.
class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop({required this.legend, required this.domains});

  final RiftCard? legend;
  final List<String> domains;

  @override
  Widget build(BuildContext context) {
    final card = legend;
    if (card == null || (card.imageUrl ?? '').isEmpty) {
      final pair = domainPair(domains);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              pair.first.withValues(alpha: 0.55),
              pair.last.withValues(alpha: 0.4),
            ],
          ),
        ),
      );
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: CardImage(
          card: card,
          width: 360,
          borderRadius: 0,
          thumbWidth: CardArtSize.detail,
        ),
      ),
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.deck,
    required this.legend,
    required this.domains,
    required this.onLike,
  });

  final Deck deck;
  final RiftCard? legend;
  final List<String> domains;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final card = legend;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (card == null)
          DeckCover(legend: null, domains: domains, width: 88)
        else
          CardImage(
            card: card,
            width: 88,
            shadow: true,
            heroTag: 'deck-${deck.id}',
            thumbWidth: CardArtSize.detail,
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deck.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.displayMedium.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                'par ${deck.owner}',
                style: text.small.copyWith(color: RiftColors.goldSoft),
              ),
              if (domains.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final domain in domains)
                      DomainChip(domain: domain, compact: true),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  MonoBadge(label: '${deck.cardCount} cartes', filled: true),
                  const SizedBox(width: 10),
                  LikeHeart(
                    likes: deck.likes,
                    liked: deck.likedByMe,
                    onDark: true,
                    onPressed: deck.isShareable ? onLike : null,
                  ),
                  const SizedBox(width: 10),
                  ViewCount(views: deck.views, onDark: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Contrôles de construction calculés par l'API (`deck.checks`).
class _Validation extends StatelessWidget {
  const _Validation({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    if (!deck.isTournament) {
      return RiftPanel(
        child: _Line(
          icon: Icons.lock_open_outlined,
          color: text.muted,
          title: 'Format libre',
          detail: 'Les règles officielles ne sont pas vérifiées ici.',
        ),
      );
    }
    final problems = deck.checks.where((check) => !check.ok).toList();
    if (problems.isEmpty) {
      return RiftPanel(
        child: _Line(
          icon: Icons.verified_outlined,
          color: RiftColors.calm,
          title: 'Deck légal',
        ),
      );
    }
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(
            icon: Icons.error_outline,
            color: RiftColors.fury,
            title: 'À corriger',
          ),
          const SizedBox(height: 10),
          for (final check in problems)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.remove, size: 13, color: RiftColors.fury),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      check.message,
                      style: text.small.copyWith(color: text.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne « icône + titre + détail » des panneaux d'état.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.bodyStrong),
              if (detail case final detail?) ...[
                const SizedBox(height: 2),
                Text(detail, style: text.small),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Une zone du deck en vignettes.
class _ZoneGrid extends StatelessWidget {
  const _ZoneGrid({
    required this.entries,
    required this.landscape,
    this.championId,
  });

  final List<DeckCard> entries;
  final bool landscape;
  final String? championId;

  @override
  Widget build(BuildContext context) {
    final columns = landscape
        ? (cardColumns(context) - 1).clamp(1, 3)
        : cardColumns(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: landscape ? 1.15 : 0.62,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) => _DeckCardTile(
          entry: entries[index],
          index: index,
          champion: entries[index].card.id == championId,
        ),
      ),
    );
  }
}

class _DeckCardTile extends StatelessWidget {
  const _DeckCardTile({
    required this.entry,
    required this.index,
    required this.champion,
  });

  final DeckCard entry;
  final int index;

  /// Champion élu : liseré or, comme sur le plateau du site.
  final bool champion;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Reveal(
      index: index,
      child: PressScale(
        onTap: () => context.go(AppRoutes.card(entry.card.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(RiftRadius.card),
                      border: champion
                          ? Border.all(color: RiftColors.gold, width: 2)
                          : null,
                    ),
                    child: CardImage(card: entry.card),
                  ),
                  if (entry.qty > 1)
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: MonoBadge(label: '×${entry.qty}', filled: true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              entry.card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.small.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rappel de la liste d'achats, pour le propriétaire du deck.
class _MissingPanel extends StatelessWidget {
  const _MissingPanel({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ce qu’il te manque', style: text.displaySmall),
          const SizedBox(height: 14),
          GhostButton(
            label: 'Cartes manquantes',
            icon: Icons.shopping_bag_outlined,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => DeckMissingSheet(deckId: deck.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre d'actions épinglée en bas de la fiche.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.deck, required this.isOwner});

  final Deck deck;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: isOwner
                    ? GoldButton(
                        label: 'Modifier',
                        icon: Icons.edit_outlined,
                        onPressed: () => _edit(context),
                      )
                    : GoldButton(
                        label: 'Copier dans mes decks',
                        icon: Icons.copy_all_outlined,
                        onPressed: () => _copy(context, ref),
                      ),
              ),
              IconButton(
                tooltip: 'Partager',
                onPressed: () => _share(context),
                icon: const Icon(Icons.ios_share),
              ),
              IconButton(
                tooltip: 'Copier le code',
                onPressed: () => _copyCode(context),
                icon: const Icon(Icons.tag_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DeckEditorScreen(deck: deck)),
    );
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    if (!ref.read(authControllerProvider).isSignedIn) {
      await showAdaptiveMessage(
        context,
        title: 'Connexion requise',
        message: 'Connecte-toi pour garder ce deck dans ta collection.',
      );
      return;
    }
    try {
      final copy = await ref.read(deckActionsProvider).copy(deck.id);
      if (!context.mounted) return;
      context.go(AppRoutes.deck(copy.id));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Copie impossible',
        message: error.message,
      );
    }
  }

  Future<void> _copyCode(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Clipboard.setData(ClipboardData(text: deckCodeOf(deck.cards)));
      messenger?.showSnackBar(
        const SnackBar(content: Text('Code copié dans le presse-papiers')),
      );
    } on DeckCodeException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Code indisponible',
        message: error.message,
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final lines = <String>[deck.name];
    try {
      lines.add(deckCodeOf(deck.cards));
    } on DeckCodeException {
      // Deck vide : on partage au moins le lien.
    }
    // Liste des noms : lisible par qui n'a pas d'outil pour décoder le code.
    final names = nameList(deck.cards);
    if (names.isNotEmpty) {
      lines.addAll(['', 'Liste des noms :', names]);
    }
    if (deck.isShareable) {
      lines.addAll(['', '${AppConfig.webBaseUrl}/decks/${deck.id}']);
    }
    await SharePlus.instance.share(
      ShareParams(
        text: lines.join('\n'),
        subject: deck.name,
        sharePositionOrigin: shareOriginOf(context),
      ),
    );
  }
}

/// Liste d'achats du deck (`GET /api/decks/{id}/missing`).
class DeckMissingSheet extends ConsumerWidget {
  const DeckMissingSheet({super.key, required this.deckId});

  final int deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(deckMissingProvider(deckId));
    final text = riftText(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
          child: missing.when(
            loading: () => const SizedBox(height: 160, child: LoadingView()),
            error: (error, _) => SizedBox(
              height: 160,
              child: ErrorView(
                message: error is ApiException
                    ? error.message
                    : 'Analyse impossible.',
                onRetry: () => ref.invalidate(deckMissingProvider(deckId)),
              ),
            ),
            data: (value) => value.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'Tu possèdes déjà toutes les cartes de ce deck.',
                      style: text.body,
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        eyebrow: 'À trouver',
                        title: 'Liste d’achats',
                        padding: EdgeInsets.only(bottom: 6),
                      ),
                      Text(
                        'Il te manque ${value.missingTotal} carte(s) sur les '
                        '${value.deckTotal} du deck.',
                        style: text.small,
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: value.items.length,
                          itemBuilder: (context, index) {
                            final item = value.items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CardImage(card: item.card, width: 40),
                              title: Text(item.card.name, style: text.body),
                              subtitle: Text(
                                '${item.missing} à trouver · '
                                '${item.owned}/${item.needed} en collection',
                                style: text.mono,
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                context.go(AppRoutes.card(item.card.id));
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
