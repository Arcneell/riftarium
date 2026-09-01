import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart' show cardThumb;
import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/rift_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/ui/login_screen.dart' show AuthError, BannerBackButton;
import '../../collection/domain/collection.dart';
import '../../decks/ui/deck_widgets.dart' show DeckCover;
import '../../play/domain/history.dart';
import '../../play/domain/play_stats.dart';
import '../application/social_providers.dart';
import '../domain/achievement.dart';
import '../domain/public_profile.dart';
import 'widgets/achievement_widgets.dart';
import 'widgets/social_widgets.dart';

/// Profil public d'un joueur : sa vitrine. On ne publie rien ici, on montre —
/// l'avatar en grand sur l'art de sa légende, ses hauts faits, et seulement ce
/// qu'il a choisi d'ouvrir (stats, collection, decks, historique).
class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.handle});

  final String handle;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  String? _error;

  Future<void> _toggleFollow(PublicProfile profile) async {
    final signedIn = ref.read(authControllerProvider).isSignedIn;
    if (!signedIn) {
      context.push(AppRoutes.loginFrom(AppRoutes.player(widget.handle)));
      return;
    }
    setState(() => _error = null);
    try {
      await ref
          .read(publicProfileProvider(widget.handle).notifier)
          .toggleFollow();
    } on Object catch (error) {
      if (mounted) setState(() => _error = socialErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(publicProfileProvider(widget.handle));
    final notifier = ref.read(publicProfileProvider(widget.handle).notifier);
    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: notifier.reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 268,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              leading: context.canPop()
                  ? BannerBackButton(onPressed: context.pop)
                  : null,
              automaticallyImplyLeading: false,
              // Le pseudo n'apparaît dans la barre qu'une fois la bannière
              // repliée : l'identité le redit déjà juste en dessous.
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final settings = context
                      .dependOnInheritedWidgetOfExactType<
                        FlexibleSpaceBarSettings
                      >();
                  final collapsed =
                      settings != null &&
                      settings.currentExtent <= settings.minExtent + 12;
                  return AnimatedOpacity(
                    duration: RiftMotion.quick,
                    opacity: collapsed ? 1 : 0,
                    child: Text(
                      widget.handle,
                      style: riftText(context).displaySmall,
                    ),
                  );
                },
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _Banner(profile: profile.valueOrNull),
              ),
            ),
            ...profile.when(
              loading: () => const [
                SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: socialErrorMessage(
                      error,
                      fallback: 'Ce joueur est introuvable.',
                    ),
                    onRetry: notifier.reload,
                  ),
                ),
              ],
              data: _body,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(PublicProfile profile) {
    final achievements = profile.achievements;
    final stats = profile.stats;
    final collection = profile.collection;
    final decks = profile.decks;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        sliver: SliverToBoxAdapter(
          child: Reveal(
            child: _Identity(
              profile: profile,
              onFollow: () => _toggleFollow(profile),
            ),
          ),
        ),
      ),
      if (_error != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          sliver: SliverToBoxAdapter(child: AuthError(message: _error!)),
        ),

      // Hauts faits
      const SliverToBoxAdapter(
        child: SectionTitle(eyebrow: 'Palmarès', title: 'Hauts faits'),
      ),
      if (!profile.visibility.showAchievements || achievements == null)
        const SliverToBoxAdapter(child: HiddenNote())
      else if (achievements.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Aucun haut fait débloqué pour l’instant.',
              style: riftText(context).small,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: _AchievementsWrap(achievements: achievements),
          ),
        ),

      // Duels
      const SliverToBoxAdapter(
        child: SectionTitle(eyebrow: 'Parties suivies', title: 'Duels'),
      ),
      if (!profile.visibility.showStats || stats == null)
        const SliverToBoxAdapter(child: HiddenNote())
      else ...[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(child: _Totals(totals: stats.totals)),
        ),
        if (stats.byLegend.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            sliver: SliverToBoxAdapter(
              child: _LegendStats(legends: stats.byLegend.take(5).toList()),
            ),
          ),
      ],

      // Collection
      const SliverToBoxAdapter(
        child: SectionTitle(eyebrow: 'Cartes', title: 'Collection'),
      ),
      if (!profile.visibility.showCollection || collection == null)
        const SliverToBoxAdapter(child: HiddenNote())
      else ...[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: _CollectionSummary(collection: collection),
          ),
        ),
        ..._collectionGrid(),
      ],

      // Decks publics
      const SliverToBoxAdapter(
        child: SectionTitle(eyebrow: 'Constructions', title: 'Decks publics'),
      ),
      if (!profile.visibility.showDecks || decks == null)
        const SliverToBoxAdapter(child: HiddenNote())
      else if (decks.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Aucun deck public pour l’instant.',
              style: riftText(context).small,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverList.separated(
            itemCount: decks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => Reveal(
              index: index,
              child: _DeckBox(deck: decks[index]),
            ),
          ),
        ),

      // Historique
      const SliverToBoxAdapter(
        child: SectionTitle(eyebrow: 'Derniers duels', title: 'Historique'),
      ),
      if (!profile.visibility.showStats)
        const SliverToBoxAdapter(child: HiddenNote())
      else
        ..._history(),

      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ];
  }

  List<Widget> _collectionGrid() {
    final cards = ref.watch(profileCollectionProvider(widget.handle));
    return cards.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: LoadingView(),
          ),
        ),
      ],
      error: (error, _) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          sliver: SliverToBoxAdapter(
            child: AuthError(message: socialErrorMessage(error)),
          ),
        ),
      ],
      data: (page) => [
        _CardsGrid(items: page.items),
        if (page.hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 240,
                  child: GhostButton(
                    label: page.loadingMore
                        ? 'Chargement…'
                        : 'Charger la suite',
                    onPressed: page.loadingMore
                        ? null
                        : () => ref
                              .read(
                                profileCollectionProvider(
                                  widget.handle,
                                ).notifier,
                              )
                              .loadMore(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _history() {
    final history = ref.watch(profileHistoryProvider(widget.handle));
    return history.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: LoadingView(),
          ),
        ),
      ],
      error: (error, _) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          sliver: SliverToBoxAdapter(
            child: AuthError(message: socialErrorMessage(error)),
          ),
        ),
      ],
      data: (page) => page.items.isEmpty
          ? [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Aucune partie suivie terminée.',
                    style: riftText(context).small,
                  ),
                ),
              ),
            ]
          : [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) => Reveal(
                    index: index,
                    child: _HistoryRow(item: page.items[index]),
                  ),
                ),
              ),
            ],
    );
  }
}

/// Bannière : l'art de la légende du joueur, agrandi et flouté comme les
/// panneaux du compteur, puis fondu dans le parchemin. Le portrait, lui, reste
/// net et cadré sur le visage.
class _Banner extends StatelessWidget {
  const _Banner({required this.profile});

  final PublicProfile? profile;

  @override
  Widget build(BuildContext context) {
    final paper = Theme.of(context).scaffoldBackgroundColor;
    final art = profile?.avatarUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (art == null || art.isEmpty)
          const DecoratedBox(
            decoration: BoxDecoration(gradient: RiftColors.goldGradient),
          )
        else
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Image(
              image: CachedNetworkImageProvider(
                cardThumb(art, width: CardArtSize.detail),
                cacheManager: riftImageCache,
              ),
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.4),
              errorBuilder: (context, error, stack) => ColoredBox(color: paper),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                paper.withValues(alpha: 0.1),
                paper.withValues(alpha: 0.55),
                paper,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RiftAvatar(
              url: profile?.avatarUrl,
              initial: profile?.initial ?? '?',
              size: 96,
              borderColor: RiftColors.goldSoft,
              shadow: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pseudo, bio, ancienneté, abonnés et suivis, puis le bouton « Suivre ».
class _Identity extends StatelessWidget {
  const _Identity({required this.profile, required this.onFollow});

  final PublicProfile profile;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final since = profile.createdAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          profile.handle,
          textAlign: TextAlign.center,
          style: text.displayMedium,
        ),
        if (since != null) ...[
          const SizedBox(height: 4),
          Text(
            'Membre depuis le ${formatSocialDate(since)}',
            textAlign: TextAlign.center,
            style: text.small,
          ),
        ],
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(profile.bio, textAlign: TextAlign.center, style: text.body),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Count(value: profile.followersCount, label: 'abonnés'),
            const SizedBox(width: 28),
            _Count(value: profile.followingCount, label: 'suivis'),
          ],
        ),
        if (!profile.isMe) ...[
          const SizedBox(height: 16),
          if (profile.isFollowed)
            GhostButton(
              label: 'Ne plus suivre',
              icon: Icons.person_remove_outlined,
              onPressed: onFollow,
            )
          else
            GoldButton(
              label: 'Suivre',
              icon: Icons.person_add_alt_1,
              onPressed: onFollow,
            ),
        ],
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      children: [
        Text(
          '$value',
          style: text.displaySmall.copyWith(color: RiftColors.gold),
        ),
        Text(label, style: text.small.copyWith(fontSize: 12)),
      ],
    );
  }
}

class _AchievementsWrap extends StatelessWidget {
  const _AchievementsWrap({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final achievement in achievements)
            SizedBox(
              width: 72,
              child: Column(
                children: [
                  AchievementMedallion(achievement: achievement, size: 46),
                  const SizedBox(height: 6),
                  Text(
                    achievement.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: text.small.copyWith(fontSize: 11, height: 1.2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compteurs de duels : parties, victoires, taux, meilleure série.
class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final PlayTotals totals;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final cells = <(String, String)>[
      ('${totals.played}', 'parties'),
      ('${totals.won}', 'victoires'),
      (totals.winRateLabel, 'de réussite'),
      ('${totals.bestStreak}', 'meilleure série'),
    ];
    return RiftPanel(
      child: Row(
        children: [
          for (final (index, cell) in cells.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  Text(
                    cell.$1,
                    maxLines: 1,
                    style: text.displaySmall.copyWith(color: RiftColors.gold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cell.$2,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: text.small.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Les cinq légendes les plus jouées, avec leur bilan.
class _LegendStats extends StatelessWidget {
  const _LegendStats({required this.legends});

  final List<LegendStat> legends;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      child: Column(
        children: [
          for (final (index, legend) in legends.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    legend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyStrong,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${legend.won} / ${legend.played}',
                  style: text.mono.copyWith(color: text.ink),
                ),
              ],
            ),
            const SizedBox(height: 6),
            PrismBar(value: legend.winRatio, height: 6),
          ],
        ],
      ),
    );
  }
}

/// Résumé de collection : cartes différentes, exemplaires, et une barre par
/// set.
class _CollectionSummary extends StatelessWidget {
  const _CollectionSummary({required this.collection});

  final ProfileCollection collection;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${collection.uniqueCards} cartes différentes · '
            '${collection.totalCards} exemplaires',
            style: text.bodyStrong,
          ),
          for (final set in collection.sets) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    set.name.isEmpty ? set.setId : set.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.small.copyWith(color: text.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${set.owned} / ${set.total}', style: text.mono),
              ],
            ),
            const SizedBox(height: 6),
            PrismBar(value: set.ratio, height: 6),
          ],
        ],
      ),
    );
  }
}

/// Grille des cartes possédées : le visuel, sa quantité en pastille.
class _CardsGrid extends StatelessWidget {
  const _CardsGrid({required this.items});

  final List<CollectionItem> items;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final width = constraints.crossAxisExtent;
          final columns = (width / 170).ceil().clamp(2, 6);
          final tileWidth = (width - gap * (columns - 1)) / columns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: 14,
              mainAxisExtent: tileWidth / CardImage.portraitRatio + 26,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return Reveal(
                index: index,
                child: PressScale(
                  onTap: () => context.push(AppRoutes.card(item.card.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Center(child: CardImage(card: item.card)),
                            Positioned(
                              right: 5,
                              top: 5,
                              child: MonoBadge(
                                label: '×${item.totalQty}',
                                filled: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.card.displayCode,
                        textAlign: TextAlign.center,
                        style: riftText(context).mono.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: items.length),
          );
        },
      ),
    );
  }
}

/// Un deck public : sa couverture, son nom, son format et ses likes.
class _DeckBox extends StatelessWidget {
  const _DeckBox({required this.deck});

  final ProfileDeck deck;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      raised: true,
      onTap: () => context.push(AppRoutes.deck(deck.id)),
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeckCover(
            legend: deck.legend,
            domains: deck.legend?.domains ?? const [],
            width: 60,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.displaySmall.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    MonoBadge(
                      label: deck.isTournament ? 'Tournoi' : 'Libre',
                      color: deck.isTournament
                          ? RiftColors.gold
                          : RiftColors.hex,
                    ),
                    MonoBadge(label: '${deck.likes} j’aime'),
                    if (deck.legend != null)
                      MonoBadge(label: deck.legend!.name),
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

/// Une ligne d'historique public : l'adversaire, le score, l'issue.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final color = switch (item.outcome) {
      'win' => RiftColors.calm,
      'loss' => RiftColors.fury,
      _ => text.muted,
    };
    final opponent = item.opponent;
    return RiftPanel(
      onTap: opponent == null || opponent.handle.isEmpty
          ? null
          : () => context.push(AppRoutes.player(opponent.handle)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          RiftAvatar(
            url: opponent?.avatarUrl,
            initial: opponent?.initial ?? '?',
            size: 36,
            borderWidth: 1.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent?.displayName ?? 'Joueur retiré',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.title,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    item.modeLabel,
                    if (item.playedAt != null) formatSocialDate(item.playedAt!),
                  ].join(' · '),
                  style: text.small.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.scoreLabel,
                style: text.monoStrong.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              MonoBadge(label: item.outcomeLabel, color: color),
            ],
          ),
        ],
      ),
    );
  }
}
