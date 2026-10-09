import 'card.dart';

final RegExp _printSuffix = RegExp(
  r'\s*\((?:alternate art|overnumbered|signature)\)\s*$',
  caseSensitive: false,
);

/// Texte cherché sur Cardmarket, comme `cardmarketUrl` du site
/// (`apps/web/src/prices.js`). Cardmarket range alt-arts, overnumbered et
/// signatures sous « showcase » : on cherche le nom sans suffixe suivi de
/// « showcase ».
String cardmarketSearch(RiftCard card) {
  final showcase =
      card.alternateArt ||
      card.overnumbered ||
      card.signature ||
      _printSuffix.hasMatch(card.name);
  if (!showcase) return card.name;
  return '${card.name.replaceFirst(_printSuffix, '')} showcase';
}

/// Lien de recherche Cardmarket (sortant, non affilié).
Uri cardmarketUri(RiftCard card) => Uri.parse(
  'https://www.cardmarket.com/fr/Riftbound/Products/Search'
  '?searchString=${Uri.encodeComponent(cardmarketSearch(card))}',
);
