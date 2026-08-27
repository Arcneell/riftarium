import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/cards_api.dart';
import '../domain/card.dart';
import '../domain/card_set.dart';
import '../domain/prices_meta.dart';

/// Taille de page de la cartothèque (maximum accepté par l'API : 100).
const int kCardsPageSize = 30;

/// Filtres courants, partagés par la barre de recherche, la feuille de
/// filtres et les puces de rappel.
final cardFiltersProvider =
    NotifierProvider<CardFiltersController, CardFilters>(
      CardFiltersController.new,
    );

class CardFiltersController extends Notifier<CardFilters> {
  @override
  CardFilters build() => const CardFilters();

  /// Recherche plein texte (nom, texte, identifiant Riftbound).
  void setQuery(String value) {
    final query = value.trim();
    if ((state.query ?? '') == query) return;
    state = state.copyWith(query: query);
  }

  void setSetId(String? value) => state = value == null
      ? state.copyWith(clearSetId: true)
      : state.copyWith(setId: value);

  void setType(String? value) => state = value == null
      ? state.copyWith(clearType: true)
      : state.copyWith(type: value);

  void setDomain(String? value) => state = value == null
      ? state.copyWith(clearDomain: true)
      : state.copyWith(domain: value);

  void setRarity(String? value) => state = value == null
      ? state.copyWith(clearRarity: true)
      : state.copyWith(rarity: value);

  void setEnergy(String? value) => state = value == null
      ? state.copyWith(clearEnergy: true)
      : state.copyWith(energy: value);

  void setOwned(String? value) => state = value == null
      ? state.copyWith(clearOwned: true)
      : state.copyWith(owned: value);

  void setSort(String? value) => state = value == null
      ? state.copyWith(clearSort: true)
      : state.copyWith(sort: value);

  /// Vide tous les critères sauf la recherche, qui reste visible dans le champ.
  void clearFacets() => state = CardFilters(query: state.query);
}

/// Contenu accumulé de la cartothèque : les pages déjà chargées, plus l'état
/// du chargement de la suivante.
class CardsList {
  const CardsList({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  const CardsList.empty()
    : items = const [],
      total = 0,
      page = 0,
      hasMore = false,
      loadingMore = false,
      loadMoreError = null;

  final List<RiftCard> items;
  final int total;

  /// Dernière page reçue de l'API.
  final int page;
  final bool hasMore;
  final bool loadingMore;

  /// Message d'échec du chargement de la page suivante (les pages déjà
  /// affichées restent en place).
  final String? loadMoreError;

  CardsList copyWith({
    List<RiftCard>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) => CardsList(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );
}

final cardsListProvider = AsyncNotifierProvider<CardsListController, CardsList>(
  CardsListController.new,
);

/// Liste paginée de `GET /api/cards`. Repart de la première page à chaque
/// changement de filtre et à chaque changement de session (`owned_qty` et le
/// filtre « possédées » dépendent du compte).
class CardsListController extends AsyncNotifier<CardsList> {
  /// Incrémenté à chaque (re)construction et à la destruction : un chargement
  /// de page lancé avant ne peut plus écraser l'état courant.
  int _generation = 0;

  @override
  Future<CardsList> build() async {
    _generation++;
    ref.onDispose(() => _generation++);
    final filters = ref.watch(cardFiltersProvider);
    ref.watch(authControllerProvider.select((state) => state.isSignedIn));
    final page = await ref
        .watch(cardsApiProvider)
        .list(filters: filters, page: 1, size: kCardsPageSize);
    return CardsList(
      items: page.items,
      total: page.total,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// Charge la page suivante et l'ajoute à la suite. Sans effet si tout est
  /// déjà chargé ou si un chargement est en cours.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, clearLoadMoreError: true),
    );
    try {
      final next = await ref
          .read(cardsApiProvider)
          .list(
            filters: ref.read(cardFiltersProvider),
            page: current.page + 1,
            size: kCardsPageSize,
          );
      if (generation != _generation) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          total: next.total,
          page: next.page,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on ApiException catch (error) {
      if (generation != _generation) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: error.message),
      );
    }
  }

  /// Tiré vers le bas : recharge la première page. L'erreur éventuelle est
  /// portée par l'état, pas relancée à l'appelant.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on ApiException {
      // L'écran affiche déjà l'erreur : rien à propager au geste de rafraîchissement.
    }
  }
}

/// Sets connus, pour le filtre. Une erreur ici n'empêche pas de filtrer le
/// reste : l'écran se contente de masquer la section.
final cardSetsProvider = FutureProvider<List<CardSet>>((ref) async {
  final rows = await ref.watch(cardsApiProvider).sets();
  return rows.map(CardSet.fromJson).toList();
});

/// Fraîcheur et origine des prix, affichées sous le prix d'une carte.
final pricesMetaProvider = FutureProvider<PricesMeta>((ref) async {
  final json = await ref.watch(cardsApiProvider).pricesMeta();
  return PricesMeta.fromJson(json);
});

/// Fiche d'une carte. Rechargée au changement de session : `owned_qty` et
/// `wished_qty` n'apparaissent que pour un compte connecté.
final cardDetailProvider = FutureProvider.family<RiftCard, String>((
  ref,
  cardId,
) {
  ref.watch(authControllerProvider.select((state) => state.isSignedIn));
  return ref.watch(cardsApiProvider).get(cardId);
});

/// Variantes (alt-art, signature, overnumbered) de la même carte.
final cardVariantsProvider = FutureProvider.family<List<RiftCard>, String>((
  ref,
  cardId,
) {
  ref.watch(authControllerProvider.select((state) => state.isSignedIn));
  return ref.watch(cardsApiProvider).variants(cardId);
});
