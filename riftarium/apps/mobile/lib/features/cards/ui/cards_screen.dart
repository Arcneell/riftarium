import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../application/cards_controller.dart';
import '../data/cards_api.dart';
import '../domain/card_labels.dart';
import 'widgets/card_filters_sheet.dart';
import 'widgets/card_grid_tile.dart';
import 'widgets/pills.dart';

/// Cartothèque : recherche, filtres, grille paginée.
class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  static const _debounceDelay = Duration(milliseconds: 300);

  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(cardFiltersProvider).query ?? '';
    _search.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// La frappe ne déclenche une requête qu'après une pause : le champ appelle
  /// l'API au plus une fois par [_debounceDelay].
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      ref.read(cardFiltersProvider.notifier).setQuery(_search.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Cartes',
      trailing: const _FiltersButton(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AdaptiveTextField(
              controller: _search,
              label: 'Rechercher',
              placeholder: 'Jinx, ogn-202, réaction…',
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              autocorrect: false,
            ),
          ),
          const _ActiveFilters(),
          const _ResultCount(),
          const Expanded(child: _CardsGrid()),
        ],
      ),
    );
  }
}

/// Bouton d'ouverture de la feuille de filtres, avec le nombre de filtres
/// actifs.
class _FiltersButton extends ConsumerWidget {
  const _FiltersButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = _activeFacetCount(ref.watch(cardFiltersProvider));
    if (isCupertino(context)) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => showCardFiltersSheet(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.slider_horizontal_3),
            if (count > 0) Text(' $count'),
          ],
        ),
      );
    }
    return IconButton(
      tooltip: 'Filtres',
      onPressed: () => showCardFiltersSheet(context),
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.tune),
      ),
    );
  }
}

int _activeFacetCount(CardFilters filters) => [
  filters.setId,
  filters.type,
  filters.domain,
  filters.rarity,
  filters.energy,
  filters.owned,
  filters.sort,
].where((value) => value != null).length;

/// Rappel des filtres actifs ; toucher une puce la retire.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(cardFiltersProvider);
    final controller = ref.read(cardFiltersProvider.notifier);
    final sets = ref.watch(cardSetsProvider).valueOrNull ?? const [];

    String setLabel(String setId) {
      for (final set in sets) {
        if (set.setId == setId) return set.label;
      }
      return setId.toUpperCase();
    }

    final pills = <Widget>[
      if (filters.setId != null)
        RemovablePill(
          label: setLabel(filters.setId!),
          onRemove: () => controller.setSetId(null),
        ),
      if (filters.type != null)
        RemovablePill(
          label: typeLabel(filters.type!),
          onRemove: () => controller.setType(null),
        ),
      if (filters.domain != null)
        RemovablePill(
          label: domainLabel(filters.domain!),
          onRemove: () => controller.setDomain(null),
        ),
      if (filters.rarity != null)
        RemovablePill(
          label: rarityLabel(filters.rarity!),
          onRemove: () => controller.setRarity(null),
        ),
      if (filters.energy != null)
        RemovablePill(
          label: 'Coût ${energyLabel(filters.energy!)}',
          onRemove: () => controller.setEnergy(null),
        ),
      if (filters.owned != null)
        RemovablePill(
          label: ownedLabel(filters.owned),
          onRemove: () => controller.setOwned(null),
        ),
      if (filters.sort != null)
        RemovablePill(
          label: 'Tri : ${sortLabel(filters.sort)}',
          onRemove: () => controller.setSort(null),
        ),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: pills.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => pills[index],
      ),
    );
  }
}

/// « N cartes », suivi d'un indicateur pendant le chargement.
class _ResultCount extends ConsumerWidget {
  const _ResultCount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cardsListProvider);
    final theme = Theme.of(context);
    final total = list.valueOrNull?.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Text(
            total == null ? 'Chargement…' : cardCountLabel(total),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (total != null && list.isLoading) ...[
            const SizedBox(width: 8),
            const SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grille responsive et pagination infinie.
class _CardsGrid extends ConsumerStatefulWidget {
  const _CardsGrid();

  @override
  ConsumerState<_CardsGrid> createState() => _CardsGridState();
}

class _CardsGridState extends ConsumerState<_CardsGrid> {
  /// Nombre de vignettes restantes à partir duquel la page suivante part.
  static const _prefetchThreshold = 6;
  static const _horizontalPadding = 16.0;
  static const _gap = 10.0;

  /// Largeur visée d'une vignette : trois colonnes sur un téléphone courant.
  static const _targetTileWidth = 130.0;

  /// Ratio portrait d'un visuel de carte, repris de `CardImage`.
  static const _portraitRatio = 5 / 7;

  void _requestMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(cardsListProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(cardsListProvider);
    final data = list.valueOrNull;

    if (data == null) {
      if (list.hasError) {
        return ErrorView(
          message: _messageOf(list.error),
          onRetry: () => ref.invalidate(cardsListProvider),
        );
      }
      return const LoadingView();
    }

    return RefreshIndicator.adaptive(
      onRefresh: ref.read(cardsListProvider.notifier).refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth - _horizontalPadding * 2;
          final columns = (available / _targetTileWidth).floor().clamp(2, 8);
          final tileWidth = (available - _gap * (columns - 1)) / columns;
          final imageHeight = tileWidth / _portraitRatio;

          return CustomScrollView(
            // La liste doit rester tirable même quand elle tient à l'écran.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (list.hasError)
                SliverToBoxAdapter(
                  child: _InlineNotice(message: _messageOf(list.error)),
                ),
              if (data.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    title: 'Aucune carte',
                    detail: 'Change la recherche ou retire des filtres.',
                    icon: isCupertino(context)
                        ? CupertinoIcons.search
                        : Icons.search_off_outlined,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    4,
                    _horizontalPadding,
                    16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: _gap,
                      mainAxisSpacing: 14,
                      mainAxisExtent: imageHeight + 40,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final card = data.items[index];
                      if (data.hasMore &&
                          !data.loadingMore &&
                          index >= data.items.length - _prefetchThreshold) {
                        _requestMore();
                      }
                      return CardGridTile(
                        card: card,
                        imageHeight: imageHeight,
                        onPressed: () => context.go(AppRoutes.card(card.id)),
                      );
                    }, childCount: data.items.length),
                  ),
                ),
              if (data.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (data.loadMoreError != null)
                SliverToBoxAdapter(
                  child: _InlineNotice(message: data.loadMoreError!),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Message d'erreur discret, quand des cartes sont déjà affichées.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
        ),
      ),
    );
  }
}

String _messageOf(Object? error) =>
    error is ApiException ? error.message : 'Erreur inattendue.';
