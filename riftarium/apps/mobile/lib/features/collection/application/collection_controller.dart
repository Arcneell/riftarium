import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/collection_api.dart';
import '../domain/collection.dart';

/// Taille de page demandée à l'API (`size` est plafonné à 100 côté serveur).
const collectionPageSize = 60;

/// Délai avant d'envoyer la recherche : la saisie ne déclenche pas un appel
/// par caractère.
const collectionSearchDelay = Duration(milliseconds: 300);

/// État de l'onglet Collection : les cartes chargées, la recherche en cours et
/// les compteurs globaux (indépendants des filtres, comme sur le site).
class CollectionState {
  const CollectionState({
    this.items = const [],
    this.query = '',
    this.sort = '',
    this.totalCards = 0,
    this.uniqueCards = 0,
    this.valueEur,
    this.total = 0,
    this.page = 1,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<CollectionItem> items;
  final String query;

  /// Tri demandé à l'API : '' (ordre du set), `price_desc` ou `price_asc`.
  final String sort;

  /// Exemplaires possédés, toutes cartes confondues.
  final int totalCards;

  /// Cartes différentes possédées.
  final int uniqueCards;

  /// Valeur estimée de la collection, null si aucun prix connu.
  final double? valueEur;

  /// Nombre de cartes correspondant à la recherche courante.
  final int total;
  final int page;
  final bool loadingMore;

  /// Message d'échec du chargement de la page suivante : les cartes déjà
  /// affichées restent visibles, l'écran ajoute une ligne d'avertissement.
  final String? loadMoreError;

  bool get hasMore => items.length < total;

  /// Collection vide côté serveur (à distinguer d'une recherche sans résultat).
  bool get isEmpty => uniqueCards == 0;

  CollectionState copyWith({
    List<CollectionItem>? items,
    String? query,
    String? sort,
    int? totalCards,
    int? uniqueCards,
    double? valueEur,
    bool clearValue = false,
    int? total,
    int? page,
    bool? loadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) => CollectionState(
    items: items ?? this.items,
    query: query ?? this.query,
    sort: sort ?? this.sort,
    totalCards: totalCards ?? this.totalCards,
    uniqueCards: uniqueCards ?? this.uniqueCards,
    valueEur: clearValue ? null : (valueEur ?? this.valueEur),
    total: total ?? this.total,
    page: page ?? this.page,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );

  /// Remplace les lots d'une carte et ajuste les compteurs : la liste reste
  /// cohérente le temps que le serveur réponde (mise à jour optimiste).
  CollectionState withEntries(String cardId, List<CollectionEntry> entries) {
    final index = items.indexWhere((item) => item.card.id == cardId);
    if (index < 0) return this;
    final current = items[index];
    final updated = current.copyWith(entries: entries);
    final delta = updated.totalQty - current.totalQty;
    final gone = updated.totalQty == 0;
    final next = [...items];
    if (gone) {
      next.removeAt(index);
    } else {
      next[index] = updated;
    }
    final price = current.priceEur;
    final value = valueEur;
    return copyWith(
      items: next,
      totalCards: (totalCards + delta).clamp(0, 1 << 30),
      uniqueCards: gone ? (uniqueCards - 1).clamp(0, 1 << 30) : uniqueCards,
      total: gone ? (total - 1).clamp(0, 1 << 30) : total,
      valueEur: (price == null || value == null)
          ? null
          : double.parse((value + delta * price).toStringAsFixed(2)),
      clearValue: price == null || value == null,
    );
  }

  /// Lots de la carte une fois la quantité du couple (état, langue) fixée.
  List<CollectionEntry> entriesWith(
    String cardId,
    int qty,
    String condition,
    String lang,
  ) {
    final item = itemOf(cardId);
    if (item == null) return const [];
    return entriesWithQuantity(item.entries, qty, condition, lang);
  }

  CollectionItem? itemOf(String cardId) {
    for (final item in items) {
      if (item.card.id == cardId) return item;
    }
    return null;
  }
}

/// Progression par set (`GET /api/collection/sets`), rechargée après chaque
/// modification de la collection.
final collectionProgressProvider = FutureProvider<CollectionProgress>((
  ref,
) async {
  final signedIn = ref.watch(
    authControllerProvider.select((auth) => auth.isSignedIn),
  );
  if (!signedIn) return CollectionProgress.empty;
  return ref.watch(collectionApiProvider).progress();
});

final collectionControllerProvider =
    AsyncNotifierProvider<CollectionController, CollectionState>(
      CollectionController.new,
    );

/// Collection du joueur : chargement paginé, recherche et modifications.
///
/// Chaque mutation applique d'abord le changement localement, puis recharge la
/// première page : les identifiants de lots et les valeurs viennent toujours
/// du serveur.
class CollectionController extends AsyncNotifier<CollectionState> {
  Timer? _debounce;
  bool _disposed = false;

  /// Incrémenté à chaque rechargement demandé : la réponse d'un rechargement
  /// dépassé (recherche tapée entre-temps, mutation plus récente) est jetée.
  int _generation = 0;

  CollectionApi get _api => ref.read(collectionApiProvider);

  @override
  Future<CollectionState> build() async {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    // Une ouverture ou une fermeture de session repart d'une collection vierge.
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );
    if (!signedIn) return const CollectionState();
    return _fetch('', '');
  }

  Future<CollectionState> _fetch(String query, String sort) async {
    final page = await _api.list(
      query: query,
      sort: sort,
      size: collectionPageSize,
    );
    return CollectionState(
      items: page.items,
      query: query,
      sort: sort,
      totalCards: page.totalCards,
      uniqueCards: page.uniqueCards,
      valueEur: page.valueEur,
      total: page.total,
      page: page.page,
    );
  }

  /// Recharge la première page en gardant la recherche et le tri courants.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    final query = current?.query ?? '';
    final sort = current?.sort ?? '';
    final generation = ++_generation;
    state = const AsyncLoading<CollectionState>().copyWithPrevious(state);
    final next = await AsyncValue.guard(() => _fetch(query, sort));
    if (_disposed || generation != _generation) return;
    state = next;
  }

  /// Saisie dans la barre de recherche : affichée tout de suite, envoyée à
  /// l'API après [collectionSearchDelay].
  void search(String query) {
    final current = state.valueOrNull ?? const CollectionState();
    if (query == current.query) return;
    state = AsyncData(current.copyWith(query: query));
    _debounce?.cancel();
    _debounce = Timer(collectionSearchDelay, () {
      unawaited(refresh());
    });
  }

  /// Change le tri (puces sous la recherche) : rechargement immédiat.
  void setSort(String sort) {
    final current = state.valueOrNull ?? const CollectionState();
    if (sort == current.sort) return;
    state = AsyncData(current.copyWith(sort: sort));
    _debounce?.cancel();
    unawaited(refresh());
  }

  /// Page suivante ajoutée à la suite de la liste. Un échec est porté par
  /// l'état (`loadMoreError`), pas relancé : les pages déjà affichées restent
  /// en place et l'écran montre le message.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await _api.list(
        query: current.query,
        sort: current.sort,
        page: current.page + 1,
        size: collectionPageSize,
      );
      if (_disposed || generation != _generation) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          page: page.page,
          total: page.total,
          loadingMore: false,
        ),
      );
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: error.message),
      );
    }
  }

  /// Fixe la quantité d'un couple (état, langue) — 0 supprime le lot.
  Future<void> setQuantity({
    required String cardId,
    required int qty,
    String condition = defaultCondition,
    String lang = defaultLang,
  }) => _mutate(
    cardId: cardId,
    optimistic: (current) => current.withEntries(
      cardId,
      current.entriesWith(cardId, qty, condition, lang),
    ),
    action: () => _api.setQuantity(
      cardId: cardId,
      qty: qty,
      condition: condition,
      lang: lang,
    ),
  );

  /// Ajoute un lot (les quantités s'additionnent si le couple existe déjà).
  Future<void> addEntry({
    required String cardId,
    required int qty,
    String condition = defaultCondition,
    String lang = defaultLang,
  }) {
    final item = state.valueOrNull?.itemOf(cardId);
    final existing = item?.entries
        .where((entry) => entry.condition == condition && entry.lang == lang)
        .fold<int>(0, (total, entry) => total + entry.qty);
    return _mutate(
      cardId: cardId,
      optimistic: (current) => current.withEntries(
        cardId,
        current.entriesWith(cardId, (existing ?? 0) + qty, condition, lang),
      ),
      action: () => _api.addEntry(
        cardId: cardId,
        qty: qty,
        condition: condition,
        lang: lang,
      ),
    );
  }

  /// Modifie un lot existant (quantité, état ou langue) — `qty: 0` le retire.
  Future<void> updateEntry({
    required String cardId,
    required CollectionEntry entry,
    int? qty,
    String? condition,
    String? lang,
  }) => _mutate(
    cardId: cardId,
    optimistic: (current) {
      final item = current.itemOf(cardId);
      if (item == null) return current;
      final entries = <CollectionEntry>[];
      for (final existing in item.entries) {
        if (existing.id != entry.id) {
          entries.add(existing);
        } else if (qty != 0) {
          entries.add(
            existing.copyWith(qty: qty, condition: condition, lang: lang),
          );
        }
      }
      return current.withEntries(cardId, entries);
    },
    action: () => _api.updateEntry(
      entryId: entry.id,
      qty: qty,
      condition: condition,
      lang: lang,
    ),
  );

  /// Retire complètement une carte de la collection (tous ses lots), en un
  /// seul appel : `POST /collection/bulk` avec `remove`. Avant, une suite de
  /// PATCH pouvait échouer à moitié et laisser des lots derrière.
  Future<void> removeCard(String cardId) => _mutate(
    cardId: cardId,
    optimistic: (current) => current.withEntries(cardId, const []),
    action: () => _api.removeCards([cardId]),
  );

  /// Applique le changement localement, l'envoie, puis relit **la seule carte
  /// touchée** (`GET /collection/{id}`) : les identifiants de lots viennent du
  /// serveur sans que la liste reparte de la première page.
  Future<void> _mutate({
    required String cardId,
    required CollectionState Function(CollectionState) optimistic,
    required Future<void> Function() action,
  }) async {
    final previous = state.valueOrNull;
    if (previous != null) state = AsyncData(optimistic(previous));
    try {
      await action();
    } catch (_) {
      // Échec : on remet l'état d'avant, l'écran affiche le message d'erreur.
      if (!_disposed && previous != null) state = AsyncData(previous);
      rethrow;
    }
    if (_disposed) return;
    ref.invalidate(collectionProgressProvider);
    await _reloadCard(cardId);
  }

  /// Remplace les lots d'une carte par ceux du serveur. Tombée à zéro, la carte
  /// sort de la liste (`withEntries`) ; absente de la vue courante (autre page,
  /// filtre), elle est simplement ignorée.
  Future<void> _reloadCard(String cardId) async {
    final generation = _generation;
    final CardCollectionState fresh;
    try {
      fresh = await _api.cardState(cardId);
    } on ApiException {
      // Carte non relue : l'état optimiste tient, le prochain rafraîchissement
      // de l'onglet repartira du serveur.
      return;
    }
    if (_disposed || generation != _generation) return;
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.withEntries(cardId, fresh.entries));
  }
}
