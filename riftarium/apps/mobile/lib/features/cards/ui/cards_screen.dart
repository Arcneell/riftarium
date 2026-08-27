import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/profile_action.dart';
import '../../../core/api_exception.dart';
import '../application/cards_controller.dart';
import '../data/cards_api.dart';
import '../domain/card_labels.dart';
import 'widgets/card_filters_sheet.dart';
import 'widgets/card_grid_tile.dart';
import 'widgets/pills.dart';

/// Cartothèque : bannière, recherche épinglée, filtres et grille paginée.
class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  /// La frappe ne part à l'API qu'après une pause.
  static const _debounceDelay = Duration(milliseconds: 300);

  /// Nombre de vignettes restantes à partir duquel la page suivante part.
  static const _prefetchThreshold = 6;
  static const _gap = 10.0;

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

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      ref.read(cardFiltersProvider.notifier).setQuery(_search.text);
    });
  }

  /// Repart d'une cartothèque vierge : facettes et recherche.
  void _resetAll() {
    _search.clear();
    ref.read(cardFiltersProvider.notifier).clearFacets();
    ref.read(cardFiltersProvider.notifier).setQuery('');
  }

  void _requestMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(cardsListProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(cardFiltersProvider);
    final list = ref.watch(cardsListProvider);
    final sets = ref.watch(cardSetsProvider).valueOrNull ?? const [];
    final data = list.valueOrNull;

    // Chaque page reçue est préchargée : le défilement suivant ne montre
    // jamais de squelette.
    ref.listen(cardsListProvider, (previous, next) {
      final items = next.valueOrNull?.items;
      if (items == null || items.isEmpty) return;
      final from = (next.valueOrNull?.page ?? 1) <= 1
          ? 0
          : (previous?.valueOrNull?.items.length ?? 0);
      if (items.length <= from) return;
      unawaited(precacheCardThumbs(context, items.skip(from)));
    });

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: ref.read(cardsListProvider.notifier).refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            PageBanner(
              title: 'Cartothèque',
              eyebrow: _eyebrow(data?.total, sets.length),
              art: RiftBanners.cards,
              focus: const Alignment(0.1, -0.15),
              actions: const [ProfileAction()],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchHeader(
                controller: _search,
                filterCount: _activeFacetCount(filters),
                dark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            const _ActiveFilters(),
            ..._content(list, data),
          ],
        ),
      ),
    );
  }

  /// « 1 248 cartes · 6 sets » : ce que contient la cartothèque, sous le titre.
  String _eyebrow(int? total, int sets) {
    final cards = total == null ? 'Chargement…' : cardCountLabel(total);
    if (sets == 0) return cards;
    return '$cards · $sets ${sets == 1 ? 'set' : 'sets'}';
  }

  List<Widget> _content(AsyncValue<CardsList> list, CardsList? data) {
    if (data == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: list.hasError
              ? ErrorView(
                  message: _messageOf(list.error),
                  onRetry: () => ref.invalidate(cardsListProvider),
                )
              : const LoadingView(),
        ),
      ];
    }

    if (data.items.isEmpty) {
      final filters = ref.read(cardFiltersProvider);
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            title: 'Aucune carte',
            detail: 'Change la recherche ou retire des filtres.',
            icon: Icons.search_off_outlined,
            action: filters.isEmpty
                ? GhostButton(
                    label: 'Recharger la cartothèque',
                    onPressed: () => ref.invalidate(cardsListProvider),
                  )
                : GhostButton(
                    label: 'Repartir de zéro',
                    icon: Icons.restart_alt,
                    onPressed: _resetAll,
                  ),
          ),
        ),
      ];
    }

    return [
      if (list.hasError)
        SliverToBoxAdapter(
          child: _InlineNotice(message: _messageOf(list.error)),
        ),
      SliverLayoutBuilder(
        builder: (context, constraints) {
          // Trois colonnes sur un téléphone tenu droit, deux sur un très petit
          // écran, quatre dès qu'on tourne l'appareil (ou sur tablette).
          final width = constraints.crossAxisExtent;
          final columns = width < 340
              ? 2
              : width >= 640
              ? 4
              : 3;
          final available = math.max(
            columns * 60.0,
            width - RiftSpace.page.horizontal,
          );
          final tileWidth = (available - _gap * (columns - 1)) / columns;
          // Ratio portrait d'un visuel de carte, plus la ligne du nom.
          final imageHeight = tileWidth / CardImage.portraitRatio;

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: _gap,
                mainAxisSpacing: 16,
                mainAxisExtent: imageHeight + 28,
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
                  index: index,
                  imageHeight: imageHeight,
                  onPressed: () => context.go(AppRoutes.card(card.id)),
                );
              }, childCount: data.items.length),
            ),
          );
        },
      ),
      if (data.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          ),
        ),
      if (data.loadMoreError != null)
        SliverToBoxAdapter(child: _InlineNotice(message: data.loadMoreError!)),
    ];
  }
}

/// Barre de recherche épinglée sous la bannière : champ arrondi sur parchemin
/// translucide et bouton de filtres avec son compteur or.
class _SearchHeader extends SliverPersistentHeaderDelegate {
  const _SearchHeader({
    required this.controller,
    required this.filterCount,
    required this.dark,
  });

  static const double _height = 72;

  final TextEditingController controller;
  final int filterCount;
  final bool dark;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = Theme.of(context);
    final paper = dark ? RiftColors.darkPaper : RiftColors.paper;
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: paper.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(
            color: overlaps || shrinkOffset > 0
                ? theme.colorScheme.outline
                : Colors.transparent,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          Expanded(child: _SearchField(controller: controller)),
          const SizedBox(width: 10),
          _FiltersButton(count: filterCount),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeader oldDelegate) =>
      oldDelegate.filterCount != filterCount ||
      oldDelegate.dark != dark ||
      oldDelegate.controller != controller;
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final theme = Theme.of(context);
    final round = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RiftRadius.full),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        style: text.body,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Jinx, ogn-202, réaction…',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          prefixIcon: Icon(Icons.search, size: 20, color: text.muted),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer la recherche',
                  icon: Icon(Icons.close, size: 18, color: text.muted),
                  onPressed: controller.clear,
                ),
          border: round,
          enabledBorder: round,
          focusedBorder: round.copyWith(
            borderSide: const BorderSide(color: RiftColors.hex, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Bouton d'ouverture de la feuille de filtres, pastille or sur le compteur.
class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = riftText(context);
    return Semantics(
      button: true,
      label: count == 0 ? 'Filtres' : 'Filtres, $count actifs',
      child: PressScale(
        onTap: () => showCardFiltersSheet(context),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(RiftRadius.full),
            border: Border.all(
              color: count > 0 ? RiftColors.gold : theme.colorScheme.outline,
              width: count > 0 ? 1.4 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.tune, size: 21, color: text.ink),
              if (count > 0)
                Positioned(
                  top: 6,
                  right: 5,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: RiftColors.goldGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: text.mono.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    if (pills.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          itemCount: pills.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) =>
              Reveal(index: index, child: pills[index]),
        ),
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

String _messageOf(Object? error) =>
    error is ApiException ? error.message : 'Erreur inattendue.';
