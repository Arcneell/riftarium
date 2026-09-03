import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';
import '../data/decks_api.dart';
import '../domain/deck.dart';
import '../domain/deck_code.dart';
import 'deck_import.dart';

/// Mes decks (`GET /api/decks/mine`). Vide et sans appel hors session.
final myDecksProvider = FutureProvider.autoDispose<List<Deck>>((ref) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const <Deck>[];
  return ref.watch(decksApiProvider).mine();
});

/// Un deck complet (`GET /api/decks/{id}`), rechargé quand la session change.
final deckProvider = FutureProvider.autoDispose.family<Deck, int>((
  ref,
  deckId,
) async {
  ref.watch(authControllerProvider.select((state) => state.isSignedIn));
  return ref.watch(decksApiProvider).get(deckId);
});

/// Cartes manquantes d'un deck (propriétaire uniquement), rechargées quand la
/// session change : la liste dépend de la collection du compte connecté.
final deckMissingProvider = FutureProvider.autoDispose.family<DeckMissing, int>(
  (ref, deckId) {
    ref.watch(authControllerProvider.select((state) => state.isSignedIn));
    return ref.watch(decksApiProvider).missing(deckId);
  },
);

/// Légendes proposées par le filtre communautaire.
final communityLegendsProvider =
    FutureProvider.autoDispose<List<CommunityLegend>>(
      (ref) => ref.watch(decksApiProvider).communityLegends(),
    );

/// Filtres + page courante du listing communautaire.
class CommunityQuery {
  const CommunityQuery({
    this.filters = const CommunityFilters(),
    this.page = 1,
  });

  final CommunityFilters filters;
  final int page;

  CommunityQuery copyWith({CommunityFilters? filters, int? page}) =>
      CommunityQuery(filters: filters ?? this.filters, page: page ?? this.page);

  @override
  bool operator ==(Object other) =>
      other is CommunityQuery && other.filters == filters && other.page == page;

  @override
  int get hashCode => Object.hash(filters, page);
}

final communityQueryProvider =
    NotifierProvider<CommunityQueryController, CommunityQuery>(
      CommunityQueryController.new,
    );

/// Un changement de filtre ramène toujours à la première page.
class CommunityQueryController extends Notifier<CommunityQuery> {
  @override
  CommunityQuery build() => const CommunityQuery();

  void _apply(CommunityFilters filters) {
    state = CommunityQuery(filters: filters, page: 1);
  }

  void setQuery(String query) => _apply(state.filters.copyWith(query: query));

  void setSort(String sort) => _apply(state.filters.copyWith(sort: sort));

  void toggleLiked() =>
      _apply(state.filters.copyWith(liked: !state.filters.liked));

  void toggleBuildable() =>
      _apply(state.filters.copyWith(buildable: !state.filters.buildable));

  void toggleLegend(String id) => _apply(
    state.filters.copyWith(legends: _toggle(state.filters.legends, id)),
  );

  void toggleDomain(String domain) => _apply(
    state.filters.copyWith(domains: _toggle(state.filters.domains, domain)),
  );

  void setFormat(String? format) => _apply(
    state.filters.copyWith(formats: format == null ? const [] : [format]),
  );

  void setPage(int page) => state = state.copyWith(page: page < 1 ? 1 : page);

  /// Remise à zéro des filtres ; le tri n'en est pas un et reste en place.
  void reset() => _apply(CommunityFilters(sort: state.filters.sort));

  static List<String> _toggle(List<String> values, String value) =>
      values.contains(value)
      ? values.where((item) => item != value).toList()
      : [...values, value];
}

/// Page courante du listing communautaire (accessible sans compte).
final communityDecksProvider = FutureProvider.autoDispose<CommunityPage>((
  ref,
) async {
  ref.watch(authControllerProvider.select((state) => state.isSignedIn));
  final query = ref.watch(communityQueryProvider);
  return ref
      .watch(decksApiProvider)
      .communityDecks(filters: query.filters, page: query.page);
});

/// Recherche de cartes de l'éditeur de deck.
class DeckCardQuery {
  const DeckCardQuery({this.text = '', this.type, this.domain, this.page = 1});

  final String text;
  final String? type;
  final String? domain;
  final int page;

  CardFilters get filters => CardFilters(
    query: text.isEmpty ? null : text,
    type: type,
    domain: domain,
  );

  DeckCardQuery copyWith({
    String? text,
    String? type,
    String? domain,
    int? page,
    bool clearType = false,
    bool clearDomain = false,
  }) => DeckCardQuery(
    text: text ?? this.text,
    type: clearType ? null : (type ?? this.type),
    domain: clearDomain ? null : (domain ?? this.domain),
    page: page ?? this.page,
  );

  @override
  bool operator ==(Object other) =>
      other is DeckCardQuery &&
      other.text == text &&
      other.type == type &&
      other.domain == domain &&
      other.page == page;

  @override
  int get hashCode => Object.hash(text, type, domain, page);
}

/// Page de résultats pour l'éditeur (`GET /api/cards`).
final deckCardSearchProvider = FutureProvider.autoDispose
    .family<CardPage, DeckCardQuery>(
      (ref, query) => ref
          .watch(cardsApiProvider)
          .list(filters: query.filters, page: query.page, size: 24),
    );

final deckActionsProvider = Provider<DeckActions>(DeckActions.new);

/// Écritures sur les decks : chaque action rafraîchit ce qui est concerné.
class DeckActions {
  DeckActions(this._ref);

  final Ref _ref;

  DecksApi get _api => _ref.read(decksApiProvider);

  Future<Deck> create(DeckInput input) async {
    final deck = await _api.create(input);
    _ref.invalidate(myDecksProvider);
    return deck;
  }

  Future<Deck> update(int deckId, DeckInput input) async {
    final deck = await _api.update(deckId, input);
    _ref.invalidate(myDecksProvider);
    _ref.invalidate(deckProvider(deckId));
    _ref.invalidate(deckMissingProvider(deckId));
    return deck;
  }

  Future<void> delete(int deckId) async {
    await _api.delete(deckId);
    _ref.invalidate(myDecksProvider);
  }

  Future<Deck> copy(int deckId) async {
    final deck = await _api.copy(deckId);
    _ref.invalidate(myDecksProvider);
    return deck;
  }

  Future<DeckLikeResult> toggleLike(int deckId) async {
    final result = await _api.toggleLike(deckId);
    _ref.invalidate(deckProvider(deckId));
    _ref.invalidate(communityDecksProvider);
    return result;
  }

  /// Compte une visite sans jamais bloquer l'affichage : les erreurs (deck
  /// privé, réseau) sont sans conséquence pour le lecteur.
  Future<void> recordView(int deckId) async {
    try {
      await _api.recordView(deckId);
    } on Object {
      // Statistique de confort : une vue perdue n'a pas d'importance.
    }
  }

  /// Crée un deck à partir d'un code partagé.
  ///
  /// Le code est décodé puis chaque carte est retrouvée via `GET /api/cards`.
  /// Les codes introuvables sont signalés dans [DeckImportOutcome.unresolved],
  /// les cartes de réserve dans [DeckImportOutcome.sideboardIgnored].
  Future<DeckImportOutcome> importFromCode(
    String code, {
    required String name,
    String format = 'tournament',
    bool isPublic = false,
    String description = '',
  }) async {
    final contents = decodeDeckCode(code);
    if (contents.mainDeck.isEmpty) {
      throw const DeckCodeException('Ce code ne contient aucune carte.');
    }
    final resolved = await resolveDeckCode(
      _ref.read(cardsApiProvider),
      contents,
    );
    if (resolved.cards.isEmpty) {
      throw const DeckCodeException(
        'Aucune carte de ce code n’a été retrouvée dans la base.',
      );
    }
    final deck = await create(
      DeckInput(
        name: name,
        description: description,
        format: format,
        isPublic: isPublic,
        cards: resolved.cards
            .map((entry) => DeckCardInput(entry.card.id, entry.qty))
            .toList(),
      ),
    );
    return DeckImportOutcome(
      deck: deck,
      unresolved: resolved.unresolved,
      sideboardIgnored: resolved.sideboardIgnored,
    );
  }
}

/// Deck créé depuis un code, avec les cartes qui n'ont pas pu être retrouvées.
class DeckImportOutcome {
  const DeckImportOutcome({
    required this.deck,
    required this.unresolved,
    this.sideboardIgnored = 0,
  });

  final Deck deck;
  final List<String> unresolved;

  /// Exemplaires de la réserve du code, écartés : Riftarium ne stocke qu'un
  /// deck principal. Le compter permet de le dire à l'utilisateur.
  final int sideboardIgnored;
}
