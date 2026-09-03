import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_code.dart';

/// Résolution d'un code de deck en cartes Riftarium.
///
/// Le code ne transporte que des codes de cartes (`OGN-247`) ; l'API attend des
/// identifiants Riftcodex. On interroge donc `GET /api/cards` avec le code sans
/// suffixe de variante puis on retient la carte dont le `riftbound_id` produit
/// exactement le même code (`toCardCode`).
class DeckImportResult {
  const DeckImportResult({
    required this.cards,
    required this.unresolved,
    this.champion,
    this.sideboardIgnored = 0,
  });

  final List<DeckCard> cards;

  /// Codes de cartes introuvables dans la base (le deck est créé sans elles).
  final List<String> unresolved;
  final RiftCard? champion;

  /// Exemplaires portés par la réserve du code : Riftarium n'a pas de zone de
  /// réserve, ils sont écartés — mais jamais en silence.
  final int sideboardIgnored;

  int get total => cards.fold<int>(0, (sum, entry) => sum + entry.qty);
}

/// Nombre de recherches menées en parallèle (l'API est appelée une fois par
/// code de carte distinct : on évite d'ouvrir 40 requêtes d'un coup).
const int _batchSize = 6;

Future<DeckImportResult> resolveDeckCode(
  CardsApi api,
  DeckCodeContents contents,
) async {
  final wanted = <String, int>{};
  for (final entry in contents.mainDeck) {
    wanted[entry.cardCode] = (wanted[entry.cardCode] ?? 0) + entry.count;
  }

  final codes = wanted.keys.toList();
  final found = <String, RiftCard>{};
  for (var start = 0; start < codes.length; start += _batchSize) {
    final slice = codes.skip(start).take(_batchSize).toList();
    final results = await Future.wait(
      slice.map((code) => _findCard(api, code)),
    );
    for (var i = 0; i < slice.length; i++) {
      final card = results[i];
      if (card != null) found[slice[i]] = card;
    }
  }

  final cards = <DeckCard>[];
  final unresolved = <String>[];
  for (final code in codes) {
    final card = found[code];
    if (card == null) {
      unresolved.add(code);
      continue;
    }
    cards.add(DeckCard(card: card, qty: wanted[code]!));
  }

  final championCode = contents.chosenChampion;
  return DeckImportResult(
    cards: cards,
    unresolved: unresolved,
    champion: championCode == null ? null : found[championCode],
    sideboardIgnored: contents.sideboard.fold<int>(
      0,
      (total, entry) => total + entry.count,
    ),
  );
}

Future<RiftCard?> _findCard(CardsApi api, String cardCode) async {
  final String query;
  try {
    query = cardCodeQuery(cardCode);
  } on DeckCodeException {
    return null;
  }
  final page = await api.list(filters: CardFilters(query: query), size: 30);
  for (final card in page.items) {
    if (toCardCode(card.riftboundId) == cardCode) return card;
  }
  return null;
}
