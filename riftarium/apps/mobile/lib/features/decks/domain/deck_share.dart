import 'deck.dart';
import 'deck_code.dart';
import 'deck_rules.dart';

/// Partage d'un deck : code de deck et listes texte, comme `deckExport.js`.

/// Cartes du deck converties en entrées de code (quantités cumulées).
List<DeckCodeCard> encoderCards(List<DeckCard> cards) {
  final counts = <String, int>{};
  for (final entry in cards) {
    final code = toCardCode(entry.card.riftboundId);
    if (code.isEmpty || entry.qty <= 0) continue;
    counts[code] = (counts[code] ?? 0) + entry.qty;
  }
  return counts.entries
      .map((entry) => DeckCodeCard(entry.key, entry.value))
      .toList();
}

/// Code de deck partageable (Rift Atlas, Piltover Archive…).
///
/// Lève [DeckCodeException] si le deck est vide.
String deckCodeOf(List<DeckCard> cards) {
  final mainDeck = encoderCards(cards);
  if (mainDeck.isEmpty) throw const DeckCodeException('Ce deck est vide.');
  final champion = championOf(cards);
  return encodeDeckCode(
    mainDeck,
    chosenChampion: champion == null
        ? null
        : toCardCode(champion.card.riftboundId),
  );
}

/// Liste compacte `3x Nom`, zone par zone.
String nameList(List<DeckCard> cards) {
  final groups = groupDeck(cards);
  final lines = <String>[];
  for (final key in const ['Legend', 'Battlefield', 'Rune', 'main']) {
    for (final entry in groups[key]!) {
      lines.add('${entry.qty}x ${entry.card.name}');
    }
  }
  return lines.join('\n');
}
