import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/api_messages.dart';
import '../../../app/widgets/card_grid_metrics.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/profile_action.dart';
import '../../../app/widgets/search_field.dart';
import '../../auth/application/auth_controller.dart';
import '../../cards/domain/card_labels.dart';
import '../application/collection_controller.dart';
import '../domain/collection.dart';
import 'widgets/collection_edit_sheet.dart';
import 'widgets/collection_sign_in.dart';

/// Onglet Collection : bannière d'inventaire, résumé chiffré, complétion par
/// set, recherche, tri, puis la grille des cartes possédées — chacune avec son
/// reflet foil, la signature visuelle d'une carte que l'on a en main.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _search = TextEditingController();
  bool _progressOpen = false;

  /// Identifiant de la dernière carte déjà mise en cache : tant qu'il ne change
  /// pas, rien de neuf n'est arrivé (une simple longueur se trompe quand une
  /// carte sort de la liste en même temps qu'une autre entre).
  String? _precachedLast;
  int _precachedCount = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () =>
          ref.read(collectionControllerProvider.notifier).search(_search.text),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(collectionProgressProvider);
    await ref.read(collectionControllerProvider.notifier).refresh();
  }

  /// Précharge les vignettes qui viennent d'arriver, pour un défilement sans
  /// squelette. Appelé depuis un `ref.listen`, jamais pendant le build.
  void _precacheNewCards(List<CollectionItem> items) {
    final last = items.isEmpty ? null : items.last.card.id;
    if (last == _precachedLast) return;
    final from = items.length > _precachedCount ? _precachedCount : 0;
    _precachedLast = last;
    _precachedCount = items.length;
    if (items.length <= from) return;
    final arriving = [for (final item in items.sublist(from)) item.card];
    unawaited(precacheCardThumbs(context, arriving));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isSignedIn) {
      return const CollectionSignIn(
        title: 'Ma collection',
        eyebrow: 'Inventaire',
        message: 'Connecte-toi pour suivre ta collection.',
        returnTo: AppRoutes.collection,
      );
    }

    final collection = ref.watch(collectionControllerProvider);
    final state = collection.valueOrNull;
    ref.listen(collectionControllerProvider, (previous, next) {
      final items = next.valueOrNull?.items;
      if (items != null) _precacheNewCards(items);
    });

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            PageBanner(
              title: 'Ma collection',
              eyebrow: auth.profile?.handle ?? 'Inventaire',
              art: RiftBanners.collection,
              actions: const [ProfileAction()],
            ),
            if (state == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: collection.hasError
                    ? ErrorView(
                        message: messageOf(collection.error),
                        onRetry: _refresh,
                      )
                    : const LoadingView(),
              )
            else ...[
              _StatsRow(state: state),
              _ProgressSliver(
                open: _progressOpen,
                onToggle: () => setState(() => _progressOpen = !_progressOpen),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Reveal(
                    index: 4,
                    child: Column(
                      children: [
                        // Le classeur est la vitrine de la collection : c'est
                        // lui qui porte l'action dorée de l'écran.
                        GoldButton(
                          label: 'Ouvrir le classeur',
                          icon: Icons.auto_stories_outlined,
                          onPressed: () => context.go(AppRoutes.binder),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GhostButton(
                                label: 'Scanner',
                                icon: Icons.center_focus_strong_outlined,
                                onPressed: () => context.push(AppRoutes.scan),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GhostButton(
                                label: 'Wishlist',
                                icon: Icons.favorite_border,
                                onPressed: () => context.go(AppRoutes.wishlist),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _SearchSliver(state: state, controller: _search),
              if (state.items.isEmpty)
                SliverToBoxAdapter(
                  child: _Empty(state: state, onClearSearch: _search.clear),
                )
              else
                _CardsGrid(items: state.items),
              if (state.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: SizedBox(
                        width: 240,
                        child: GhostButton(
                          label: state.loadingMore
                              ? 'Chargement…'
                              : 'Charger la suite',
                          onPressed: state.loadingMore
                              ? null
                              : () => unawaited(
                                  ref
                                      .read(
                                        collectionControllerProvider.notifier,
                                      )
                                      .loadMore(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.loadMoreError != null)
                SliverToBoxAdapter(
                  child: _InlineNotice(message: state.loadMoreError!),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Avertissement discret sous la grille : la page suivante n'est pas arrivée,
/// mais les cartes déjà chargées restent en place.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RiftColors.fury.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RiftRadius.sm),
          border: Border.all(color: RiftColors.fury.withValues(alpha: 0.35)),
        ),
        child: Text(message, style: text.small.copyWith(color: text.ink)),
      ),
    );
  }
}

/// Première lettre en capitale : les libellés du domaine sont écrits en
/// minuscule pour s'enchaîner, mais ils ouvrent parfois une ligne.
String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Trois panneaux : cartes différentes, exemplaires, valeur estimée.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final CollectionState state;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      sliver: SliverToBoxAdapter(
        // Les trois panneaux gardent la même hauteur, quel que soit le nombre
        // de lignes de leur libellé.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Stat(
                index: 0,
                label: 'Cartes différentes',
                value: '${state.uniqueCards}',
              ),
              const SizedBox(width: 10),
              _Stat(
                index: 1,
                label: 'Exemplaires',
                value: '${state.totalCards}',
              ),
              const SizedBox(width: 10),
              _Stat(
                index: 2,
                label: 'Valeur estimée',
                value: formatEuroOrNull(state.valueEur) ?? '—',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.index, required this.label, required this.value});

  final int index;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Expanded(
      child: Reveal(
        index: index,
        child: RiftPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: text.displayMedium.copyWith(
                    fontSize: 22,
                    color: RiftColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  style: text.eyebrow.copyWith(color: text.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Complétion par set, repliée par défaut : une barre prismatique par set,
/// le nombre possédé en mono et le coût des cartes manquantes.
class _ProgressSliver extends ConsumerWidget {
  const _ProgressSliver({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionProgressProvider);
    final progress = async.valueOrNull;
    if (progress == null && async.hasError) {
      // Hors ligne ou API en panne : on le dit, on ne masque pas la section
      // (charte : jamais de cache silencieux ni d'écran muet).
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        sliver: SliverToBoxAdapter(
          child: Reveal(
            index: 3,
            child: RiftPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Progression indisponible pour le moment.',
                      style: riftText(context).small,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(collectionProgressProvider),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (progress == null || progress.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final text = riftText(context);
    final overall = progress.overall;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      sliver: SliverToBoxAdapter(
        child: Reveal(
          index: 3,
          child: RiftPanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            onTap: onToggle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  expanded: open,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complétion par set',
                              style: text.displaySmall.copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      MonoBadge(label: '${overall.owned}/${overall.total}'),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: RiftMotion.quick,
                        child: Icon(
                          Icons.expand_more,
                          size: 22,
                          color: text.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PrismBar(value: overall.ratio, height: 10),
                const SizedBox(height: 6),
                Text(
                  '${overall.percent} % · ${_capitalize(overall.missingLabel)}',
                  style: text.mono,
                ),
                if (open) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  for (final row in progress.sets) _ProgressRow(row: row),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.row});

  final SetCompletion row;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyStrong.copyWith(fontSize: 14.5),
                ),
              ),
              const SizedBox(width: 8),
              MonoBadge(label: '${row.owned}/${row.total}'),
            ],
          ),
          const SizedBox(height: 7),
          PrismBar(value: row.ratio),
          const SizedBox(height: 5),
          Text(_capitalize(row.missingLabel), style: text.mono),
        ],
      ),
    );
  }
}

/// Recherche et tri : le champ parchemin puis les puces de tri.
class _SearchSliver extends ConsumerWidget {
  const _SearchSliver({required this.state, required this.controller});

  final CollectionState state;
  final TextEditingController controller;

  static const _sorts = <String, String>{
    '': 'Ordre du set',
    'price_desc': 'Prix décroissant',
    'price_asc': 'Prix croissant',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final notifier = ref.read(collectionControllerProvider.notifier);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      sliver: SliverToBoxAdapter(
        child: Reveal(
          index: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RiftSearchField(controller: controller),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sort in _sorts.entries)
                    FilterChip(
                      label: Text(sort.value),
                      selected: state.sort == sort.key,
                      onSelected: (_) => notifier.setSort(sort.key),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(cardCountLabel(state.total), style: text.mono),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille 3 colonnes : chaque carte possédée reflète, sa quantité en pastille.
class _CardsGrid extends StatelessWidget {
  const _CardsGrid({required this.items});

  final List<CollectionItem> items;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        // Même règle que la cartothèque (`cardGridMetrics`).
        final grid = cardGridMetrics(
          width: constraints.crossAxisExtent,
          gap: gap,
        );
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: grid.columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: 16,
              // Le bloc texte sous le visuel (nom, code, prix, état) tient
              // encore à grande échelle de texte.
              mainAxisExtent: grid.imageHeight + 80,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _CollectionTile(item: items[index], index: index),
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}

/// Une carte possédée : visuel qui brille, quantité en pastille, code, prix,
/// état et langue. L'appui long ouvre la feuille d'édition des lots.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.item, required this.index});

  final CollectionItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final value = formatEuroOrNull(item.valueEur);
    // Quand le système réduit les animations, inutile de monter le reflet :
    // il ne se verrait pas et sa boucle continuerait de tourner.
    final shine = !MediaQuery.disableAnimationsOf(context);
    return Reveal(
      index: index,
      child: Semantics(
        button: true,
        label:
            '${item.card.name}, ${copyCountLabel(item.totalQty)}, '
            '${item.entriesLabel}',
        child: PressScale(
          onTap: () => context.go(AppRoutes.card(item.card.id)),
          onLongPress: () => showCollectionEditor(context, item.card.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CardImage(
                    card: item.card,
                    foil: shine,
                    // Une possédée brille discrètement, une foil à plein.
                    foilIntensity: item.card.foil ? 1 : 0.6,
                    heroTag: 'card-${item.card.id}',
                    shadow: true,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: MonoBadge(label: '×${item.totalQty}', filled: true),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyStrong.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.card.displayCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.mono.copyWith(fontSize: 11.5),
                          ),
                        ),
                        if (value != null)
                          Flexible(
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.mono.copyWith(
                                fontSize: 11.5,
                                color: RiftColors.goldDeep,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      item.entriesLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.mono.copyWith(fontSize: 11.5),
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

/// Collection vide (ou recherche sans résultat) : toujours une invitation.
class _Empty extends StatelessWidget {
  const _Empty({required this.state, required this.onClearSearch});

  final CollectionState state;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final empty = state.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
      child: EmptyView(
        title: empty ? 'Ta collection est vide' : 'Aucune carte ne correspond',
        detail: empty
            ? null
            : 'Essaie un autre nom, un code (ogn-202) ou un type.',
        icon: Icons.style_outlined,
        action: empty
            ? Column(
                children: [
                  GoldButton(
                    label: 'Scanner une carte',
                    icon: Icons.center_focus_strong_outlined,
                    expand: false,
                    onPressed: () => context.push(AppRoutes.scan),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.cards),
                    child: const Text('Parcourir les cartes'),
                  ),
                ],
              )
            : TextButton(
                onPressed: onClearSearch,
                child: const Text('Effacer la recherche'),
              ),
      ),
    );
  }
}
